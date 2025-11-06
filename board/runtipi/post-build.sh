#!/bin/bash
# Post-build script for RuntipiOS
# This script is called after the root filesystem is built but before the image is created
# Similar to Home Assistant OS approach

set -e

TARGET_DIR=$1

echo "=== RuntipiOS Post-Build Script ==="

# Create necessary directories
mkdir -p "${TARGET_DIR}/opt/runtipi"
mkdir -p "${TARGET_DIR}/data"
mkdir -p "${TARGET_DIR}/mnt/boot"
mkdir -p "${TARGET_DIR}/mnt/data"

# Create runtipi user and group
if ! grep -q "^runtipi:" "${TARGET_DIR}/etc/passwd"; then
    echo "runtipi:x:1000:1000:Runtipi User:/opt/runtipi:/bin/bash" >> "${TARGET_DIR}/etc/passwd"
    echo "runtipi:x:1000:" >> "${TARGET_DIR}/etc/group"
    echo "runtipi:*:19000:0:99999:7:::" >> "${TARGET_DIR}/etc/shadow"
fi

# Set permissions for runtipi directories
chown -R 1000:1000 "${TARGET_DIR}/opt/runtipi" 2>/dev/null || true
chown -R 1000:1000 "${TARGET_DIR}/data" 2>/dev/null || true

# Enable systemd services
systemctl --root="${TARGET_DIR}" enable systemd-networkd.service || true
systemctl --root="${TARGET_DIR}" enable systemd-resolved.service || true
systemctl --root="${TARGET_DIR}" enable systemd-timesyncd.service || true
systemctl --root="${TARGET_DIR}" enable sshd.service || true
systemctl --root="${TARGET_DIR}" enable docker.service || true
systemctl --root="${TARGET_DIR}" enable runtipios-setup.service || true
systemctl --root="${TARGET_DIR}" enable runtipios-hotspot.service || true

# Configure network
mkdir -p "${TARGET_DIR}/etc/systemd/network"
cat > "${TARGET_DIR}/etc/systemd/network/20-wired.network" << 'EOF'
[Match]
Name=eth* en*

[Network]
DHCP=yes
MulticastDNS=yes

[DHCP]
UseDomains=yes
RouteMetric=10
EOF

cat > "${TARGET_DIR}/etc/systemd/network/25-wireless.network" << 'EOF'
[Match]
Name=wlan*

[Network]
DHCP=yes
MulticastDNS=yes

[DHCP]
UseDomains=yes
RouteMetric=20
EOF

# Configure resolved
mkdir -p "${TARGET_DIR}/etc/systemd/resolved.conf.d"
cat > "${TARGET_DIR}/etc/systemd/resolved.conf.d/runtipios.conf" << 'EOF'
[Resolve]
MulticastDNS=yes
LLMNR=yes
EOF

# Set default SSH configuration
if [ -f "${TARGET_DIR}/etc/ssh/sshd_config" ]; then
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' "${TARGET_DIR}/etc/ssh/sshd_config"
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' "${TARGET_DIR}/etc/ssh/sshd_config"
fi

# Configure Docker
mkdir -p "${TARGET_DIR}/etc/docker"
cat > "${TARGET_DIR}/etc/docker/daemon.json" << 'EOF'
{
  "log-driver": "journald",
  "storage-driver": "overlay2",
  "data-root": "/data/docker"
}
EOF

# Set hostname
echo "runtipios" > "${TARGET_DIR}/etc/hostname"

# Configure hosts
cat > "${TARGET_DIR}/etc/hosts" << 'EOF'
127.0.0.1   localhost runtipios runtipios.local
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# Set timezone (will be overridden by config.yml)
ln -sf /usr/share/zoneinfo/Europe/Paris "${TARGET_DIR}/etc/localtime" || true

# Create version file
cat > "${TARGET_DIR}/etc/runtipios-release" << EOF
RUNTIPIOS_VERSION=1.0.0
BUILD_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
BUILD_ID=${BUILD_ID:-unknown}
EOF

echo "=== Post-Build Script Completed ==="
