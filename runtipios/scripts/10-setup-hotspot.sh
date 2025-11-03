#!/bin/bash
apt-get update && apt-get install -y nginx dnsmasq hostapd python3
systemctl disable systemd-resolved
systemctl stop systemd-resolved
cat <<EOF > /etc/dnsmasq.conf
interface=wlan0
dhcp-range=192.168.4.10,192.168.4.50,255.255.255.0,24h
address=/#/192.168.4.1
EOF

cat <<EOF > /etc/hostapd/hostapd.conf
interface=wlan0
ssid=RuntipiOS-Setup
hw_mode=g
channel=7
wmm_enabled=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=runtipi123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

cat <<EOF > /etc/nginx/sites-enabled/default
server {
  listen 80 default_server;
  root /var/www/html;
  index index.html;
  location /save {
    proxy_pass http://127.0.0.1:8000;
  }
}
EOF

cp -r /opt/runtipi-hotspot/www/* /var/www/html/
systemctl enable nginx hostapd dnsmasq
