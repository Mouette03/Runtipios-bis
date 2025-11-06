#!/bin/bash
# Post-image script for RuntipiOS
# Creates boot files for genimage

set -e

BOARD_DIR="$(dirname $0)"
BINARIES_DIR="${1}"

if [ -z "${BINARIES_DIR}" ]; then
    echo "Error: BINARIES_DIR not provided"
    exit 1
fi

echo "=== RuntipiOS Post-Image Script ==="
echo "BINARIES_DIR: ${BINARIES_DIR}"

# Create cmdline.txt
cat > "${BINARIES_DIR}/cmdline.txt" << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait quiet
EOF

# Copy the appropriate config.txt
# Try to detect board type from available DTB files
if [ -f "${BINARIES_DIR}/bcm2712-rpi-5-b.dtb" ]; then
    echo "Detected Raspberry Pi 5 build"
    if [ -f "${BOARD_DIR}/config_rpi5.txt" ]; then
        cp "${BOARD_DIR}/config_rpi5.txt" "${BINARIES_DIR}/config.txt"
    fi
else
    echo "Detected Raspberry Pi 4 build"
    if [ -f "${BOARD_DIR}/config.txt" ]; then
        cp "${BOARD_DIR}/config.txt" "${BINARIES_DIR}/config.txt"
    fi
fi

# Ensure config.txt exists
if [ ! -f "${BINARIES_DIR}/config.txt" ]; then
    echo "Warning: config.txt not found, creating default"
    cat > "${BINARIES_DIR}/config.txt" << 'EOF'
arm_64bit=1
enable_uart=1
kernel=Image
EOF
fi

echo "Boot configuration files created"
echo "Files in output/images:"
ls -lh "${BINARIES_DIR}/" | head -30

echo "Running genimage..."
GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"
if [ -f "${BINARIES_DIR}/bcm2712-rpi-5-b.dtb" ] && [ -f "${BOARD_DIR}/genimage-rpi5.cfg" ]; then
    GENIMAGE_CFG="${BOARD_DIR}/genimage-rpi5.cfg"
fi

mkdir -p "${BINARIES_DIR}/genimage.tmp"
genimage --rootpath "${BINARIES_DIR}/rootfs" \
                 --tmppath "${BINARIES_DIR}/genimage.tmp" \
                 --inputpath "${BINARIES_DIR}" \
                 --outputpath "${BINARIES_DIR}" \
                 --config "${GENIMAGE_CFG}"

echo "genimage finished using ${GENIMAGE_CFG}"
echo "=== Post-Image Script Completed ==="
