#!/bin/bash
# System configuration script for RuntipiOS
# Reads config.yml and applies system settings

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <root_mount_point> <config_yml_path>"
    echo "Example: $0 /mnt /mnt/opt/runtipi-hotspot/config.yml"
    exit 1
fi

ROOT_MOUNT="$1"
CONFIG_FILE="$2"

echo "=== RuntipiOS System Configuration ==="
echo "Root mount: $ROOT_MOUNT"
echo "Config file: $CONFIG_FILE"
echo ""

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

if [ ! -d "$ROOT_MOUNT" ]; then
    echo "ERROR: Root mount point not found: $ROOT_MOUNT"
    exit 1
fi

# Extract configuration values
HOSTNAME=$(grep 'hostname:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")
TIMEZONE=$(grep 'timezone:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")
LOCALE=$(grep 'locale:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")
KEYBOARD=$(grep 'keyboard_layout:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")
WIFI_COUNTRY=$(grep 'wifi_country:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")
AUTOLOGIN=$(grep 'autologin:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")
SHOW_MOTD=$(grep 'show_motd:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")
DEFAULT_USER=$(grep 'default_user:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")

echo "Configuration values extracted:"
echo "  Hostname: $HOSTNAME"
echo "  Timezone: $TIMEZONE"
echo "  Locale: $LOCALE"
echo "  Keyboard: $KEYBOARD"
echo "  WiFi Country: $WIFI_COUNTRY"
echo "  Autologin: $AUTOLOGIN"
echo "  Show MOTD: $SHOW_MOTD"
echo "  Default User: $DEFAULT_USER"
echo ""

# 1. Configure hostname
if [ -n "$HOSTNAME" ]; then
    echo "✓ Setting hostname to: $HOSTNAME"
    echo "$HOSTNAME" > "$ROOT_MOUNT/etc/hostname"
    
    # Update /etc/hosts
    cat > "$ROOT_MOUNT/etc/hosts" <<EOF
127.0.0.1       localhost
127.0.1.1       $HOSTNAME
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF
fi

# 2. Configure timezone
if [ -n "$TIMEZONE" ]; then
    echo "✓ Setting timezone to: $TIMEZONE"
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" "$ROOT_MOUNT/etc/localtime"
    echo "$TIMEZONE" > "$ROOT_MOUNT/etc/timezone"
fi

# 3. Configure locale
if [ -n "$LOCALE" ]; then
    echo "✓ Setting locale to: $LOCALE"
    
    # Uncomment the locale in /etc/locale.gen
    if [ -f "$ROOT_MOUNT/etc/locale.gen" ]; then
        sed -i "s/^# *\($LOCALE.*\)/\1/" "$ROOT_MOUNT/etc/locale.gen"
        # Also ensure en_US.UTF-8 is available (fallback)
        sed -i 's/^# *\(en_US.UTF-8.*\)/\1/' "$ROOT_MOUNT/etc/locale.gen"
    fi
    
    # Set default locale
    cat > "$ROOT_MOUNT/etc/default/locale" <<EOF
LANG=$LOCALE
LC_ALL=$LOCALE
LANGUAGE=${LOCALE%%.*}
EOF
fi

# 4. Configure keyboard layout
if [ -n "$KEYBOARD" ]; then
    echo "✓ Setting keyboard layout to: $KEYBOARD"
    cat > "$ROOT_MOUNT/etc/default/keyboard" <<EOF
XKBMODEL="pc105"
XKBLAYOUT="$KEYBOARD"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
fi

# 5. Configure WiFi country
if [ -n "$WIFI_COUNTRY" ]; then
    echo "✓ Setting WiFi country to: $WIFI_COUNTRY"
    
    # Update wpa_supplicant.conf
    if [ -f "$ROOT_MOUNT/etc/wpa_supplicant/wpa_supplicant.conf" ]; then
        if grep -q "^country=" "$ROOT_MOUNT/etc/wpa_supplicant/wpa_supplicant.conf"; then
            sed -i "s/^country=.*/country=$WIFI_COUNTRY/" "$ROOT_MOUNT/etc/wpa_supplicant/wpa_supplicant.conf"
        else
            sed -i "1a country=$WIFI_COUNTRY" "$ROOT_MOUNT/etc/wpa_supplicant/wpa_supplicant.conf"
        fi
    fi
    
    # Set in /boot/firmware/config.txt or /boot/config.txt for older systems
    for CONFIG_TXT in "$ROOT_MOUNT/boot/firmware/config.txt" "$ROOT_MOUNT/boot/config.txt"; do
        if [ -f "$CONFIG_TXT" ]; then
            if ! grep -q "^country=" "$CONFIG_TXT"; then
                echo "country=$WIFI_COUNTRY" >> "$CONFIG_TXT"
            fi
        fi
    done
fi

# 6. Configure autologin
if [ "$AUTOLOGIN" = "true" ] && [ -n "$DEFAULT_USER" ]; then
    echo "✓ Enabling autologin for user: $DEFAULT_USER"
    
    # Create autologin service override directory
    mkdir -p "$ROOT_MOUNT/etc/systemd/system/getty@tty1.service.d"
    
    # Create autologin override
    cat > "$ROOT_MOUNT/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $DEFAULT_USER --noclear %I \$TERM
EOF
else
    echo "✓ Autologin disabled (login prompt will be shown)"
    # Remove autologin if it exists
    rm -rf "$ROOT_MOUNT/etc/systemd/system/getty@tty1.service.d/autologin.conf" 2>/dev/null || true
fi

# 7. Configure MOTD (Message of the Day)
if [ "$SHOW_MOTD" = "true" ]; then
    echo "✓ Creating custom MOTD"
    cat > "$ROOT_MOUNT/etc/motd" <<'EOF'

  ____              _   _       _     ___  ____  
 |  _ \ _   _ _ __ | |_(_)_ __ (_)   / _ \/ ___| 
 | |_) | | | | '_ \| __| | '_ \| |  | | | \___ \ 
 |  _ <| |_| | | | | |_| | |_) | |  | |_| |___) |
 |_| \_\\__,_|_| |_|\__|_| .__/|_|   \___/|____/ 
                         |_|                      

Welcome to RuntipiOS - Simplified Runtipi Deployment

Quick Start:
  - Web Interface: http://runtipi.local or http://runtipios.local
  - Documentation: https://runtipi.io
  - Configuration: /opt/runtipi-hotspot/config.yml

Useful Commands:
  - sudo systemctl status runtipi-wifi.service
  - sudo journalctl -u runtipi-wifi.service -f
  - sudo bash /opt/runtipi-hotspot/scripts/debug-hotspot.sh

EOF
else
    echo "✓ MOTD disabled (using default)"
    # Don't remove default MOTD, just don't add custom one
fi

# 8. Create a first-boot configuration script that will run on the Raspberry Pi
echo "✓ Creating first-boot locale generation script"
cat > "$ROOT_MOUNT/usr/local/bin/runtipios-firstboot.sh" <<'EOFSCRIPT'
#!/bin/bash
# RuntipiOS first boot configuration

# This script runs once on first boot to finalize configuration

LOG_FILE="/var/log/runtipios-firstboot.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== $(date) - RuntipiOS First Boot Configuration ==="

# Generate locales
if [ -f /etc/locale.gen ]; then
    echo "Generating locales..."
    locale-gen
    echo "✓ Locales generated"
fi

# Update locale
if [ -f /etc/default/locale ]; then
    source /etc/default/locale
    update-locale LANG=$LANG LC_ALL=$LC_ALL 2>/dev/null || true
fi

# Disable this script from running again
systemctl disable runtipios-firstboot.service 2>/dev/null || true
rm -f /etc/systemd/system/runtipios-firstboot.service

echo "=== $(date) - First boot configuration completed ==="
EOFSCRIPT

chmod +x "$ROOT_MOUNT/usr/local/bin/runtipios-firstboot.sh"

# Create systemd service for first boot
cat > "$ROOT_MOUNT/etc/systemd/system/runtipios-firstboot.service" <<EOF
[Unit]
Description=RuntipiOS First Boot Configuration
After=systemd-user-sessions.service
Before=runtipi-wifi.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/runtipios-firstboot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo ""
echo "=========================================="
echo "✓ System configuration completed successfully"
echo "=========================================="
