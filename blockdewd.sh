#!/bin/bash

usage() {
    echo "Usage: $0 [install|remove|run|update]"
    exit 1
}

# Helpers
die()  { echo "❌  $*" >&2; exit 1; }
info() { echo "ℹ️   $*"; }
ok()   { echo "✅  $*"; }

install() {
    #sudo check
    if [[ $EUID -ne 0 ]]; then
    die "This must be run as root (use sudo)"
    fi
    # check for yq and install if needed
    if command -v yq &> /dev/null; then
        ok "yq is already installed: $(yq --version)"
    else
        info "yq not found, installing..."
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
            info "No package manager found, falling back to direct download..."
            wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
            chmod +x /usr/local/bin/yq
        fi
        ok "yq installed: $(yq --version)"
    fi

    # Load variables from config.yaml
    TIMER=$(yq -r '.systemd_timer' config.yaml)

    # check for grepcidr and install if needed
    if command -v grepcidr &> /dev/null; then
        ok "grepcidr is already installed: $(grepcidr 2>&1 | head -1)"
    else
        info "grepcidr not found, installing..."
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
            die "No supported package manager found. Please install grepcidr manually."
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
ExecStart=$PWD/blockdewd.sh run
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
}

remove() {
    #sudo check
    if [[ $EUID -ne 0 ]]; then
    die "This must be run as root (use sudo)"
    fi
    # stop and disable timer and service
    info "Stopping and disabling cs-blockdewd timer and service..."
    systemctl stop cs-blockdewd.timer
    systemctl disable cs-blockdewd.timer
    systemctl stop cs-blockdewd.service
    systemctl disable cs-blockdewd.service

    # remove systemd files
    info "Removing systemd files..."
    rm -f /etc/systemd/system/cs-blockdewd.service
    rm -f /etc/systemd/system/cs-blockdewd.timer

    # reload systemd
    systemctl daemon-reload
    systemctl reset-failed cs-blockdewd.service cs-blockdewd.timer

    ok "cs-blockdewd service and timer removed"

    # optionally remove yq
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
        ok "yq removed"
    else
        ok "yq kept"
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
            info "No supported package manager found. Please remove grepcidr manually." >&2
        fi
        ok "grepcidr removed"
    else
        ok "grepcidr kept"
    fi
    sleep 3
}

run() {
    bash "$PWD/cs-blockdewd.sh"
}

update() {
    info "updating....."
    #curl lastest package
    LOCATION=$(curl -s https://api.github.com/repos/dewdmadbro/cs-blockdewd/releases/latest \
    | grep "tarball_url" \
    | awk '{ print $2 }' \
    | sed 's/,$//'       \
    | sed 's/"//g' )     \
    ; curl -L -o cs-blockdewd.tar.gz $LOCATION
    sleep 1

    #extract files overwriting files excluding config
    tar -xvzf cs-blockdewd.tar.gz --strip-components=1 --exclude="config.yaml"
    rm cs-blockdewd.tar.gz

    #makes files excutable
    chmod +x blockdewd.sh
    chmod +x cs-blockdewd.sh
    ok "complete....."
    sleep 1
}

case "$1" in
    install) install ;;
    remove)  remove  ;;
    run)     run     ;;
    update)  update  ;;
    *)       usage   ;;
esac

