#!/bin/bash
# RuntipiOS Post-Build Script

set -e

TARGET_DIR=$1
BOARD_DIR=$2

log() {
    echo "[Post-Build] $1"
}

log "Starting post-build customization..."

log "Creating system directories..."
mkdir -p "$TARGET_DIR/etc/runtipi"
mkdir -p "$TARGET_DIR/var/log/runtipi"
mkdir -p "$TARGET_DIR/home/runtipi/.config"

chmod 755 "$TARGET_DIR/etc/runtipi"
chmod 755 "$TARGET_DIR/var/log/runtipi"
chown 1000:1000 "$TARGET_DIR/home/runtipi" 2>/dev/null || true

if ! grep -q "^runtipi:" "$TARGET_DIR/etc/passwd"; then
    log "Creating runtipi user..."
    echo "runtipi:x:1000:1000:Runtipi User:/home/runtipi:/bin/bash" >> "$TARGET_DIR/etc/passwd"
    echo "runtipi:x:1000:" >> "$TARGET_DIR/etc/group"
    mkdir -p "$TARGET_DIR/home/runtipi"
    chown 1000:1000 "$TARGET_DIR/home/runtipi" 2>/dev/null || true
fi

if [ -d "$TARGET_DIR/etc/sudoers.d" ]; then
    cat > "$TARGET_DIR/etc/sudoers.d/runtipi" << 'SUDOERS'
runtipi ALL=(ALL) NOPASSWD: ALL
SUDOERS
    chmod 0440 "$TARGET_DIR/etc/sudoers.d/runtipi"
    log "Sudoers configuration added"
fi

log "Setting script permissions..."
chmod +x "$TARGET_DIR/usr/local/bin/runtipi-"* 2>/dev/null || true
chmod +x "$TARGET_DIR/usr/local/bin/"*.sh 2>/dev/null || true

log "Setting up systemd..."
mkdir -p "$TARGET_DIR/etc/systemd/system"
mkdir -p "$TARGET_DIR/var/log/journal"

log "Enabling RuntipiOS services..."
mkdir -p "$TARGET_DIR/etc/systemd/system/multi-user.target.wants"

ln -sf /etc/systemd/system/runtipi-network.service "$TARGET_DIR/etc/systemd/system/multi-user.target.wants/" 2>/dev/null || true
ln -sf /etc/systemd/system/runtipi-install.service "$TARGET_DIR/etc/systemd/system/multi-user.target.wants/" 2>/dev/null || true
ln -sf /etc/systemd/system/runtipi-motd.service "$TARGET_DIR/etc/systemd/system/multi-user.target.wants/" 2>/dev/null || true

log "Setting hostname..."
echo "runtipi" > "$TARGET_DIR/etc/hostname"

log "Creating default MOTD..."
cat > "$TARGET_DIR/etc/motd" << 'MOTD'
╔════════════════════════════════════════════════════════════╗
║                    Welcome to RuntipiOS                    ║
║          Booting up... Runtipi will be ready shortly       ║
╚════════════════════════════════════════════════════════════╝

Waiting for system initialization...
MOTD

log "Setting up shell environment..."
cat > "$TARGET_DIR/etc/profile.d/runtipi.sh" << 'PROFILE'
export RUNTIPI_VERSION="1.0.0"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if [ -x /usr/bin/tput ] && tput setaf 1 >/dev/null 2>&1; then
    export LS_COLORS="di=01;34:ln=01;36:ex=01;32"
    alias ls="ls --color=auto"
fi
PROFILE
chmod 644 "$TARGET_DIR/etc/profile.d/runtipi.sh"

log "Setting up log rotation..."
cat > "$TARGET_DIR/etc/logrotate.d/runtipi" << 'LOGROTATE'
/var/log/runtipi/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 runtipi runtipi
    sharedscripts
}
LOGROTATE

touch "$TARGET_DIR/etc/runtipi/first-boot"

log "Post-build customization completed!"
