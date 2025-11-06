#!/bin/bash
# RuntipiOS Network Setup Script
# Detects if Ethernet is available, otherwise starts WiFi captive portal

set -e

CONFIG_FILE="/etc/runtipi/config.yml"
LOCK_FILE="/run/runtipi-network-setup.lock"

if [ -f "$LOCK_FILE" ]; then
    exit 0
fi

touch "$LOCK_FILE"

log() {
    echo "[RuntipiOS Network] $1" | tee -a /var/log/runtipi-network.log
}

get_config_value() {
    local key=$1
    local default=$2

    if [ -f "$CONFIG_FILE" ]; then
        grep "^${key}:" "$CONFIG_FILE" | cut -d':' -f2 | xargs || echo "$default"
    else
        echo "$default"
    fi
}

log "Starting network detection..."

sleep 2

if ip link show | grep -q "eth0\|enp"; then
    log "Ethernet interface detected, waiting for connection..."

    for i in {1..30}; do
        if ethtool eth0 2>/dev/null | grep -q "Link detected: yes"; then
            log "Ethernet link detected, starting DHCP..."
            systemctl start systemd-networkd
            sleep 5

            dhcpcd -t 30 eth0 2>/dev/null || true

            ETHERNET_IP=$(hostname -I | awk '{print $1}')
            if [ ! -z "$ETHERNET_IP" ]; then
                log "Ethernet configured with IP: $ETHERNET_IP"
                exit 0
            fi
        fi
        sleep 1
    done

    log "Ethernet not connected after 30 seconds, falling back to WiFi"
fi

log "No Ethernet connection, starting WiFi captive portal..."
systemctl start runtipi-captive.service

exit 0
