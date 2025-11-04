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

# DISABLE cloud-init completely to avoid console spam
echo "Disabling cloud-init for cleaner boot experience"
sudo touch "$BOOT_MOUNT/cloud-init.disabled"

# Also disable cloud-init services in systemd
sudo mkdir -p "$ROOT_MOUNT/etc/systemd/system/cloud-init.target.wants"
for service in cloud-config.service cloud-final.service cloud-init-local.service cloud-init.service; do
    sudo ln -sf /dev/null "$ROOT_MOUNT/etc/systemd/system/$service"
done

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
    sudo tee "$ROOT_MOUNT/usr/local/bin/runtipi-installer.sh" > /dev/null <<'EOF'
#!/bin/bash
# This script runs on boot to install Runtipi if network is available.

# Ensure we output to the main console
exec > /dev/tty1 2>&1 < /dev/tty1

LOG_FILE="/var/log/runtipi-installer.log"

# Function to log and display
log_display() {
    echo "$1" | tee -a "$LOG_FILE"
}

clear
log_display ""
log_display "  ╔═══════════════════════════════════════════════════════════╗"
log_display "  ║                                                           ║"
log_display "  ║        🚀  RuntipiOS - Installation automatique  🚀       ║"
log_display "  ║                                                           ║"
log_display "  ╚═══════════════════════════════════════════════════════════╝"
log_display ""
log_display "  [1/4] Vérification de la connexion réseau..."
sleep 2

# Check for network connection (Ethernet OR WiFi)
NETWORK_CONNECTED=false

if ip link show eth0 2>/dev/null | grep -q "state UP"; then
    log_display "  ✓ Connexion Ethernet (eth0) détectée"
    NETWORK_CONNECTED=true
elif ip link show wlan0 2>/dev/null | grep -q "state UP"; then
    log_display "  ✓ Connexion WiFi (wlan0) détectée"
    NETWORK_CONNECTED=true
fi

if [ "$NETWORK_CONNECTED" = false ]; then
    log_display "  ⚠️  Aucune connexion réseau détectée."
    log_display ""
    log_display "  Veuillez connecter un câble Ethernet ou configurer le WiFi,"
    log_display "  puis redémarrer le système."
    log_display ""
    log_display "  💡 Pour configurer le WiFi, éditez le fichier :"
    log_display "     /etc/wpa_supplicant/wpa_supplicant.conf"
    systemctl disable runtipi-installer.service
    sleep 15
    exit 0
fi

log_display ""
log_display "  [2/4] Attente de la connexion Internet..."

# Wait for internet connection (max 5 minutes)
for i in {1..60}; do
  if curl -fs --head http://connectivity-check.ubuntu.com/ >/dev/null 2>&1; then
    log_display "  ✓ Connexion Internet établie"
    log_display ""
    log_display "  [3/4] Téléchargement et installation de Runtipi..."
    log_display "  (Cela peut prendre 5-10 minutes selon votre connexion)"
    log_display ""
    
EOF

    # Now add the curl command with the actual URL
    echo "    if curl -fsSL \"$RUNTIPI_URL\" | bash 2>&1 | tee -a \"\$LOG_FILE\"; then" | sudo tee -a "$ROOT_MOUNT/usr/local/bin/runtipi-installer.sh" > /dev/null

    # Continue with the rest of the script
    sudo tee -a "$ROOT_MOUNT/usr/local/bin/runtipi-installer.sh" > /dev/null <<'EOF'
      log_display ""
      log_display "  [4/4] Configuration finale..."
      # Create dynamic MOTD script
      cat > /etc/profile.d/runtipi-motd.sh << 'EOMOTD'
#!/bin/bash
IP_ADDRESS=$(hostname -I | awk '{print $1}')
cat << EOT

  ____              _   _       _     ___  ____  
 |  _ \ _   _ _ __ | |_(_)_ __ (_)   / _ \/ ___| 
 | |_) | | | | '_ \| __| | '_ \| |  | | | \___ \ 
 |  _ <| |_| | | | | |_| | |_) | |  | |_| |___) |
 |_| \_\\__,_|_| |_|\__|_| .__/|_|   \___/|____/ 
                         |_|                      

