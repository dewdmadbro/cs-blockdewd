# 🛡️ CS-BlockDewd

> Automated blocklist pulling and importing for [CrowdSec](https://www.crowdsec.net/), designed to reduce redundant decisions and minimize hardware impact.

[![License](https://img.shields.io/github/license/dewdmadbro/cs-blockdewd)](https://github.com/dewdmadbro/cs-blockdewd/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)]()
[![Latest Release](https://img.shields.io/github/v/release/dewdmadbro/cs-blockdewd)](https://github.com/dewdmadbro/cs-blockdewd/releases/latest)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Updating](#updating)
- [Uninstallation](#uninstallation)
- [Removing Decisions](#removing-decisions)
- [How It Works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Disclaimer](#disclaimer)

---

## Overview

CS-BlockDewd automates the process of fetching IP blocklists from multiple sources and importing them into CrowdSec. It intelligently filters out duplicate and redundant entries before creating decisions, resulting in:

- ✅ Cleaner decision lists
- ✅ Reduced log flooding (only 1 alert per import)
- ✅ Hopefuly minimal hardware impact
- ✅ Set-and-forget operation via systemd

---

## Features

| Feature | Description |
|---------|-------------|
| **YAML Configuration** | Simple, human-readable config via `config.yaml` |
| **Automated Scheduling** | Runs on a configurable timer via systemd (default: every 6 hours) |
| **Duplicate Filtering** | Removes duplicate entries from all pulled lists |
| **GeoIP Integration** | Optional `geoip-shell` integration to skip already-geoblocked IPs |
| **CIDR Range Checking** | Prevents redundant decisions by checking against existing CIDR ranges |
| **Active Decision Checking** | Validates against existing CrowdSec decisions before importing |
| **Docker & Native Support** | Works with both CrowdSec Docker containers and native installations |
| **Custom Blocklists** | Support for adding your own custom blocklist file |

---

## Requirements

### Required
- **Linux** (tested on Linux Mint; Ubuntu/Debian-based distros recommended)
- **CrowdSec** installed and running (native or Docker)
- **systemd** for scheduling and automation
- **CrowdSec Bouncer API Key** ([docs](https://docs.crowdsec.net/docs/next/cscli/cscli_bouncers_add/))

### Optional (Highly Recommended)
- **[geoip-shell](https://github.com/friendly-bits/geoip-shell)** – Enables geoblocking filtering (whitelist or blacklist mode)

### Auto-Installed Dependencies
The installer will automatically install these if missing:
- **yq** – YAML processor
- **grepcidr** – CIDR range matching tool

---

## Installation

### 1. Download the Latest Release

```bash
LOCATION=$(curl -s https://api.github.com/repos/dewdmadbro/cs-blockdewd/releases/latest \
  | grep "tarball_url" \
  | awk '{ print $2 }' \
  | sed 's/,$//'       \
  | sed 's/"//g' )     \
; curl -L -o cs-blockdewd.tar.gz $LOCATION
```

### 2. Extract Files

```bash
tar -xvzf cs-blockdewd.tar.gz --one-top-level --strip-components=1
rm cs-blockdewd.tar.gz
cd cs-blockdewd
```

### 3. Configure

Edit the configuration file with your preferred editor:

```bash
nano config.yaml
```

### 4. Install & Run

```bash
chmod +x blockdewd.sh
sudo ./blockdewd.sh install
```

The installer will:
- Check and install `yq` and `grepcidr` if needed
- Create systemd service and timer files
- Run the service for the first time
- Generate logs in the installation directory

---

## Configuration

Edit `config.yaml` to customize behavior:

| Key | Description | Example |
|-----|-------------|---------|
| `bouncerkey` | Your CrowdSec API key | `"your-api-key-here"` |
| `ban_duration` | Duration for imported bans | `"72h"` |
| `cs_container` | Docker container name (if using Docker) | `"crowdsec"` |
| `systemd_timer` | Hours between runs | `6h` |
| `geoip_mode` | GeoIP filtering mode (`whitelist` or `blacklist`) | `"whitelist"` |
| `myblocklist` | Path to custom blocklist file | `"/path/to/custom.list"` |
| `urls_standard` | Array of blocklist URLs to fetch | `["https://...", "..."]` |

---

## Usage

### Check Service Status

```bash
sudo systemctl status cs-blockdewd
```

### View Timer Schedule & History

```bash
sudo systemctl list-timers
```

### View Logs

```bash
cat cs-blockdewd.log
```

### Manual Run

```bash
sudo ./blockdewd.sh run
```

---

## Updating

```bash
cd cs-blockdewd
sudo ./blockdewd.sh update
```

> **Note:** Updates preserve your `config.yaml` file.

---

## Uninstallation

```bash
cd cs-blockdewd
sudo ./blockdewd.sh remove
```

This will:
- Stop and disable the systemd service and timer
- Remove systemd unit files
- Reload systemd daemon
- Prompt to remove `yq` and `grepcidr` (optional)

---

## Removing Decisions

To remove all decisions imported by CS-BlockDewd:

### Docker Installation
```bash
sudo docker exec crowdsec cscli decisions delete --origin cscli-import
```

### Native Installation
```bash
cscli decisions delete --origin cscli-import
```

---

## How It Works

```
┌─────────────────────┐
│  Fetch Blocklists   │  Downloads IPs from configured URLs
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  Remove Duplicates  │  Deduplicates and sorts entries
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  GeoIP Filter       │  (Optional) Filters via geoip-shell
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  CIDR Check         │  Removes IPs covered by CIDR ranges
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  Existing Decisions │  Skips IPs already in CrowdSec
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  Import to CrowdSec │  Creates decisions (single alert)
└─────────────────────┘
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Service fails to start | Check logs: `cat cs-blockdewd.log` |
| API key errors | Verify `bouncerkey` in `config.yaml` |
| Docker import fails | Confirm container name matches `cs_container` |
| GeoIP filtering not working | Ensure `geoip-shell` is installed and in PATH |

---

## Disclaimer

> This tool was developed and tested on **Linux Mint**. It should work on Ubuntu and other Debian-based distributions. While it works well for my use case, it may not be the optimal solution for all environments. Use at your own discretion and test in your environment before relying on it in production and make sure you have appropriate allowlists set up.

---

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgments

- [CrowdSec](https://www.crowdsec.net/) – Open-source IPS
- [geoip-shell](https://github.com/friendly-bits/geoip-shell) – GeoIP lookup tool
- [yq](https://github.com/mikefarah/yq) – YAML processor
- [grepcidr](https://github.com/jamespurcell/grepcidr) – CIDR matching utility
