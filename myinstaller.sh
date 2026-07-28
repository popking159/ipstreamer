#!/bin/sh

# =========================================================================
# CONFIGURATION (Change these for different repositories)
# =========================================================================
PLUGIN_NAME="IPStreamer"
USERNAME="popking159"
REPO="ipstreamer"

# 1. PYTHON DEPENDENCIES (Write only the core module names without prefixes)
# The script automatically adds 'python-' for Py2 or 'python3-' for Py3.
PY_DEPENDS="core twisted-web pillow json"

# 2. SYSTEM DEPENDENCIES (Binary utilities installed exactly as written)
SYS_DEPENDS="ffmpeg
gstreamer1.0-plugins-bad-autoconvert
gstreamer1.0-plugins-bad-dash
gstreamer1.0-plugins-bad-faad
gstreamer1.0-plugins-bad-hls
gstreamer1.0-plugins-bad-mpegpsdemux
gstreamer1.0-plugins-bad-mpegtsdemux
gstreamer1.0-plugins-bad-opusparse
gstreamer1.0-plugins-bad-rtmp
gstreamer1.0-plugins-bad-smoothstreaming
gstreamer1.0-plugins-bad-subenc
gstreamer1.0-plugins-bad-videoparsersbad
gstreamer1.0-plugins-base-alsa
gstreamer1.0-plugins-base-app
gstreamer1.0-plugins-base-audioconvert
gstreamer1.0-plugins-base-audiorate
gstreamer1.0-plugins-base-audioresample
gstreamer1.0-plugins-base-ogg
gstreamer1.0-plugins-base-opus
gstreamer1.0-plugins-base-playback
gstreamer1.0-plugins-base-rawparse
gstreamer1.0-plugins-base-subparse
gstreamer1.0-plugins-base-typefindfunctions
gstreamer1.0-plugins-base-videoconvertscale
gstreamer1.0-plugins-base-vorbis
gstreamer1.0-plugins-good-amrnb
gstreamer1.0-plugins-good-amrwbdec
gstreamer1.0-plugins-good-apetag
gstreamer1.0-plugins-good-audioparsers
gstreamer1.0-plugins-good-autodetect
gstreamer1.0-plugins-good-avi
gstreamer1.0-plugins-good-flac
gstreamer1.0-plugins-good-flv
gstreamer1.0-plugins-good-icydemux
gstreamer1.0-plugins-good-id3demux
gstreamer1.0-plugins-good-isomp4
gstreamer1.0-plugins-good-matroska
gstreamer1.0-plugins-good-rtp
gstreamer1.0-plugins-good-rtpmanager
gstreamer1.0-plugins-good-rtsp
gstreamer1.0-plugins-good-soup
gstreamer1.0-plugins-good-udp
gstreamer1.0-plugins-good-wavpack
gstreamer1.0-plugins-good-wavparse
gstreamer1.0-plugins-ugly-asf
gstreamer1.0-plugins-ugly-cdio
gstreamer1.0-plugins-ugly-dvdsub
gstreamer1.0-plugins-base-volume
gstreamer1.0-plugins-bad-audiovisualizers
gstreamer1.0-plugins-good-equalizer"
# =========================================================================

# Dynamically construct the download link
PLUGIN_URL="https://github.com/${USERNAME}/${REPO}/raw/refs/heads/main/main.tar.gz"

# Workspace paths
TMP_DIR="/var/volatile/tmp"
[ -d "$TMP_DIR" ] || TMP_DIR="/tmp"
TMP_FILE="$TMP_DIR/main_install.tar.gz"

PKG_MANAGER=""
PYTHON_VERSION=""
FINAL_DEPENDS=""

