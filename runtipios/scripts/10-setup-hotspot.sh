#!/bin/bash
set -e

echo "=== Installing Hotspot Dependencies ==="

# Update package lists
apt-get update

# Install required packages
echo "Installing nginx, dnsmasq, hostapd, python3..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  nginx \
  dnsmasq \
  hostapd \
  python3 \
  python3-pip \
  iproute2 \
  iptables

# Stop and disable systemd-resolved (conflicts with dnsmasq)
systemctl disable systemd-resolved 2>/dev/null || true
systemctl stop systemd-resolved 2>/dev/null || true

# Remove existing symlink if present
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Configure dnsmasq
echo "Configuring dnsmasq..."
cat <<EOF > /etc/dnsmasq.conf
# Runtipi Hotspot Configuration
interface=wlan0
bind-interfaces
dhcp-range=192.168.4.10,192.168.4.50,255.255.255.0,24h
address=/#/192.168.4.1
no-hosts
log-queries
log-dhcp
EOF

# Configure hostapd
echo "Configuring hostapd..."
cat <<EOF > /etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
ssid=RuntipiOS-Setup
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=runtipi123
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# Set hostapd to use our config
sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd 2>/dev/null || true

# Configure nginx for captive portal
echo "Configuring nginx..."
cat <<EOF > /etc/nginx/sites-available/default
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  
  root /var/www/html;
  index index.html;
  server_name _;
  
  location / {
    try_files \$uri \$uri/ =404;
  }
  
  location /save {
    proxy_pass http://127.0.0.1:8000;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
EOF

# Copy web interface
echo "Installing web interface..."
mkdir -p /var/www/html
cp -r /opt/runtipi-hotspot/www/* /var/www/html/ 2>/dev/null || true
chown -R www-data:www-data /var/www/html

# Don't enable services yet - they will be started by detect-network.sh
# We just make them available
systemctl daemon-reload

echo "✓ Hotspot dependencies installed successfully"