Bienvenue sur RuntipiOS - Déploiement simplifié de Runtipi

Accès rapide :
  - Interface Web : http://runtipios.local ou http://$IP_ADDRESS
  - Documentation : https://runtipi.io

EOT
EOMOTD
      chmod +x /etc/profile.d/runtipi-motd.sh
      # Clear the static MOTD file
      > /etc/motd
      
      # Create marker file to indicate successful installation
      mkdir -p /var/lib
      echo "Runtipi installed on $(date)" > /var/lib/runtipi-installed
      
      clear
      log_display ""
      log_display "  ╔═══════════════════════════════════════════════════════════╗"
      log_display "  ║                                                           ║"
      log_display "  ║        ✅  Installation terminée avec succès !  ✅       ║"
      log_display "  ║                                                           ║"
      log_display "  ║   Runtipi est maintenant accessible à l'adresse :         ║"
      log_display "  ║                                                           ║"
      log_display "  ║             👉 http://runtipios.local 👈​                 ║"
      log_display "  ║                                                           ║"
      log_display "  ║   Le système va redémarrer dans 15 secondes...            ║"
      log_display "  ║                                                           ║"
      log_display "  ╚═══════════════════════════════════════════════════════════╝"
      log_display ""
      
      sleep 15
    else
      log_display ""
      log_display "  ❌ L'installation de Runtipi a échoué."
      log_display "  📋 Consultez le fichier de log : /var/log/runtipi-installer.log"
      log_display ""
      sleep 30
    fi
    
    # Disable this service from running again
    systemctl disable runtipi-installer.service
    rm -f /etc/systemd/system/runtipi-installer.service
    reboot
    exit 0
  fi
  printf "  ⏳ Tentative %d/60...\r" "$i"
  sleep 5
done

log_display ""
log_display "  ❌ Impossible d'établir une connexion Internet après 5 minutes."
log_display "  Veuillez vérifier votre connexion réseau et redémarrer."
systemctl disable runtipi-installer.service
rm -f /etc/systemd/system/runtipi-installer.service
sleep 30
exit 1
EOF
    sudo chmod +x "$ROOT_MOUNT/usr/local/bin/runtipi-installer.sh"

    # Create the systemd service
    echo "Creating runtipi-installer systemd service"
    sudo tee "$ROOT_MOUNT/etc/systemd/system/runtipi-installer.service" > /dev/null <<'EOF'
[Unit]
Description=Runtipi Auto-Installer
After=network-online.target systemd-user-sessions.service plymouth-quit-wait.service getty@tty1.service
Wants=network-online.target
Before=getty@tty1.service

[Service]
Type=idle
ExecStartPre=/bin/sleep 3
ExecStart=/usr/local/bin/runtipi-installer.sh
StandardInput=tty
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
RemainAfterExit=no
KillMode=process
Restart=no

[Install]
WantedBy=multi-user.target
EOF

    # Enable the service
    echo "Enabling runtipi-installer service"
    sudo ln -sf /etc/systemd/system/runtipi-installer.service "$ROOT_MOUNT/etc/systemd/system/multi-user.target.wants/runtipi-installer.service"

    # Disable getty on tty1 temporarily to avoid conflicts during installation
    echo "Configuring getty@tty1 to not interfere with installation"
    sudo mkdir -p "$ROOT_MOUNT/etc/systemd/system/getty@tty1.service.d"
    sudo tee "$ROOT_MOUNT/etc/systemd/system/getty@tty1.service.d/override.conf" > /dev/null <<'EOF'
[Unit]
ConditionPathExists=!/var/lib/runtipi-installed
EOF
else
    echo "--- (4/4) Skipping Runtipi auto-installation ---"
fi

echo "--- Configuration script finished successfully! ---"
