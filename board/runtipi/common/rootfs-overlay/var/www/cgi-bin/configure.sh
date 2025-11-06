#!/bin/bash
# API endpoint for WiFi configuration
# This script is called by lighttpd CGI

echo "Content-Type: application/json"
echo ""

# Read POST data
read POST_DATA

# Parse JSON (simple parsing for demo, use jq for production)
WIFI_SSID=$(echo "$POST_DATA" | grep -o '"wifi_ssid":"[^"]*"' | cut -d'"' -f4)
WIFI_PASSWORD=$(echo "$POST_DATA" | grep -o '"wifi_password":"[^"]*"' | cut -d'"' -f4)
WIFI_COUNTRY=$(echo "$POST_DATA" | grep -o '"wifi_country":"[^"]*"' | cut -d'"' -f4)

# Update config.yml on boot partition
CONFIG_FILE="/boot/config.yml"

if [ -f "$CONFIG_FILE" ]; then
    # Update existing config
    sed -i "s/^wifi_ssid:.*/wifi_ssid: \"$WIFI_SSID\"/" "$CONFIG_FILE"
    sed -i "s/^wifi_password:.*/wifi_password: \"$WIFI_PASSWORD\"/" "$CONFIG_FILE"
    sed -i "s/^wifi_country:.*/wifi_country: \"$WIFI_COUNTRY\"/" "$CONFIG_FILE"
else
    # Create new config
    cat > "$CONFIG_FILE" << EOF
# RuntipiOS Configuration
hostname: runtipios
timezone: Europe/Paris
locale: en_US.UTF-8
keyboard: us
wifi_country: $WIFI_COUNTRY
wifi_ssid: "$WIFI_SSID"
wifi_password: "$WIFI_PASSWORD"
username: runtipi
password: runtipi
EOF
fi

# Trigger reconfiguration on next boot
rm -f /etc/runtipios-configured

# Return success
echo '{"success": true, "message": "Configuration saved. Rebooting..."}'

# Schedule reboot
(sleep 5; reboot) &
