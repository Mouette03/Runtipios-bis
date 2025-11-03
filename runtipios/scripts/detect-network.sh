#!/bin/bash
# Detect Ethernet and decide if we start hotspot or run Runtipi install

LOG_FILE="/var/log/runtipi-detect.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== $(date) - Runtipi Network Detection Started ==="

# Read configuration
CONFIG_FILE="/opt/runtipi-hotspot/config.yml"
if [ -f "$CONFIG_FILE" ]; then
    HOTSPOT_SSID=$(grep -A2 'wifi_connect:' "$CONFIG_FILE" | grep 'ssid:' | awk '{print $2}' | tr -d '"' | tr -d "'")
    HOTSPOT_SSID="${HOTSPOT_SSID:-RuntipiOS-Setup}"
else
    HOTSPOT_SSID="RuntipiOS-Setup"
fi

# Wait a bit for network interfaces to initialize
sleep 10

# Check if Ethernet is connected
ETH_LINK=$(cat /sys/class/net/eth0/carrier 2>/dev/null || echo "0")

if [ "$ETH_LINK" = "1" ]; then
  echo "✓ Ethernet detected, will install Runtipi..."
  
  # Make sure wlan0 is not in hotspot mode
  systemctl stop hostapd 2>/dev/null || true
  systemctl stop dnsmasq 2>/dev/null || true
  
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
  
  # Stop all conflicting services
  echo "Stopping conflicting services..."
  systemctl stop wpa_supplicant 2>/dev/null || true
  systemctl stop dhcpcd 2>/dev/null || true
  killall wpa_supplicant 2>/dev/null || true
  killall dhcpcd 2>/dev/null || true
  
  # Wait for processes to fully stop
  sleep 2
  
  # Bring down wlan0 and reconfigure
  echo "Configuring wlan0..."
  ip link set wlan0 down 2>/dev/null || true
  sleep 1
  
  # Remove any existing IP configuration
  ip addr flush dev wlan0 2>/dev/null || true
  
  # Set wlan0 to unmanaged mode
  rfkill unblock wifi 2>/dev/null || true
  
  # Configure static IP
  ip addr add 192.168.4.1/24 dev wlan0
  ip link set wlan0 up
  
  # Wait for interface to be fully up
  sleep 3
  
  # Verify wlan0 is up with correct IP
  if ! ip addr show wlan0 | grep -q "192.168.4.1"; then
    echo "ERROR: Failed to configure wlan0 IP"
    ip addr show wlan0
    exit 1
  fi
  
  echo "✓ wlan0 configured: 192.168.4.1/24"
  
  # Start dnsmasq first
  echo "Starting dnsmasq..."
  systemctl start dnsmasq
  sleep 2
  
  if ! systemctl is-active --quiet dnsmasq; then
    echo "ERROR: dnsmasq failed to start"
    systemctl status dnsmasq
    exit 1
  fi
  echo "✓ dnsmasq started"
  
  # Start nginx for captive portal
  echo "Starting nginx..."
  systemctl start nginx
  sleep 1
  echo "✓ nginx started"
  
  # Start Python WiFi config server
  echo "Starting WiFi config server..."
  nohup python3 /opt/runtipi-hotspot/scripts/save_wifi.py >> /var/log/runtipi-wifi.log 2>&1 &
  sleep 2
  echo "✓ WiFi config server started"
  
  # Finally start hostapd
  echo "Starting hostapd..."
  systemctl start hostapd
  sleep 3
  
  if ! systemctl is-active --quiet hostapd; then
    echo "ERROR: hostapd failed to start"
    systemctl status hostapd
    journalctl -u hostapd -n 50 --no-pager
    exit 1
  fi
  
  echo "✓ hostapd started successfully"
  echo ""
  echo "=========================================="
  echo "✓ Hotspot is ready!"
  echo "   SSID: $HOTSPOT_SSID"
  echo "   Password: runtipi123"
  echo "   Portal: http://192.168.4.1"
  echo "=========================================="
fi

echo "=== $(date) - Detection script completed ==="
