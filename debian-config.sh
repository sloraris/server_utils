#!/usr/bin/env bash
#
# SCRIPT: debian-config.sh
# DESCRIPTION: Unified onboarding script for Debian (AMD64) & RasPi OS (ARM64).
#
################################################################################

set -e

# --- Configuration Variables ---
TIME_ZONE="America/Denver"
DEFAULT_KOMODO_CORE="https://komodo.local"
# -------------------------------

# 1. Privilege Check
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root"
   exit 1
fi

# 2. Hardware / Architecture Detection
IS_RPI=false
if [[ "$(uname -m)" == "aarch64" ]] && [[ -d "/boot/firmware" ]]; then
    IS_RPI=true
fi

# 3. Upfront Prompts 
# Gather all interactive inputs first so the rest of the script can run unattended
echo "============================================="
echo "  System Onboarding - $(hostname)"
echo "============================================="
echo ""

read -s -p "Enter Komodo Onboarding Key (leave blank to skip Komodo): " KOMODO_KEY
echo ""
if [[ -n "$KOMODO_KEY" ]]; then
    read -p "Enter Komodo Core Address (hit enter for default [$DEFAULT_KOMODO_CORE]): " KOMODO_CORE
    KOMODO_CORE=${KOMODO_CORE:-$DEFAULT_KOMODO_CORE}
fi

echo ""
read -r -p "Install Docker? (y/N): " DOCKER_CHOICE
read -r -p "Perform soft reboot when finished? (y/N): " REBOOT_CHOICE

echo ""
echo "============================================="
echo "Starting automated configuration..."
echo "============================================="

## 4. System Updates
# ----------------------------------------------------
echo "-> Running System Updates and Upgrades..."
apt update -y
apt upgrade -y
apt install -y curl python3 ca-certificates

## 5. Set Timezone
# ----------------------------------------------------
echo "-> Setting Timezone to: ${TIME_ZONE}"
timedatectl set-timezone "${TIME_ZONE}"

## 6. Raspberry Pi Specific: Disable Wireless Interfaces
# ----------------------------------------------------
if [ "$IS_RPI" = true ]; then
    echo "-> ARM64 Pi Detected: Disabling wireless interfaces"
    CONFIG_FILE="/boot/firmware/config.txt"
    
    if ! grep -q "dtoverlay=disable-wifi" "$CONFIG_FILE"; then
        echo "dtoverlay=disable-wifi" >> "$CONFIG_FILE"
        echo "   Added disable-wifi to config.txt"
    fi

    if ! grep -q "dtoverlay=disable-bt" "$CONFIG_FILE"; then
        echo "dtoverlay=disable-bt" >> "$CONFIG_FILE"
        echo "   Added disable-bt to config.txt"
    fi
else
    echo "-> Standard Architecture Detected: Skipping Pi-specific configuration"
fi

## 7. Configure motd
# ----------------------------------------------------
echo "-> Configuring ANSI motd"
curl -fsSL https://raw.githubusercontent.com/sloraris/server-utils/refs/heads/main/motd.sh | bash

## 8. Install Docker
# ----------------------------------------------------
if [[ "$DOCKER_CHOICE" =~ ^[Yy]$ ]]; then
    if ! command -v docker &> /dev/null; then
        echo "-> Installing Docker via convenience script..."
        curl -fsSL https://get.docker.com -o ./install-docker.sh
        bash ./install-docker.sh
        rm ./install-docker.sh
    else
        echo "-> Docker is already installed. Skipping."
    fi
else
    echo "-> Skipping Docker install."
fi

## 9. Install Komodo Periphery
# ----------------------------------------------------
if [[ -n "$KOMODO_KEY" ]]; then
    echo "-> Fetching and executing the Komodo Periphery installer..."
    curl -sSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py \
      | python3 - \
      --core-address="${KOMODO_CORE}" \
      --connect-as="$(hostname)" \
      --onboarding-key="${KOMODO_KEY}"
    echo "-> Komodo Periphery installation completed."
else
    echo "-> No onboarding key provided. Skipping Komodo installation."
fi

## 10. Finalizing
# ----------------------------------------------------
echo ""
echo "--- Setup Script Finished ---"
echo "Debian is now updated and configured for $(hostname)."

if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    echo "Rebooting now..."
    reboot
else
    echo "Please consider rebooting manually soon to apply kernel updates."
fi
