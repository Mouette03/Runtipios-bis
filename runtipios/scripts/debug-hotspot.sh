#!/bin/bash
# Debug script for RuntipiOS hotspot issues

echo "=========================================="
echo "RuntipiOS Hotspot Debug Information"
echo "=========================================="
echo ""

echo "=== Network Interfaces ==="
ip link show
echo ""

echo "=== IP Configuration ==="
ip addr show
echo ""

echo "=== wlan0 Status ==="
if [ -e /sys/class/net/wlan0 ]; then
    echo "wlan0 exists"
    cat /sys/class/net/wlan0/operstate
    iw dev wlan0 info 2>/dev/null || echo "iw command failed"
else
    echo "wlan0 NOT FOUND"
fi
echo ""

echo "=== Running Processes ==="
ps aux | grep -E 'hostapd|dnsmasq|wpa_supplicant|dhcpcd' | grep -v grep
echo ""

echo "=== Service Status ==="
systemctl status runtipi-wifi.service --no-pager || true
echo "---"
systemctl status hostapd --no-pager || true
echo "---"
systemctl status dnsmasq --no-pager || true
echo "---"
systemctl status nginx --no-pager || true
echo ""

echo "=== hostapd Configuration ==="
if [ -f /etc/hostapd/hostapd.conf ]; then
    cat /etc/hostapd/hostapd.conf
else
    echo "Config file not found"
fi
echo ""

echo "=== dnsmasq Configuration ==="
if [ -f /etc/dnsmasq.conf ]; then
    cat /etc/dnsmasq.conf
else
    echo "Config file not found"
fi
echo ""

echo "=== Recent Logs ==="
echo "--- runtipi-detect.log ---"
tail -n 30 /var/log/runtipi-detect.log 2>/dev/null || echo "Log file not found"
echo ""
echo "--- runtipi-wifi.log ---"
tail -n 30 /var/log/runtipi-wifi.log 2>/dev/null || echo "Log file not found"
echo ""

echo "=== systemd Journal (hostapd) ==="
journalctl -u hostapd -n 30 --no-pager || true
echo ""

echo "=== systemd Journal (runtipi-wifi) ==="
journalctl -u runtipi-wifi.service -n 30 --no-pager || true
echo ""

echo "=========================================="
echo "Debug information collection complete"
echo "=========================================="