log() {
    echo "$1"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

is_pkg_installed() {
    pkg="$1"
    if [ "$PKG_MANAGER" = "opkg" ]; then
        if [ -f /var/lib/opkg/status ]; then
            grep -q "^Package: $pkg$" /var/lib/opkg/status && return 0
        fi
        opkg list-installed 2>/dev/null | grep -q "^$pkg[[:space:]-]" && return 0
        return 1
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" && return 0
        return 1
    fi
    return 1
}

restart_enigma2() {
    log "[INFO] Restarting Enigma2 UI..."
    sleep 2
    if [ -f /usr/bin/systemctl ]; then
        systemctl restart enigma2
    else
        init 4 && sleep 2 && init 3 || killall -9 enigma2 >/dev/null 2>&1
    fi
}

echo "===================================================="
echo "         $PLUGIN_NAME INSTALLER UTILITY            "
echo "===================================================="

# 1. Detect Environment & Python Version
if has_cmd opkg; then
    PKG_MANAGER="opkg"
elif has_cmd apt-get; then
    PKG_MANAGER="apt"
fi
log "[INFO] Package manager detected: ${PKG_MANAGER:-None}"

if has_cmd python3; then
    PYTHON_VERSION="3"
    PY_PREFIX="python3-"
elif has_cmd python; then
    PYTHON_VERSION="2"
    PY_PREFIX="python-"
fi
log "[INFO] Detected Python Environment: Python $PYTHON_VERSION"

# 2. Build the Final Dependency List based on Python version
for dep in $PY_DEPENDS; do
    FINAL_DEPENDS="$FINAL_DEPENDS ${PY_PREFIX}${dep}"
done
for dep in $SYS_DEPENDS; do
    FINAL_DEPENDS="$FINAL_DEPENDS $dep"
done

# 3. Update Package Feeds (Only if dependencies are requested)
if [ -n "$FINAL_DEPENDS" ] && [ -n "$PKG_MANAGER" ]; then
    if [ "$PKG_MANAGER" = "opkg" ]; then
        log "[INFO] Updating opkg feeds..."
        opkg update >/dev/null 2>&1 || log "[WARN] opkg update failed, continuing..."
    elif [ "$PKG_MANAGER" = "apt" ]; then
        log "[INFO] Updating apt feeds..."
        apt-get update >/dev/null 2>&1 || log "[WARN] apt update failed, continuing..."
    fi
fi

# 4. Check and Download Dependencies (Strict Mode)
if [ -n "$FINAL_DEPENDS" ]; then
    log "[INFO] Verifying required dependencies..."
    for pkg in $FINAL_DEPENDS; do
        if is_pkg_installed "$pkg"; then
            log "[OK] Already installed: $pkg"
        else
            log "[INFO] Downloading and installing: $pkg"
            if [ "$PKG_MANAGER" = "opkg" ]; then
                opkg install "$pkg" >/dev/null 2>&1
            elif [ "$PKG_MANAGER" = "apt" ]; then
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1
            fi
            
            # Strict Verification: If it failed to install, abort immediately
            if is_pkg_installed "$pkg"; then
                log "[OK] Successfully installed: $pkg"
            else
                log "[ERROR] Required dependency '$pkg' could not be installed! Aborting setup."
                exit 1
            fi
        fi
    done
else
    log "[INFO] No dependencies specified in configuration. Skipping dependency phase."
fi

# 5. Download Plugin Archive
log "[INFO] Downloading main plugin tree archive..."
rm -f "$TMP_FILE"
wget -q --no-check-certificate "$PLUGIN_URL" -O "$TMP_FILE"

if [ ! -s "$TMP_FILE" ]; then
    log "[ERROR] Download failed or file is empty!"
    rm -f "$TMP_FILE"
    exit 1
fi

# 6. Extract directly to ROOT (/)
log "[INFO] Extracting payload contents to system paths..."
tar -xzf "$TMP_FILE" -C /
if [ $? -ne 0 ]; then
    log "[ERROR] Extraction failed!"
    rm -f "$TMP_FILE"
    exit 1
fi

rm -f "$TMP_FILE"
sync

echo "===================================================="
echo "          $PLUGIN_NAME INSTALLATION COMPLETE        "
echo "===================================================="

restart_enigma2
exit 0
