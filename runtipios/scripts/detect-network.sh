#!/bin/bash
# Detect Ethernet and decide if we start hotspot or run Runtipi install

LOG_FILE="/var/log/runtipi-detect.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== $(date) - Runtipi Network Detection Started ==="

# Wait a bit for network interfaces to initialize
sleep 5

# Check if Ethernet is connected
ETH_LINK=$(cat /sys/class/net/eth0/carrier 2>/dev/null || echo "0")

if [ "$ETH_LINK" = "1" ]; then
  echo "✓ Ethernet detected, will install Runtipi..."
  
  # Wait for network to be fully ready
  echo "Waiting for internet connection..."
  for i in {1..30}; do
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
      echo "✓ Internet connection available"
      break
    fi
    echo "Waiting for internet... attempt $i/30"
    sleep 2
  done
  
  # Run Runtipi installation
  bash /opt/runtipi-hotspot/scripts/30-install-runtipi.sh
  
else
  echo "✗ No Ethernet detected, starting Wi-Fi hotspot..."
  
  # Ensure wlan0 is available
  if [ ! -e /sys/class/net/wlan0 ]; then
    echo "ERROR: wlan0 interface not found!"
    exit 1
  fi
  
  # Stop any conflicting services
  systemctl stop wpa_supplicant 2>/dev/null || true
  
  # Configure wlan0 IP
  ip addr flush dev wlan0
  ip addr add 192.168.4.1/24 dev wlan0
  ip link set wlan0 up
  
  # Start dnsmasq first
  systemctl start dnsmasq
  sleep 2
  
  # Start nginx for captive portal
  systemctl start nginx
  
  # Finally start hostapd
  systemctl start runtipi-hotspot.service
  
  echo "✓ Hotspot services started"
  echo "   SSID: RuntipiOS-Setup"
  echo "   Password: runtipi123"
  echo "   Portal: http://192.168.4.1"
fi

echo "=== $(date) - Detection script completed ==="
