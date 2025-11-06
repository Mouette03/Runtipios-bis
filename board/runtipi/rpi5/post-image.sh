#!/bin/bash
# Post-image script for RuntipiOS - Raspberry Pi 5
# Creates boot files and SD card image for RPi5

set -e

BOARD_DIR="$(dirname $0)"
COMMON_DIR="${BOARD_DIR}/../common"
BINARIES_DIR="${1}"

if [ -z "${BINARIES_DIR}" ]; then
    echo "Error: BINARIES_DIR not provided"
    exit 1
fi

echo "=== RuntipiOS Post-Image Script (Raspberry Pi 5) ==="
echo "BINARIES_DIR: ${BINARIES_DIR}"
echo "BOARD_DIR: ${BOARD_DIR}"

# Create cmdline.txt
cat > "${BINARIES_DIR}/cmdline.txt" << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait quiet
EOF

# Copy RPi5 config.txt
if [ -f "${BOARD_DIR}/config_rpi5.txt" ]; then
    cp "${BOARD_DIR}/config_rpi5.txt" "${BINARIES_DIR}/config.txt"
    echo "Copied RPi5 config.txt"
else
    echo "Error: RPi5 config.txt not found!"
    exit 1
fi

echo "Boot configuration files created"
echo "Files in output/images:"
ls -lh "${BINARIES_DIR}/" | head -30

echo "Running genimage for Raspberry Pi 5..."
GENIMAGE_CFG="${BOARD_DIR}/genimage-rpi5.cfg"

if [ ! -f "${GENIMAGE_CFG}" ]; then
    echo "Error: genimage-rpi5.cfg not found at ${GENIMAGE_CFG}"
    exit 1
fi

# Create genimage temp directory
GENIMAGE_TMP="${BINARIES_DIR}/genimage.tmp"
rm -rf "${GENIMAGE_TMP}"

genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath "${GENIMAGE_TMP}" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

echo "genimage finished successfully"
echo "Generated files:"
ls -lh "${BINARIES_DIR}/"*.img 2>/dev/null || echo "No .img files found"
echo "=== Post-Image Script Completed ==="
