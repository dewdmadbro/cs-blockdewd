# **CS-BlockDewd**

 Easy and automated blocklist pulling and importing for crowdsec aimed at reducing redundant decisions and minimal impact on hardware. Designed to run as a systemd service for a set and forget approach once configured.


## **Main Features**

 Easy configuration via a simple yaml file\
 Automated blocklist pulling and import every 6 hours\
 Filters out duplicate entries from pulled lists\
 Checks IP's against geopip-shell if installed so we only have to created decisions for items it doesn't already block (only if installed)\
 Checks IP's against the Cidr ranges from pulled lists to reduce redundant decisions\
 Checks IP's against the Cidr ranges in active decisions to reduce redundant decisions\
 Finally checks IP's against existing IP decisions to reduce redundant decisions\
 Imports into crowdsec while only creating 1 alert as to not flood logs\
 Can run crowdsec import for native install or docker container\

### **Requirements and installation**

 Not required but highly recommended to have geoip-shell for geoblocking MUST be in whitelist mode or this will NOT WORK so go get that first here -> [GEOIP-SHELL](https://github.com/friendly-bits/geoip-shell?tab=readme-ov-file)\
 Requires yq & grepcidr which both will be installed if needed during installation\
 Systemd for scheduling and automation\
 Crowdsec bouncerkey, see crowdsec documentation here -> [Crowdsec Bouncers](https://docs.crowdsec.net/docs/next/cscli/cscli_bouncers_add/)

 To install download via command line

        LOCATION=$(curl -s https://api.github.com/repos/dewdmadbro/cs-blockdewd/releases/latest \
        | grep "tarball_url" \
        | awk '{ print $2 }' \
        | sed 's/,$//'       \
        | sed 's/"//g' )     \
        ; curl -L -o cs-blockdewd.tar.gz $LOCATION

 Then extract the files

        tar -xvzf cs-blockdewd.tar.gz --one-top-level --strip-components=1
        rm cs-blockdewd.tar.gz

 Read and edit config.yaml replace nano with your editor

        cd cs-blockdewd
        nano config.yaml

 Once done with config you will need to make blockdewd.sh executable and then run install

        chmod +x blockdewd.sh
        sudo ./blockdewd.sh install

 During installation it will check for yq & grepcidr and install if needed\
 Also the systemd service and timer will be generated\
 It will map the service to run cs-blockdewd.sh and generate a log in the extracted folder
 The final thing it will do is run the service for the first time\  

### **Removal and updating**

 **To uninstall**
 
        cd blockdewd
        sudo ./blockdewd.sh remove

 This will disble the cs-blockdewd.service and cs-blockdewd.timer\
 Then it will remove the files and reload the systemd daemon\
 It will also ask if you want to remove yq and grepcidr\

 **To update**
 
 To update run the following

        cd blockdewd
        sudo ./blockdewd.sh update

 **To remove decisions**

 Docker install(replace crowdsec with your container name if different)
        
        sudo docker exec crowdsec cscli decisions delete --origin cscli-import

 Native install
        
        cscli decisions delete --origin cscli-import

