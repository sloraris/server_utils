#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root." 
   exit 1
fi

echo "--- MergerFS Install/Update Script ---"

# Ensure prerequisites are installed
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null || ! command -v lsb_release &> /dev/null; then
    echo "[*] Installing required dependencies..."
    apt-get update -qq && apt-get install -y -qq curl jq lsb-release
fi

# Detect system architecture and Debian codename
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)

echo "[*] Detected System: Debian $CODENAME ($ARCH)"

# Fetch the latest release data from GitHub API
REPO="trapexit/mergerfs"
API_URL="https://api.github.com/repos/$REPO/releases/latest"

echo "[*] Checking latest release from GitHub..."
LATEST_JSON=$(curl -sL --fail "$API_URL") || { echo "Error: Failed to fetch release data from GitHub."; exit 1; }

# Extract the version tag (stripping any leading 'v' if present, though trapexit typically doesn't use them)
LATEST_VERSION=$(echo "$LATEST_JSON" | jq -r '.tag_name' | sed 's/^v//')

# Check the currently installed version via dpkg
if dpkg-query -W -f='${Status}' mergerfs 2>/dev/null | grep -q "ok installed"; then
    INSTALLED_VERSION=$(dpkg-query -W -f='${Version}\n' mergerfs)
else
    INSTALLED_VERSION="none"
fi

echo " -> Latest available : $LATEST_VERSION"
echo " -> Currently installed: $INSTALLED_VERSION"

# Idempotency check: if the latest version is already installed, exit cleanly
if [[ "$INSTALLED_VERSION" == *"$LATEST_VERSION"* ]]; then
    echo "[✔] MergerFS is already up to date."
    exit 0
fi

# Extract the appropriate download URL for the target OS and Architecture
# We are looking for an asset matching: *debian-{CODENAME}*{ARCH}.deb
DOWNLOAD_URL=$(echo "$LATEST_JSON" | jq -r \
    --arg os "debian-$CODENAME" \
    --arg arch "$ARCH" \
    '.assets[] | select(.name | contains($os) and contains($arch) and endswith(".deb")) | .browser_download_url' | head -n1)

if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
    echo "Error: Could not find a pre-compiled .deb for Debian $CODENAME ($ARCH) in release $LATEST_VERSION."
    echo "This might mean the repository hasn't compiled a package for your specific version yet."
    exit 1
fi

# Setup secure temporary file cleanup
TMP_DEB=$(mktemp /tmp/mergerfs_${LATEST_VERSION}_XXXXXX.deb)
trap 'rm -f "$TMP_DEB"' EXIT

echo "[*] Downloading package from: $DOWNLOAD_URL"
curl -sL --fail -o "$TMP_DEB" "$DOWNLOAD_URL"

echo "[*] Installing MergerFS..."
# Using 'apt-get install ./' instead of 'dpkg -i' automatically pulls down any missing dependencies
apt-get install -y "$TMP_DEB"

echo "[✔] MergerFS has been successfully updated to $LATEST_VERSION!"
