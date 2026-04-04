#!/bin/bash
 
#stop and disable timer and service
echo "Stopping and disabling cs-blockdewd timer and service..."
systemctl stop cs-blockdewd.timer
systemctl disable cs-blockdewd.timer
systemctl stop cs-blockdewd.service
 
#remove systemd files
echo "Removing systemd files..."
rm -f /etc/systemd/system/cs-blockdewd.service
rm -f /etc/systemd/system/cs-blockdewd.timer
 
#reload systemd
systemctl daemon-reload
systemctl reset-failed
 
echo "cs-blockdewd service and timer removed"
 
#optionally remove yq
read -p "Remove yq? (y/n): " answer
if [[ "$answer" == "y" ]]; then
    if command -v apt &> /dev/null; then
        apt remove -y yq
    elif command -v dnf &> /dev/null; then
        dnf remove -y yq
    elif command -v yum &> /dev/null; then
        yum remove -y yq
    else
        rm -f /usr/local/bin/yq
    fi
    echo "yq removed"
else
    echo "yq kept"
fi

# optionally remove grepcidr
read -p "Remove grepcidr? (y/n): " answer
if [[ "$answer" == "y" ]]; then
    if command -v apt &> /dev/null; then
        apt remove -y grepcidr
    elif command -v dnf &> /dev/null; then
        dnf remove -y grepcidr
    elif command -v yum &> /dev/null; then
        yum remove -y grepcidr
    else
        echo "No supported package manager found. Please remove grepcidr manually." >&2
    fi
    echo "grepcidr removed"
else
    echo "grepcidr kept"
fi
sleep 3