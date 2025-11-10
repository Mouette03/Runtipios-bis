#!/bin/bash
# WiFi Configuration API

echo "Content-Type: application/json"
echo ""

read POST_DATA

WIFI_SSID=$(echo "$POST_DATA" | grep -o '"wifi_ssid":"[^"]*"' | cut -d'"' -f4)
WIFI_PASSWORD=$(echo "$POST_DATA" | grep -o '"wifi_password":"[^"]*"' | cut -d'"' -f4)
WIFI_COUNTRY=$(echo "$POST_DATA" | grep -o '"wifi_country":"[^"]*"' | cut -d'"' -f4)

if [ -z "$WIFI_SSID" ] || [ -z "$WIFI_PASSWORD" ]; then
    echo '{"success": false, "message": "Missing credentials"}'
    exit 1
fi

CONFIG_FILE="/boot/firmware/config.yml"

cat > "$CONFIG_FILE" << EOF
hostname: runtipios
timezone: Europe/Paris
wifi_country: $WIFI_COUNTRY
wifi_ssid: "$WIFI_SSID"
wifi_password: "$WIFI_PASSWORD"
EOF

rm -f /etc/runtipios-configured

echo '{"success": true}'

(sleep 5; reboot) &
