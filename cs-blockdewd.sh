#!/bin/bash


# Cleanup function to remove temp files on exit (success, error, or interrupt)
cleanup() {
    rm -f *.ipls
    echo "Temporary files cleaned up."
}
trap cleanup EXIT

#Load variables from config.yaml
KEY=$(yq -r '.bouncerkey' config.yaml)
DURATION=$(yq -r '.ban_duration' config.yaml)
CS=$(yq -r '.cs_container' config.yaml)
V1=$(yq -r '.abipdb_filter' config.yaml)
MODE=$(yq -r '.geoip_mode' config.yaml)
CUSTOMLIST=$(yq -r '.myblocklist' config.yaml)
readarray -t URL1_LIST < <(yq -r '.urls_standard[]' config.yaml)
readarray -t URL2_LIST < <(yq -r '.urls_abuseipdb[]' config.yaml)
#Set variables
IPDECS="ip_decs.ipls"
DECS="raw_decs.ipls"
CIDRDECS="cidr_decs.ipls"
IMPORT="import.ipls"
PULL="pull_list.ipls"
IPLIST="ip_list.ipls"
CIDRLIST="cidr_list.ipls"
INPUT1="input1.ipls"
INPUT2="input2.ipls"
GSIPLIST="geoip_list.ipls"
BLOCKED="geoip_blocked.ipls"
GEOIP=""


#set funchtions
fetch1() {
    local url=$1
    echo -n "-----> Fetching  "
    curl -s "$url" | grep -v '^#' >> "$PULL"
    count1
}
count1() {
    COUNT=$(wc -l < "$PULL")
    echo "          $COUNT Entries To Process"
}
fetch2() {
    local url=$1
    echo -n "-----> Fetching  "
    curl -s "$url" | grep "$V1" | grep -v '^#' | awk '{print $1}' >> "$PULL"
    count1
}

#check for custom blocklist and if it exists ammend the IPLIST
custom_blocklist() {
    if [[ ! -f "$CUSTOMLIST" ]]; then
        echo "-----> Custom blocklist not found skipping"
    else
        cat "$CUSTOMLIST" >> "$PULL" 
        echo "-----> Custom blocklist added to processing"
        count1
    fi
}

geoip_mode() {
    # only valid options
    local option_a="whitelist"
    local option_b="blacklist"

    #check options and run correct way to compare
    if [[ "$MODE" == "$option_a" ]]; then
        echo "-----> Checking To Whitelist Mode"
        whitelist_mode
    elif [[ "$MODE" == "$option_b" ]]; then
        echo "-----> Checking To Blacklist Mode"
        blacklist_mode
    else
        echo "[ERROR] Blocking mode incorrectly set please fix and run again."
        exit 1
    fi
}

whitelist_mode() {
    echo "-----> Removing Unecessary IPs"
    #find ips in the whitelist that we want to block
    geoip-shell lookup -F "$IPLIST" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$GSIPLIST"
}

blacklist_mode() {
    echo "-----> Removing Unecessary IPs"
    #get the ips matching in the blacklist
    geoip-shell lookup -F "$IPLIST" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$BLOCKED"
    #remove matching ips
    grep -xvFf "$BLOCKED" "$IPLIST" > "$GSIPLIST"
}

# Loop through the URL lists and fetch
echo "-----> Fetching Lists"
echo "--------------------------------------------------"
for url in "${URL1_LIST[@]}"; do
    fetch1 "$url"
done
# Loop through Abuse IPDB style lists and fetch
if [[ -n "$URL2_LIST" ]]; then
    echo "-----> Abuse IP Database Lists Found "
    for url in "${URL2_LIST[@]}"; do
        fetch2 "$url"
    done
else
    echo "-----> No Additional Lists"
fi

#Sorting & Remove Duplicates
echo ""
echo "-----> Fetch Complete"
count1
echo "-----> Checking for custom blocklist"
custom_blocklist
sleep 1
echo "-----> Removing Duplicates & Sorting"
sort -u "$PULL" | grep -v '^\s*$' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$IPLIST"
sort -u "$PULL" | grep -v '^\s*$' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$' > "$CIDRLIST"
COUNTCIDR=$(wc -l < "$CIDRLIST")
COUNTIP=$(wc -l < "$IPLIST")

#check for geoip-shell then compare IPLIST against geoip-shell if exists
command -v geoip-shell >/dev/null 2>&1 && GEOIP="1"
if [ -n "$GEOIP" ]; then
    echo "-----> Checking IPs Against GEOIP-SHELL"
    geoip_mode
    COUNTGS=$(wc -l < "$GSIPLIST")
    COUNTGEOIP=$(( COUNTIP - COUNTGS ))
else
    cat "$IPLIST" > "$GSIPLIST"
    COUNTGEOIP=0
    echo "-----> GEOIP-SHELL Missing, Skipping Check"
fi

#check esisting crowdsec decisions
echo "-----> Check Existing Cidr Decisions"
curl -s -H "X-Api-Key: $KEY" 'http://127.0.0.1:8080/v1/decisions?type=ban'   -H 'accept: application/json' | jq -r '.[].value' > "$DECS"
grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' "$DECS" > "$IPDECS"
grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$' "$DECS" > "$CIDRDECS"

#remove ips covered by cidr ranges
echo "-----> Removing IPs Covered By Cidr Ranges"
grepcidr -v -f "$CIDRLIST" "$GSIPLIST" > "$INPUT1"
grepcidr -v -f "$CIDRDECS" "$INPUT1" > "$INPUT2"
sleep 1

#set new ips and cidr for import & count
echo "-----> Removing IPs Already In Crowdsec"
grep -xvFf "$IPDECS" "$INPUT2" > "$IMPORT"
grep -xvFf "$CIDRDECS" "$CIDRLIST" >> "$IMPORT"

#more stats stuff
COUNTINPUT2=$(wc -l < "$INPUT2")
COUNTCIDRDIFF=$(( COUNTGS - COUNTINPUT2 ))
COUNTCIDRDECS=$(wc -l < "$CIDRDECS")
COUNTIPDECS=$(wc -l < "$IPDECS")
COUNTIMPORT=$(wc -l < "$IMPORT")
echo "-----> Processing"
sleep 1

#check for cscli and  run import based on crowdsec install
echo "-----> Running Import"
if command -v cscli >/dev/null 2>&1; then
    echo "CSCLI Found, Running CSCLI Commands."
    cat "$IMPORT" | cscli decisions import -i - --format values --duration "$DURATION" --reason "Threats"
else
    echo "CSCLI Not Found, Running Docker Commands..."
    cat "$IMPORT" | docker exec -i "$CS" cscli decisions import -i - --format values --duration "$DURATION" --reason "Threats"
fi
sleep 1
echo "-----> Complete"
echo ""

# --- Summary ---
echo ""
echo "-----> Summary"
echo "--------------------------------------------------"
echo "   ~Cidrs fetched for input          : $COUNTCIDR"
echo "   ~IPs fetched for input            : $COUNTIP"
echo "   ~CIDRs already in crowdsec        : $COUNTCIDRDECS"
echo "   ~IPs already in crowdsec          : $COUNTIPDECS"
echo "   ~IPs blocked by geoip-shell       : $COUNTGEOIP" 
echo "   ~IPs covered by CIDRs             : $COUNTCIDRDIFF"
echo "   ~Total decisions added            : $COUNTIMPORT"
echo "--------------------------------------------------"
echo ""
sleep 3
echo "-> Bye"
sleep 2
