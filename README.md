# **CS-BlockDewd**

 Easy and automated blocklist pulling and importing for crowdsec aimed at reducing redundant decisions and minimal impact on hardware. Designed to run as a systemd service for a set and forget approach once configured.


## **Main Features**

 Easy configuration via a simple yaml file\
 Automated blocklist pulling and import every 6 hours\
 Filters out duplicate entries from pulled lists\
 Checks IP's against the Cidr ranges from pulled lists to reduce redundant decisions\
 Checks IP's against the Cidr ranges in active decisions to reduce redundant decisions\
 Finally checks IP's against existing IP decisions to reduce redundant decisions\
 Imports into crowdsec while only creating 1 alert as to not flood logs\
 Can run crowdsec import for native install or docker container\

### **Requirments and installation**
 Requires yq & grepcidr which both will be installed if need during installation\
 Systemd for scheduling and automation

 To install download via command line

        curl -L -o cs-blockdewd.tar.gz https://github.com/dewdmadbro/cs-blockdewd/archive/refs/tags/Latest.tar.gz

 Then extract the files, then check the config.yaml and edit as needed

        tar -xvzf cs-blockdewd.tar.gz

 Once done make install-csblockdew.sh executable and then run it

        chmod +x install-csblockdewd.sh
        sudo ./install-csblockdewd.sh

 During installation it will check for yq & grepcidr and install if needed\
 Also the systemd service and timer will be generated\
 It will map the service to run cs-blockdewd.sh and gernerate a log in the extracted folder
 The final thing it will do is run the service for the first time       

### **Removal and updating**

 **To uninstall**
 
        chmod +x uninstall-csblockdewd.sh
        sudo ./uninstall-csblockdewd.sh

 This will disble the cs-blockdewd.service and cs-blockdewd.timer\
 Then it will remove the files and reload the systemd daemon\
 It will also ask if you want to remove yq and grepcidr\

 **To update**
 
 Currently I do not have a dedicated install mechanism\
 Best way to do it now is to run the uninstaller and then download latest and reinstall
 