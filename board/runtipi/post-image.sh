#!/bin/bash
# Post-image script for RuntipiOS
# Creates the final disk image with boot and root partitions

set -e

BOARD_DIR="$(dirname $0)"
GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

echo "=== RuntipiOS Post-Image Script ==="

# Create boot configuration
cat > "${BINARIES_DIR}/config.txt" << 'EOF'
# RuntipiOS Boot Configuration
# See https://www.raspberrypi.com/documentation/computers/config_txt.html

# GPU Memory
gpu_mem=128

# Enable audio
dtparam=audio=on

# Enable I2C and SPI
dtparam=i2c_arm=on
dtparam=spi=on

# Enable UART
enable_uart=1

# Disable splash screen
disable_splash=1

# Boot faster
boot_delay=0
disable_overscan=1

# 64-bit mode
arm_64bit=1

# Kernel
kernel=kernel8.img

# Device Tree overlays
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Camera
start_x=0

# Overclocking (optional, uncommented for safety)
#over_voltage=2
#arm_freq=1800
EOF

# Create cmdline.txt
cat > "${BINARIES_DIR}/cmdline.txt" << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait quiet loglevel=3 logo.nologo vt.global_cursor_default=0
EOF

# Copy additional boot files
cp "${BOARD_DIR}/config.txt" "${BINARIES_DIR}/config.txt" 2>/dev/null || true

echo "Boot files created successfully"
echo "=== Post-Image Script Completed ==="
