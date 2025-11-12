#!/bin/bash
#==============================================================================
# System Customization Script
# This script runs in the context of the mounted root filesystem
#==============================================================================

set -e

#==============================================================================
# Logging functions
#==============================================================================

log_info() {
    echo -e "\e[34m[INFO]\e[0m $*"
}

log_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $*"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $*"
}

#==============================================================================
# Parse arguments
#==============================================================================

MOUNT_ROOT="$1"
MOUNT_BOOT="$2"

if [ -z "$MOUNT_ROOT" ] || [ -z "$MOUNT_BOOT" ]; then
    echo "Error: Mount points not provided"
    exit 1
fi

log_info "Customizing system at: ${MOUNT_ROOT}"

#==============================================================================
# Setup chroot environment
#==============================================================================

setup_chroot() {
    log_info "Setting up chroot environment..."
    
    # Copy qemu for ARM emulation
    cp /usr/bin/qemu-aarch64-static "${MOUNT_ROOT}/usr/bin/" 2>/dev/null || \
    cp /usr/bin/qemu-arm-static "${MOUNT_ROOT}/usr/bin/" 2>/dev/null || true
    
    # Mount required filesystems
    mount --bind /dev "${MOUNT_ROOT}/dev"
    mount --bind /proc "${MOUNT_ROOT}/proc"
    mount --bind /sys "${MOUNT_ROOT}/sys"
    mount --bind /dev/pts "${MOUNT_ROOT}/dev/pts"
}

cleanup_chroot() {
    log_info "Cleaning up chroot environment..."
    
    umount "${MOUNT_ROOT}/dev/pts" 2>/dev/null || true
    umount "${MOUNT_ROOT}/sys" 2>/dev/null || true
    umount "${MOUNT_ROOT}/proc" 2>/dev/null || true
    umount "${MOUNT_ROOT}/dev" 2>/dev/null || true
    
    rm -f "${MOUNT_ROOT}/usr/bin/qemu-"* 2>/dev/null || true
}

trap cleanup_chroot EXIT

#==============================================================================
# Install packages
#==============================================================================

install_packages() {
    log_info "Installing additional packages..."
    
    # Update package lists
    chroot "${MOUNT_ROOT}" /bin/bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# Install packages
# Note: Docker will be installed by Runtipi installation script
apt-get install -y --no-install-recommends \
    hostapd \
    dnsmasq \
    lighttpd \
    iptables \
    rfkill \
    iw \
    wireless-tools \
    curl \
    wget \
    git \
    nano \
    vim \
    htop \
    net-tools \
    avahi-daemon \
    avahi-utils \
    python3 \
    python3-pip

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF
    
    log_success "Packages installed"
}

#==============================================================================
# Apply overlays
#==============================================================================

apply_overlays() {
    log_info "Applying filesystem overlays..."
    
    # Copy common overlays
    if [ -d "${SCRIPT_DIR}/platforms/common/overlays" ]; then
        cp -a "${SCRIPT_DIR}/platforms/common/overlays/." "${MOUNT_ROOT}/"
    fi
    
    # Copy platform-specific overlays
    if [ -d "${SCRIPT_DIR}/platforms/${PLATFORM}/overlays" ]; then
        cp -a "${SCRIPT_DIR}/platforms/${PLATFORM}/overlays/." "${MOUNT_ROOT}/"
    fi
    
    log_success "Overlays applied"
}

#==============================================================================
# Configure hostname
#==============================================================================

configure_hostname() {
    log_info "Configuring hostname: ${RUNTIPIOS_HOSTNAME}"
    
    echo "${RUNTIPIOS_HOSTNAME}" > "${MOUNT_ROOT}/etc/hostname"
    
    cat > "${MOUNT_ROOT}/etc/hosts" << EOF
127.0.0.1       localhost
127.0.1.1       ${RUNTIPIOS_HOSTNAME}

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF
}

#==============================================================================
# Configure timezone and locale
#==============================================================================

configure_locale() {
    log_info "Configuring timezone and locale..."
    
    # Timezone
    chroot "${MOUNT_ROOT}" ln -sf "/usr/share/zoneinfo/${RUNTIPIOS_TIMEZONE}" /etc/localtime
    
    # Locale
    sed -i "s/^# *${RUNTIPIOS_LOCALE}/${RUNTIPIOS_LOCALE}/" "${MOUNT_ROOT}/etc/locale.gen"
    chroot "${MOUNT_ROOT}" locale-gen
}

#==============================================================================
# Create default user
#==============================================================================

