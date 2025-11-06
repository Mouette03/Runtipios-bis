#!/bin/bash
# RuntipiOS Automatic Runtipi Installation Script

set -e

CONFIG_FILE="/etc/runtipi/config.yml"
INSTALL_MARKER="/etc/runtipi/installed"
LOG_FILE="/var/log/runtipi-install.log"
RUNTIPI_DIR="/home/runtipi/app"

log() {
    echo "[RuntipiOS Install] $1" | tee -a "$LOG_FILE"
}

if [ -f "$INSTALL_MARKER" ]; then
    log "Runtipi already installed, skipping installation"
    exit 0
fi

log "Starting Runtipi installation..."

log "Waiting for network connectivity..."
for i in {1..60}; do
    if ping -c 1 8.8.8.8 &>/dev/null; then
        log "Network is available"
        break
    fi
    if [ $i -eq 60 ]; then
        log "ERROR: Network is not available after 60 seconds"
        exit 1
    fi
    sleep 1
done

IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)

log "System IP: $IP"
log "Hostname: $HOSTNAME"

mkdir -p "$RUNTIPI_DIR"
chown runtipi:runtipi "$RUNTIPI_DIR"

log "Downloading Runtipi installation script..."
cd "$RUNTIPI_DIR"

INSTALL_SCRIPT=$(mktemp)
if curl -fsSL -o "$INSTALL_SCRIPT" https://raw.githubusercontent.com/meienberger/runtipi/master/scripts/install.sh; then
    log "Installation script downloaded successfully"
    chmod +x "$INSTALL_SCRIPT"

    log "Running Runtipi installation..."
    if bash "$INSTALL_SCRIPT"; then
        log "Runtipi installation completed successfully"
        touch "$INSTALL_MARKER"
        log "Installation marker created"
    else
        log "ERROR: Runtipi installation failed"
        exit 1
    fi

    rm -f "$INSTALL_SCRIPT"
else
    log "ERROR: Failed to download installation script"
    exit 1
fi

log "Runtipi installation finished"
exit 0
