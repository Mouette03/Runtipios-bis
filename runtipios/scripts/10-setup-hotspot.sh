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
  iptables \
  dhcpcd5

# Stop and disable conflicting services
echo "Disabling conflicting services..."
systemctl disable systemd-resolved 2>/dev/null || true
systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable NetworkManager 2>/dev/null || true
systemctl stop NetworkManager 2>/dev/null || true
systemctl disable wpa_supplicant 2>/dev/null || true

# Disable hostapd and dnsmasq autostart (will be managed by detect-network.sh)
systemctl disable hostapd 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true

# Remove existing symlink if present
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Configure dnsmasq
echo "Configuring dnsmasq..."
cat <<EOF > /etc/dnsmasq.conf
# Runtipi Hotspot Configuration
interface=wlan0
bind-interfaces
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=192.168.4.10,192.168.4.50,255.255.255.0,24h
address=/#/192.168.4.1
no-hosts
log-queries
log-dhcp
EOF

# Configure hostapd
echo "Configuring hostapd..."
cat <<'EOF' > /etc/hostapd/hostapd.conf
# Runtipi Hotspot Configuration
interface=wlan0
driver=nl80211
ssid=RuntipiOS-Setup
hw_mode=g
channel=7
ieee80211n=1
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=runtipi123
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
EOF

# Set hostapd to use our config
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd
echo 'DAEMON_OPTS=""' >> /etc/default/hostapd

# Prevent hostapd from starting automatically
systemctl unmask hostapd 2>/dev/null || true

# Configure dhcpcd to ignore wlan0 in hotspot mode
echo "Configuring dhcpcd..."
cat <<EOF >> /etc/dhcpcd.conf

# RuntipiOS: Static IP for wlan0 in hotspot mode (commented by default)
# Uncommented by detect-network.sh when hotspot is active
#interface wlan0
#static ip_address=192.168.4.1/24
#nohook wpa_supplicant
EOF

# Configure nginx for captive portal
echo "Configuring nginx..."
cat <<'EOF' > /etc/nginx/sites-available/default
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  
  root /var/www/html;
  index index.html;
  server_name _;
  
  location / {
    try_files $uri $uri/ =404;
  }
  
  location /save {
    proxy_pass http://127.0.0.1:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
EOF

# Copy web interface
echo "Installing web interface..."
mkdir -p /var/www/html
cp -r /opt/runtipi-hotspot/www/* /var/www/html/ 2>/dev/null || true
chown -R www-data:www-data /var/www/html

# Create wpa_supplicant config if not exists
touch /etc/wpa_supplicant/wpa_supplicant.conf
cat <<EOF > /etc/wpa_supplicant/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=FR

EOF

# Reload systemd
systemctl daemon-reload

echo "✓ Hotspot dependencies installed successfully"
