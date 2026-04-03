#!/bin/bash

# check for yq and install if needed
if command -v yq &> /dev/null; then
    echo "yq is already installed: $(yq --version)"
else
    echo "yq not found, installing..."
    if command -v apt &> /dev/null; then
        echo "Using apt..."
        apt install -y yq
    elif command -v dnf &> /dev/null; then
        echo "Using dnf..."
        dnf install -y yq
    elif command -v yum &> /dev/null; then
        echo "Using yum..."
        yum install -y yq
    else
        echo "No package manager found, falling back to direct download..."
        wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        chmod +x /usr/local/bin/yq
    fi
    echo "yq installed: $(yq --version)"
fi

# Load variables from config.yaml
TIMER=$(yq -r '.systemd_timer' config.yaml)

# check for grepcidr and install if needed
if command -v grepcidr &> /dev/null; then
    echo "grepcidr is already installed: $(grepcidr 2>&1 | head -1)"
else
    echo "grepcidr not found, installing..."
    if command -v apt &> /dev/null; then
        echo "Using apt..."
        apt install -y grepcidr
    elif command -v dnf &> /dev/null; then
        echo "Using dnf..."
        dnf install -y grepcidr
    elif command -v yum &> /dev/null; then
        echo "Using yum..."
        yum install -y grepcidr
    else
        echo "No supported package manager found. Please install grepcidr manually." >&2
        exit 1
    fi
fi

chmod +x $PWD/cs-blockdewd.sh

# make systemd service file
cat > /etc/systemd/system/cs-blockdewd.service << EOF
[Unit]
Description=pull lists and run crowdsec blockist imports every $TIMER hours
[Service]
Type=oneshot
WorkingDirectory=$PWD
ExecStart=$PWD/cs-blockdewd.sh
StandardOutput=file:$PWD/cs-blockdewd.log
[Install]
WantedBy=multi-user.target
EOF
echo "Service File Created"

# make systemd timer file
cat > /etc/systemd/system/cs-blockdewd.timer << EOF
[Unit]
Description=Timer to run csblock every $TIMER hours
[Timer]
OnUnitActiveSec=$TIMER
Persistent=true
AccuracySec=1us
Unit=cs-blockdewd.service
[Install]
WantedBy=timers.target
EOF
echo "Timer File Created"

# start timer and first run of service
systemctl daemon-reload
systemctl enable cs-blockdewd.timer
systemctl start cs-blockdewd.timer
echo "Service Timer Enabled And Started"
sleep 1
echo "Running Service"
systemctl start cs-blockdewd
echo "First run completed. You can check the status with:"
echo "sudo systemctl status cs-blockdewd"
echo "You can view timers and runs with:"
echo "sudo systemctl list-timers"
sleep 2
echo "Install Complete, Bye"
sleep 1