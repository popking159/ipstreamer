#!/bin/sh

# =========================================================================
# One-liner execution command:
# wget -qO - https://raw.githubusercontent.com/popking159/ipstreamer/refs/heads/main/installer.sh | /bin/sh
# =========================================================================

PLUGIN_NAME="IPStreamer"
PKG_BASE="enigma2-plugin-extensions-ipstreamer"
VERSION="1.4.0"
USERNAME="popking159"
REPO="ipstreamer"
ARCH="all"

TMP_DIR="/var/volatile/tmp"
[ -d "$TMP_DIR" ] || TMP_DIR="/tmp"

log() {
    echo "$1"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

echo "===================================================="
echo "         $PLUGIN_NAME UNIVERSAL INSTALLER           "
echo "                 by MNASR                           "
echo "===================================================="

# 1. Detect Package Manager
if has_cmd opkg; then
    PKG_MANAGER="opkg"
elif has_cmd apt-get; then
    PKG_MANAGER="apt"
else
    log "[ERROR] No supported package manager (opkg/apt) found!"
    exit 1
fi
log "[INFO] Package manager detected: ${PKG_MANAGER}"

# 2. Construct Universal IPK URL
IPK_NAME="${PKG_BASE}_${VERSION}_${ARCH}.ipk"
PLUGIN_URL="https://github.com/${USERNAME}/${REPO}/raw/refs/heads/main/${IPK_NAME}"
TMP_FILE="$TMP_DIR/$IPK_NAME"

log "[INFO] Target Package: $IPK_NAME"

# 3. Update Package Feeds
log "[INFO] Updating package feeds..."
if [ "$PKG_MANAGER" = "opkg" ]; then
    opkg update >/dev/null 2>&1 || log "[WARN] opkg update failed, attempting installation anyway..."
elif [ "$PKG_MANAGER" = "apt" ]; then
    apt-get update >/dev/null 2>&1 || log "[WARN] apt-get update failed, attempting installation anyway..."
fi

# 4. Download IPK Archive
log "[INFO] Downloading IPK package..."
rm -f "$TMP_FILE"

if has_cmd wget; then
    wget -q --no-check-certificate "$PLUGIN_URL" -O "$TMP_FILE"
elif has_cmd curl; then
    curl -s -k -L "$PLUGIN_URL" -o "$TMP_FILE"
fi

if [ ! -s "$TMP_FILE" ] || grep -q -i "<html" "$TMP_FILE" || grep -q "404: Not Found" "$TMP_FILE"; then
    log "[ERROR] Download failed! The package $IPK_NAME does not exist on GitHub."
    rm -f "$TMP_FILE"
    exit 1
fi

# 5. Install the IPK
log "[INFO] Installing package and resolving dependencies..."
if [ "$PKG_MANAGER" = "opkg" ]; then
    opkg install --force-reinstall --force-overwrite "$TMP_FILE"
elif [ "$PKG_MANAGER" = "apt" ]; then
    dpkg -i "$TMP_FILE"
    apt-get install -f -y
fi

if [ $? -ne 0 ]; then
    log "[ERROR] Installation failed!"
    rm -f "$TMP_FILE"
    exit 1
fi

# 6. Cleanup and Finalize
rm -f "$TMP_FILE"
sync

echo "===================================================="
echo "          $PLUGIN_NAME INSTALLATION COMPLETE        "
echo "===================================================="
echo "[INFO] Universal plugin installed successfully."
echo "[INFO] Restarting Enigma2 GUI to apply changes..."

if has_cmd wget; then
    wget -qO - "http://127.0.0.1/web/powerstate?newstate=3" >/dev/null 2>&1
elif has_cmd curl; then
    curl -s "http://127.0.0.1/web/powerstate?newstate=3" >/dev/null 2>&1
fi

exit 0