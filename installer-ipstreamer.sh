#!/bin/bash

# IPStreamer Installer - Clean upgrade path
version="1.00"
ipkurl="https://github.com/popking159/ipstreamer/releases/download/IPStreamer/enigma2-plugin-extensions-ipstreamer_${version}_all.ipk"

echo ""
echo "IPStreamer Installer v$version"
echo "============================"

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run as root!"
    exit 1
fi

# Test URL
echo "=== Testing download ==="
if ! wget --spider "$ipkurl" 2>/dev/null; then
    echo "ERROR: IPK not found! Check GitHub releases"
    exit 1
fi

# CHECK & REMOVE PREVIOUS IPStreamer ONLY
echo "=== Checking for previous IPStreamer ==="
if opkg list-installed | grep -q "enigma2-plugin-extensions-ipstreamer"; then
    echo "Previous IPStreamer found - removing..."
    opkg remove enigma2-plugin-extensions-ipstreamer --force-depends
    rm -rf /usr/lib/enigma2/python/Plugins/Extensions/IPStreamer
    echo "✓ IPStreamer removed"
else
    echo "No previous IPStreamer - fresh install"
fi

# Backup playlists ONLY if exist
echo "=== Backing up playlists ==="
if [ -d "/etc/enigma2/ipstreamer" ] && [ "$(ls -A /etc/enigma2/ipstreamer/*.json 2>/dev/null | wc -l)" -gt 0 ]; then
    backup_dir="/tmp/ipstreamerbackup-$(date +%Y%m%d-%H%M%S)"
    cp -r /etc/enigma2/ipstreamer "$backup_dir/"
    echo "✓ Playlists backed up: $backup_dir"
fi

# Download & Install
tmp_dir="/tmp/ipstreamer-install"
mkdir -p "$tmp_dir"
cd "$tmp_dir" || exit 1

echo "=== Downloading v$version ==="
wget -q --show-progress "$ipkurl" -O ipstreamer.ipk || { echo "Download failed!"; rm -rf "$tmp_dir"; exit 1; }

echo "=== Installing ==="
opkg install ./ipstreamer.ipk

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 IPStreamer v$version INSTALLED SUCCESSFULLY!"
    echo "====================================="
    echo "- Plugin: /usr/lib/enigma2/python/Plugins/Extensions/IPStreamer/"
    echo "- Playlists: /etc/enigma2/ipstreamer/"
    echo ""
else
    echo "❌ Installation FAILED!"
    rm -rf "$tmp_dir"
    exit 1
fi

rm -rf "$tmp_dir"
exit 0
