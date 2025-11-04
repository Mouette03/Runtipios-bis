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
echo "$HOSTNAME" | sudo tee "$ROOT_MOUNT/etc/hostname" > /dev/null
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" "$ROOT_MOUNT/etc/hosts"

# 2. Set timezone
echo "Setting timezone to $TIMEZONE"
sudo ln -sf "/usr/share/zoneinfo/$TIMEZONE" "$ROOT_MOUNT/etc/localtime"

# 3. Set locale
echo "Setting locale to $LOCALE"
echo "LANG=$LOCALE" | sudo tee "$ROOT_MOUNT/etc/default/locale" > /dev/null
sudo sed -i "s/# $LOCALE/$LOCALE/" "$ROOT_MOUNT/etc/locale.gen"

# 4. Set keyboard layout
echo "Setting keyboard layout to $KEYBOARD_LAYOUT"
sudo tee "$ROOT_MOUNT/etc/default/keyboard" > /dev/null <<EOF
XKBMODEL="pc105"
XKBLAYOUT="$KEYBOARD_LAYOUT"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

# 5. Set WiFi country
echo "Setting WiFi country to $WIFI_COUNTRY"
echo "country=$WIFI_COUNTRY" | sudo tee -a "$ROOT_MOUNT/etc/wpa_supplicant/wpa_supplicant.conf" > /dev/null

echo "--- (2/4) Setting up user and enabling SSH ---"
# Create userconf.txt for headless setup
echo "Creating userconf.txt for user $DEFAULT_USER"
PASSWORD_HASH=$(echo "$DEFAULT_PASSWORD" | openssl passwd -6 -stdin)
echo "$DEFAULT_USER:$PASSWORD_HASH" | sudo tee "$BOOT_MOUNT/userconf.txt" > /dev/null

# Enable SSH by creating the 'ssh' file
echo "Enabling SSH"
sudo touch "$BOOT_MOUNT/ssh"

# Disable cloud-init messages on boot for a cleaner experience
echo "Disabling cloud-init verbose messages"
sudo mkdir -p "$ROOT_MOUNT/etc/cloud/cloud.cfg.d"
sudo tee "$ROOT_MOUNT/etc/cloud/cloud.cfg.d/99-disable-network-messages.cfg" > /dev/null <<EOF
# Disable verbose cloud-init messages on console
datasource_list: [ None ]
EOF

# Add a Plymouth boot splash theme configuration (if plymouth is available)
# This will hide boot messages behind a graphical splash screen
echo "Configuring quiet boot"
if [ -f "$ROOT_MOUNT/boot/firmware/cmdline.txt" ]; then
  sudo sed -i 's/$/ quiet splash plymouth.ignore-serial-consoles loglevel=3/' "$ROOT_MOUNT/boot/firmware/cmdline.txt"
elif [ -f "$ROOT_MOUNT/boot/cmdline.txt" ]; then
  sudo sed -i 's/$/ quiet splash plymouth.ignore-serial-consoles loglevel=3/' "$ROOT_MOUNT/boot/cmdline.txt"
fi

echo "--- (3/4) Setting up first-boot services ---"
# Create a first-boot script to run locale-gen
echo "Creating first-boot script for locale generation"
sudo tee "$ROOT_MOUNT/usr/local/bin/runtipios-firstboot.sh" > /dev/null <<'EOF'
#!/bin/bash
echo "--- Generating locales on first boot ---"
locale-gen
echo "--- Locales generated ---"
# Disable self
systemctl disable runtipios-firstboot.service
rm -f /etc/systemd/system/runtipios-firstboot.service
rm -f /usr/local/bin/runtipios-firstboot.sh
EOF
sudo chmod +x "$ROOT_MOUNT/usr/local/bin/runtipios-firstboot.sh"

# Create systemd service for first boot locale generation
sudo tee "$ROOT_MOUNT/etc/systemd/system/runtipios-firstboot.service" > /dev/null <<'EOF'
[Unit]
Description=Generate locales on first boot
After=network.target
Before=runtipi-installer.service

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
    sudo tee "$ROOT_MOUNT/usr/local/bin/runtipi-installer.sh" > /dev/null <<EOF