create_default_user() {
    log_info "Creating default user: ${RUNTIPIOS_DEFAULT_USER}..."
    
    chroot "${MOUNT_ROOT}" /bin/bash << EOF
# Create user if it doesn't exist
if ! id -u ${RUNTIPIOS_DEFAULT_USER} &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,video,plugdev,games,users,input,netdev,spi,i2c,gpio ${RUNTIPIOS_DEFAULT_USER}
    echo "${RUNTIPIOS_DEFAULT_USER}:${RUNTIPIOS_DEFAULT_PASSWORD}" | chpasswd
    
    # Allow sudo without password
    echo "${RUNTIPIOS_DEFAULT_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/010_${RUNTIPIOS_DEFAULT_USER}
    chmod 0440 /etc/sudoers.d/010_${RUNTIPIOS_DEFAULT_USER}
fi
EOF

    # Copy .bashrc if exists in overlays
    if [ -f "${SCRIPT_DIR}/platforms/common/overlays/home/runtipi/.bashrc" ]; then
        cp "${SCRIPT_DIR}/platforms/common/overlays/home/runtipi/.bashrc" \
           "${MOUNT_ROOT}/home/${RUNTIPIOS_DEFAULT_USER}/.bashrc"
        chroot "${MOUNT_ROOT}" chown ${RUNTIPIOS_DEFAULT_USER}:${RUNTIPIOS_DEFAULT_USER} \
           /home/${RUNTIPIOS_DEFAULT_USER}/.bashrc
    fi

    log_success "User created"
}

#==============================================================================
# Configure autologin
#==============================================================================

configure_autologin() {
    log_info "Configuring autologin for ${RUNTIPIOS_DEFAULT_USER}..."
    
    # Create autologin directory
    mkdir -p "${MOUNT_ROOT}/etc/systemd/system/getty@tty1.service.d"
    
    # Create autologin override
    cat > "${MOUNT_ROOT}/etc/systemd/system/getty@tty1.service.d/autologin.conf" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${RUNTIPIOS_DEFAULT_USER} --noclear %I \$TERM
EOF

    log_success "Autologin configured"
}

#==============================================================================
# Enable services
#==============================================================================

enable_services() {
    log_info "Enabling systemd services..."
    
    chroot "${MOUNT_ROOT}" /bin/bash << 'EOF'
# Enable RuntipiOS services
systemctl enable runtipios-setup.service
systemctl enable runtipios-hotspot.service
systemctl enable runtipi-install.service

# Enable Avahi for .local resolution
systemctl enable avahi-daemon

# Enable SSH
systemctl enable ssh

# Disable Raspberry Pi OS default services that expect 'pi' user
systemctl disable userconfig.service 2>/dev/null || true
systemctl mask userconfig.service 2>/dev/null || true

# Disable resize2fs_once (we handle partition resize differently)
systemctl disable resize2fs_once.service 2>/dev/null || true
systemctl mask resize2fs_once.service 2>/dev/null || true

# Disable lighttpd by default (started only by hotspot script)
systemctl disable lighttpd 2>/dev/null || true

# Disable dnsmasq by default (started only by hotspot script)
systemctl disable dnsmasq 2>/dev/null || true

# Disable hostapd by default (started only by hotspot script)
systemctl disable hostapd 2>/dev/null || true

# Disable unnecessary services
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
EOF
    
    log_success "Services configured"
}

#==============================================================================
# Configure boot
#==============================================================================

configure_boot() {
    log_info "Configuring boot settings..."
    
    # Copy boot config if exists
    if [ -f "${SCRIPT_DIR}/platforms/${PLATFORM}/config/config.txt" ]; then
        cp "${SCRIPT_DIR}/platforms/${PLATFORM}/config/config.txt" "${MOUNT_BOOT}/"
    fi
    
    # Enable SSH
    touch "${MOUNT_BOOT}/ssh"
    
    # Remove userconf trigger file (prevents userconfig.service from running)
    rm -f "${MOUNT_BOOT}/userconf" "${MOUNT_BOOT}/userconf.txt"
    
    # Create welcome message
    cat > "${MOUNT_ROOT}/etc/motd" << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                      Welcome to RuntipiOS!                    ║
║                                                               ║
║  Lightweight Linux distribution for running Runtipi           ║
║                                                               ║
║  Default login: runtipi / runtipi                             ║
║                                                               ║
║  Runtipi will install automatically when internet is          ║
║  detected (Ethernet or WiFi).                                 ║
║                                                               ║
║  TROUBLESHOOTING:                                             ║
║    Run: debug  (shows complete diagnostic)                    ║
║                                                               ║
║  Access web interface after installation:                     ║
║    http://runtipios.local                                     ║
║    http://YOUR_IP_ADDRESS                                     ║
║                                                               ║
║  WiFi Setup (if no Ethernet):                                 ║
║    1. Hotspot should appear: RuntipiOS-Setup                  ║
║    2. Password: runtipios2024                                 ║
║    3. Configure WiFi via web portal                           ║
║    4. Runtipi installs automatically after connection         ║
║                                                               ║
║  Check status:                                                ║
║    systemctl status runtipios-hotspot                         ║
║    systemctl status runtipi-install                           ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    
    log_success "Boot configured"
}

#==============================================================================
# Create data directory
#==============================================================================

create_data_directory() {
    log_info "Creating required directories..."
    mkdir -p "${MOUNT_ROOT}/data"
    chmod 755 "${MOUNT_ROOT}/data"
    
    # Create hostapd and dnsmasq config directories
    mkdir -p "${MOUNT_ROOT}/etc/hostapd"
    mkdir -p "${MOUNT_ROOT}/etc/dnsmasq.d"
}

#==============================================================================
# Run all customizations
#==============================================================================

setup_chroot
install_packages
apply_overlays
configure_hostname
configure_locale
create_default_user
configure_autologin
enable_services
configure_boot
create_data_directory

log_success "System customization complete!"
