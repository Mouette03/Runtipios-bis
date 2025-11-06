#!/bin/bash
# RuntipiOS Captive Portal Script
# Sets up WiFi AP and captive portal for initial WiFi configuration

set -e

CONFIG_FILE="/etc/runtipi/config.yml"
SSID="RuntipiOS-Setup"
PASSWORD=""
INTERFACE="wlan0"
IP="192.168.99.1"
NETMASK="255.255.255.0"

log() {
    echo "[RuntipiOS Captive] $1" | tee -a /var/log/runtipi-captive.log
}

if ! ip link show "$INTERFACE" &>/dev/null; then
    log "ERROR: WiFi interface $INTERFACE not found"
    exit 1
fi

log "Starting captive portal setup..."

if [ -f "$CONFIG_FILE" ]; then
    SSID=$(grep "ssid:" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "$SSID")
    PASSWORD=$(grep "password:" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "$PASSWORD")
fi

log "Bringing up $INTERFACE..."
ip link set "$INTERFACE" up

log "Configuring IP address..."
ip addr flush dev "$INTERFACE"
ip addr add "$IP/24" dev "$INTERFACE"

log "Starting DHCP server (dnsmasq)..."
cat > /tmp/dnsmasq-captive.conf << EOF
interface=$INTERFACE
listen-address=$IP
dhcp-range=192.168.99.10,192.168.99.250,12h
dhcp-option=option:router,$IP
dhcp-option=option:dns-server,$IP
address=/#/$IP
log-queries
log-dhcp
EOF

dnsmasq -C /tmp/dnsmasq-captive.conf &
sleep 2

log "Starting WiFi access point: $SSID..."
cat > /tmp/hostapd-captive.conf << EOF
interface=$INTERFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
wmm_enabled=1
auth_algs=1
wpa=0
EOF

if [ ! -z "$PASSWORD" ]; then
    cat >> /tmp/hostapd-captive.conf << EOF
wpa=2
wpa_passphrase=$PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
EOF
fi

hostapd -B /tmp/hostapd-captive.conf

log "Starting captive portal web server..."
lighttpd -f /etc/lighttpd/lighttpd-captive.conf &

log "Captive portal is running on $IP"
log "WiFi SSID: $SSID"

wait
