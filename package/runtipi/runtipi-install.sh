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

echo "Installing Runtipi with Docker..."

# Ensure we're in the right directory
mkdir -p "$RUNTIPI_DIR"
cd "$RUNTIPI_DIR"

# Install Runtipi using official installer (includes Docker)
# This will install Docker if not present and set up Runtipi
curl -L https://setup.runtipi.io | bash

# Wait for installation to complete
sleep 5

# Mark as installed
mkdir -p "$STATE_DIR"
touch "$INSTALL_FLAG"
echo "Runtipi installation completed successfully"

# Display access information
echo ""
echo "=========================================="
echo "Runtipi is now installed!"
echo "Access it at: http://$(hostname -I | awk '{print $1}')"
echo "Or: http://$(hostname).local"
echo "=========================================="
