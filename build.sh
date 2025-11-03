#!/bin/bash
set -e

# Build script for RuntipiOS
echo "📦 Building RuntipiOS with captive portal..."

# Load config
CONFIG_FILE="config.yml"
IMG_URL=$(grep 'url:' $CONFIG_FILE | awk '{print $2}' | tr -d '"')
IMG_FILE=$(basename $IMG_URL)

# Download base image
wget -O $IMG_FILE $IMG_URL

# Mount and prepare image
mkdir -p mnt
LOOP=$(losetup -fP --show $IMG_FILE)
mount ${LOOP}p2 mnt

# Copy scripts
mkdir -p mnt/opt/runtipi-hotspot
cp -r scripts mnt/opt/runtipi-hotspot/
cp -r www mnt/opt/runtipi-hotspot/

# Setup userconf
bash scripts/00-setup-userconf.sh

# Unmount and cleanup
umount mnt
losetup -d $LOOP

echo "✅ Build complete. Flash the image to your SD card and boot your Raspberry Pi."
