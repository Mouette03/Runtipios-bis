#!/bin/bash
# Post-image script for RuntipiOS
# Creates the final disk image with boot and root partitions

set -e

BOARD_DIR="$(dirname $0)"
BINARIES_DIR="${1}"

echo "=== RuntipiOS Post-Image Script ==="
echo "BOARD_DIR: ${BOARD_DIR}"
echo "BINARIES_DIR: ${BINARIES_DIR}"

# Determine which board we're building for
if [ -f "${BINARIES_DIR}/.config" ]; then
    if grep -q "bcm2712" "${BINARIES_DIR}/.config" 2>/dev/null; then
        BOARD_TYPE="rpi5"
    else
        BOARD_TYPE="rpi4"
    fi
else
    BOARD_TYPE="rpi4"
fi

echo "Board type detected: ${BOARD_TYPE}"

# Create boot configuration based on board type
if [ "${BOARD_TYPE}" = "rpi5" ]; then
    CONFIG_TXT="${BOARD_DIR}/config_rpi5.txt"
    KERNEL_NAME="kernel_2712.img"
else
    CONFIG_TXT="${BOARD_DIR}/config.txt"
    KERNEL_NAME="Image"
fi

# Copy config.txt
if [ -f "${CONFIG_TXT}" ]; then
    cp "${CONFIG_TXT}" "${BINARIES_DIR}/config.txt"
    echo "Copied ${CONFIG_TXT} to ${BINARIES_DIR}/config.txt"
else
    echo "Warning: ${CONFIG_TXT} not found, using default"
fi

# Create cmdline.txt
cat > "${BINARIES_DIR}/cmdline.txt" << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait quiet loglevel=3 logo.nologo vt.global_cursor_default=0
EOF

echo "Created cmdline.txt"

# Rename kernel if needed
if [ -f "${BINARIES_DIR}/Image" ] && [ "${KERNEL_NAME}" != "Image" ]; then
    cp "${BINARIES_DIR}/Image" "${BINARIES_DIR}/${KERNEL_NAME}"
    echo "Copied kernel as ${KERNEL_NAME}"
fi

# List files for debugging
echo "Files in ${BINARIES_DIR}:"
ls -lh "${BINARIES_DIR}/" | head -20

echo "=== Post-Image Script Completed ==="
