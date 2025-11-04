#!/bin/bash
set -e

# This script is called from the GitHub Actions workflow.
# It applies all system configurations to the mounted image.

# --- Environment variables passed from the workflow ---
# ROOT_MOUNT="/mnt/root"
# BOOT_MOUNT="/mnt/boot"
# HOSTNAME
# TIMEZONE
# LOCALE
# KEYBOARD_LAYOUT
# WIFI_COUNTRY
# DEFAULT_USER
# DEFAULT_PASSWORD
# RUNTIPI_AUTO_INSTALL
# RUNTIPI_URL

echo "--- (1/4) Applying basic system configuration ---"
# 1. Set hostname
echo "Setting hostname to $HOSTNAME"
sudo bash -c "echo '$HOSTNAME' > $ROOT_MOUNT/etc/hostname"
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" "$ROOT_MOUNT/etc/hosts"

# 2. Set timezone
echo "Setting timezone to $TIMEZONE"
sudo ln -sf "/usr/share/zoneinfo/$TIMEZONE" "$ROOT_MOUNT/etc/localtime"

# 3. Set locale
echo "Setting locale to $LOCALE"
sudo bash -c "echo 'LANG=$LOCALE' > $ROOT_MOUNT/etc/default/locale"
sudo sed -i "s/# $LOCALE/$LOCALE/" "$ROOT_MOUNT/etc/locale.gen"

# 4. Set keyboard layout
echo "Setting keyboard layout to $KEYBOARD_LAYOUT"
sudo bash -c "cat > $ROOT_MOUNT/etc/default/keyboard" <<EOF
XKBMODEL="pc105"
XKBLAYOUT="$KEYBOARD_LAYOUT"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

# 5. Set WiFi country
echo "Setting WiFi country to $WIFI_COUNTRY"
sudo bash -c "echo 'country=$WIFI_COUNTRY' >> $ROOT_MOUNT/etc/wpa_supplicant/wpa_supplicant.conf"

echo "--- (2/4) Setting up user and enabling SSH ---"
# Create userconf.txt for headless setup
echo "Creating userconf.txt for user $DEFAULT_USER"
PASSWORD_HASH=$(echo "$DEFAULT_PASSWORD" | openssl passwd -6 -stdin)
sudo bash -c "echo '$DEFAULT_USER:$PASSWORD_HASH' > $BOOT_MOUNT/userconf.txt"

# Enable SSH by creating the 'ssh' file
echo "Enabling SSH"
sudo touch "$BOOT_MOUNT/ssh"

echo "--- (3/4) Setting up first-boot services ---"
# Create a first-boot script to run locale-gen
echo "Creating first-boot script for locale generation"
sudo bash -c 'cat > '"$ROOT_MOUNT"'/usr/local/bin/runtipios-firstboot.sh' << 'EOF'
#!/bin/bash
echo "--- Generating locales on first boot ---"
locale-gen
echo "--- Locales generated ---"
# Disable self
rm -f /etc/systemd/system/runtipios-firstboot.service
rm -f /usr/local/bin/runtipios-firstboot.sh
EOF
sudo chmod +x "$ROOT_MOUNT/usr/local/bin/runtipios-firstboot.sh"

# Create systemd service for first boot locale generation
sudo bash -c 'cat > '"$ROOT_MOUNT"'/etc/systemd/system/runtipios-firstboot.service' << 'EOF'
[Unit]
Description=Generate locales on first boot
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/runtipios-firstboot.sh

[Install]
WantedBy=multi-user.target
EOF
sudo ln -sf /etc/systemd/system/runtipios-firstboot.service "$ROOT_MOUNT/etc/systemd/system/multi-user.target.wants/runtipios-firstboot.service"

if [ "$RUNTIPI_AUTO_INSTALL" = "True" ]; then
    echo "--- (4/4) Setting up Runtipi auto-installation ---"

    # Create the installer script that will run on the Pi
    sudo bash -c 'cat > '"$ROOT_MOUNT"'/usr/local/bin/runtipi-installer.sh' << EOF
#!/bin/bash
# This script runs on boot to install Runtipi if network is available.

LOG_FILE="/var/log/runtipi-installer.log"
exec > >(tee -a "\$LOG_FILE") 2>&1

echo "--- Runtipi Installer Service Started at \$(date) ---"

# Check for Ethernet connection first
if ! ip link | grep -q "eth0.*state UP"; then
    echo "No active Ethernet (eth0) connection found. Exiting."
    systemctl disable runtipi-installer.service
    exit 0
fi

echo "Active Ethernet connection found. Waiting for internet connectivity..."

# Wait for internet connection (max 5 minutes)
for i in {1..60}; do
  if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "Internet connection detected."
    
    echo "Starting Runtipi installation from $RUNTIPI_URL..."
    if curl -L "$RUNTIPI_URL" | bash; then
      echo "Runtipi installation script finished successfully."
      # Create dynamic MOTD script
      cat > /etc/profile.d/runtipi-motd.sh << 'EOMOTD'
#!/bin/bash
IP_ADDRESS=\$(hostname -I | awk '{print \$1}')
cat << EOT

  ____              _   _       _     ___  ____  
 |  _ \ _   _ _ __ | |_(_)_ __ (_)   / _ \/ ___| 
 | |_) | | | | '_ \| __| | '_ \| |  | | | \___ \ 
 |  _ <| |_| | | | | |_| | |_) | |  | |_| |___) |
 |_| \_\\__,_|_| |_|\__|_| .__/|_|   \___/|____/ 
                         |_|                      

Welcome to RuntipiOS - Simplified Runtipi Deployment

Quick Start:
  - Web Interface: http://runtipios.local or http://\$IP_ADDRESS
  - Documentation: https://runtipi.io

EOT
EOMOTD
      chmod +x /etc/profile.d/runtipi-motd.sh
      # Clear the static MOTD file
      > /etc/motd
    else
      echo "Runtipi installation script failed."
    fi
    
    # Disable this service from running again
    echo "Disabling runtipi-installer service."
    systemctl disable runtipi-installer.service
    rm -f /etc/systemd/system/runtipi-installer.service
    exit 0
  fi
  echo "Waiting for connection... (attempt \$i)"
  sleep 5
done

echo "Could not establish internet connection after 5 minutes. Runtipi not installed."
echo "Disabling runtipi-installer service."
systemctl disable runtipi-installer.service
rm -f /etc/systemd/system/runtipi-installer.service
exit 1
EOF
    sudo chmod +x "$ROOT_MOUNT/usr/local/bin/runtipi-installer.sh"

    # Create systemd service for the installer
    sudo bash -c 'cat > '"$ROOT_MOUNT"'/etc/systemd/system/runtipi-installer.service' << 'EOF'
[Unit]
Description=Runtipi Auto Installer
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/runtipi-installer.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    # Enable the service
    sudo ln -sf /etc/systemd/system/runtipi-installer.service "$ROOT_MOUNT/etc/systemd/system/multi-user.target.wants/runtipi-installer.service"
else
    echo "--- (4/4) Skipping Runtipi auto-installation ---"
fi

echo "--- Configuration script finished successfully! ---"