#!/bin/bash
# This script runs on boot to install Runtipi if network is available.

LOG_FILE="/var/log/runtipi-installer.log"
exec > >(tee -a "\$LOG_FILE") 2>&1

clear
echo ""
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║                                                           ║"
echo "  ║        🚀  RuntipiOS - Installation automatique  🚀       ║"
echo "  ║                                                           ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "  [1/4] Vérification de la connexion réseau..."

# Check for Ethernet connection first
if ! ip link | grep -q "eth0.*state UP"; then
    echo "  ⚠️  Aucune connexion Ethernet (eth0) détectée."
    echo ""
    echo "  Veuillez brancher un câble Ethernet et redémarrer."
    systemctl disable runtipi-installer.service
    exit 0
fi

echo "  ✓ Connexion Ethernet détectée"
echo ""
echo "  [2/4] Attente de la connexion Internet..."

# Wait for internet connection (max 5 minutes)
for i in {1..60}; do
  if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "  ✓ Connexion Internet établie"
    echo ""
    echo "  [3/4] Téléchargement et installation de Runtipi..."
    echo "  (Cela peut prendre 5-10 minutes selon votre connexion)"
    echo ""
    
    if curl -fsSL "$RUNTIPI_URL" | bash; then
      echo ""
      echo "  [4/4] Configuration finale..."
      # Create dynamic MOTD script
      cat > /etc/profile.d/runtipi-motd.sh << 'EOMOTD'
#!/bin/bash
IP_ADDRESS=\$(hostname -I | awk '{print \$1}')
cat << EOT

  ____              _   _       _     ___  ____  
 |  _ \\ _   _ _ __ | |_(_)_ __ (_)   / _ \\/ ___| 
 | |_) | | | | '_ \\| __| | '_ \\| |  | | | \\___ \\ 
 |  _ <| |_| | | | | |_| | |_) | |  | |_| |___) |
 |_| \\_\\\\__,_|_| |_|\\__|_| .__/|_|   \\___/|____/ 
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
      
      echo ""
      echo "  ╔═══════════════════════════════════════════════════════════╗"
      echo "  ║                                                           ║"
      echo "  ║        ✅  Installation terminée avec succès !  ✅        ║"
      echo "  ║                                                           ║"
      echo "  ║   Runtipi est maintenant accessible à l'adresse :        ║"
      echo "  ║                                                           ║"
      echo "  ║   👉  http://runtipios.local                             ║"
      echo "  ║                                                           ║"
      echo "  ║   Le système va redémarrer dans 10 secondes...           ║"
      echo "  ║                                                           ║"
      echo "  ╚═══════════════════════════════════════════════════════════╝"
      echo ""
      
      sleep 10
    else
      echo ""
      echo "  ❌ L'installation de Runtipi a échoué."
      echo "  📋 Consultez le fichier de log : /var/log/runtipi-installer.log"
    fi
    
    # Disable this service from running again
    systemctl disable runtipi-installer.service
    rm -f /etc/systemd/system/runtipi-installer.service
    reboot
    exit 0
  fi
  printf "  ⏳ Tentative %d/60...\r" "\$i"
  sleep 5
done

echo ""
echo "  ❌ Impossible d'établir une connexion Internet après 5 minutes."
echo "  Veuillez vérifier votre connexion réseau et redémarrer."
systemctl disable runtipi-installer.service
rm -f /etc/systemd/system/runtipi-installer.service
exit 1
EOF
    sudo chmod +x "$ROOT_MOUNT/usr/local/bin/runtipi-installer.sh"

    # Create systemd service for the installer
    sudo tee "$ROOT_MOUNT/etc/systemd/system/runtipi-installer.service" > /dev/null <<'EOF'
[Unit]
Description=Runtipi Auto Installer
After=network-online.target runtipios-firstboot.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/runtipi-installer.sh
StandardInput=tty
StandardOutput=tty
StandardError=journal
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
