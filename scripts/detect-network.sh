#!/bin/bash
# Detect Ethernet and decide if we start hotspot or run Runtipi install

ETH_LINK=$(cat /sys/class/net/eth0/carrier 2>/dev/null)
if [ "$ETH_LINK" = "1" ]; then
  echo "Ethernet detected, installing Runtipi..."
  bash /opt/runtipi-hotspot/scripts/30-install-runtipi.sh
else
  echo "No Ethernet, starting hotspot..."
  systemctl start runtipi-hotspot.service
fi
