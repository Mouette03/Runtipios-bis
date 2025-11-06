#!/bin/bash
# Runtipi installation script
# This script is called by the runtipi-install systemd service on first boot

set -e

RUNTIPI_DIR="/opt/runtipi"
STATE_DIR="$RUNTIPI_DIR/state"
INSTALL_FLAG="$STATE_DIR/.installed"

# Exit if already installed
if [ -f "$INSTALL_FLAG" ]; then
    echo "Runtipi already installed"
    exit 0
fi

echo "Installing Runtipi..."

# Ensure Docker is running
systemctl is-active --quiet docker || systemctl start docker

# Wait for Docker to be ready
timeout=30
while ! docker info >/dev/null 2>&1; do
    if [ $timeout -le 0 ]; then
        echo "Docker failed to start"
        exit 1
    fi
    echo "Waiting for Docker..."
    sleep 2
    timeout=$((timeout - 2))
done

# Download and install Runtipi
cd "$RUNTIPI_DIR"

# Clone or download Runtipi
if [ ! -d "$RUNTIPI_DIR/.git" ]; then
    git clone https://github.com/runtipi/runtipi.git /tmp/runtipi-src
    cp -r /tmp/runtipi-src/* "$RUNTIPI_DIR/"
    rm -rf /tmp/runtipi-src
fi

# Run Runtipi setup
if [ -x "$RUNTIPI_DIR/scripts/install.sh" ]; then
    bash "$RUNTIPI_DIR/scripts/install.sh"
elif [ -x "$RUNTIPI_DIR/runtipi-cli" ]; then
    ./runtipi-cli setup
fi

# Mark as installed
touch "$INSTALL_FLAG"
echo "Runtipi installation completed"
