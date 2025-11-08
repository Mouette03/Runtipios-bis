#!/bin/bash
# Post-image script for RuntipiOS - Raspberry Pi 4
# Creates boot files and SD card image for RPi4

set -e

BOARD_DIR="$(dirname $0)"
COMMON_DIR="${BOARD_DIR}/../common"
BINARIES_DIR="${1}"

if [ -z "${BINARIES_DIR}" ]; then
    echo "Error: BINARIES_DIR not provided"
    exit 1
fi

# Calculate TARGET_DIR (Buildroot doesn't pass it to post-image scripts)
TARGET_DIR="$(dirname ${BINARIES_DIR})/target"

echo "=== RuntipiOS Post-Image Script (Raspberry Pi 4) ==="
echo "BINARIES_DIR: ${BINARIES_DIR}"
echo "TARGET_DIR: ${TARGET_DIR}"
echo "BOARD_DIR: ${BOARD_DIR}"
echo "PWD: $(pwd)"

# Create cmdline.txt
cat > "${BINARIES_DIR}/cmdline.txt" << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait quiet
EOF

# Copy RPi4 config.txt
if [ -f "${BOARD_DIR}/config_rpi4.txt" ]; then
    cp "${BOARD_DIR}/config_rpi4.txt" "${BINARIES_DIR}/config.txt"
    echo "Copied RPi4 config.txt"
else
    echo "Error: RPi4 config.txt not found!"
    exit 1
fi

echo "Boot configuration files created"
echo "Files in output/images:"
ls -lh "${BINARIES_DIR}/" | head -30

echo "Running genimage for Raspberry Pi 4..."
GENIMAGE_CFG="${BOARD_DIR}/genimage-rpi4.cfg"

if [ ! -f "${GENIMAGE_CFG}" ]; then
    echo "Error: genimage-rpi4.cfg not found at ${GENIMAGE_CFG}"
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
