#!/bin/bash

#Load variables from config.yaml
KEY=$(yq -r '.bouncerkey' config.yaml)
DURATION=$(yq -r '.ban_duration' config.yaml)
CS=$(yq -r '.cs_container' config.yaml)
V1=$(yq -r '.abipdb_filter' config.yaml)
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

# Loop through the URL lists and fetch
echo "-----> Fetching Lists"
echo "--------------------------------------------------"
for url in "${URL1_LIST[@]}"; do
    fetch1 "$url"
done
# Loop through Abuse IPDB lists and fetch
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
sleep 1
echo "-----> Removing Duplicates & Sorting"
sort -u "$PULL" | grep -v '^\s*$' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > "$IPLIST"
sort -u "$PULL" | grep -v '^\s*$' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$' > "$CIDRLIST"
COUNTCIDR=$(wc -l < "$CIDRLIST")


#check esisting cscli-import decisions
echo "-----> Check Existing Cidr Decisions"
curl -s -H "X-Api-Key: $KEY" 'http://127.0.0.1:8080/v1/decisions?type=ban&origins=cscli-import'   -H 'accept: application/json' | jq -r '.[].value' > "$DECS"
grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' "$DECS" > "$IPDECS"
grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$' "$DECS" > "$CIDRDECS"

#remove ips covered by cidr ranges
echo "-----> Removing IPs Covered By Cidr Ranges"
grepcidr -v -f "$CIDRLIST" "$IPLIST" > "$INPUT1"
grepcidr -v -f "$CIDRDECS" "$INPUT1" > "$INPUT2"
COUNTIP=$(wc -l < "$INPUT2")
sleep 1

#set new ips and cidr for import & count
grep -xvFf "$IPDECS" "$INPUT2" > "$IMPORT"
grep -xvFf "$CIDRDECS" "$CIDRLIST" >> "$IMPORT"
COUNTCIDRDECS=$(wc -l < "$CIDRDECS")
COUNTIPDECS=$(wc -l < "$IPDECS")
COUNTIMPORT=$(wc -l < "$IMPORT")
echo "-----> Processing"
sleep 1
echo "          $COUNTIMPORT Decisions To Add"

#import into crowdsec
echo "-----> Running Import"
check for cscli and  run import based on crowdsec install
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
echo "   ~CIDRs already in crowdsec        : $COUNTCIDRDECS"
echo "   ~IPs already in crowdsec          : $COUNTIPDECS"
echo "   ~IPs fetched for input            : $COUNTIP"
echo "   ~Cidrs fetched for input          : $COUNTCIDR"
echo "   ~Total decisions added            : $COUNTIMPORT"
echo "--------------------------------------------------"
echo ""
sleep 3
echo "-> Cleaning Up"
rm *.ipls
echo "-> Bye"
sleep 2
