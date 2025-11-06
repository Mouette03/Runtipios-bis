#!/bin/bash
# Post-build script for RuntipiOS
# This script is called after the root filesystem is built but before the image is created

set -e

TARGET_DIR="${1}"

if [ -z "${TARGET_DIR}" ]; then
    echo "Error: TARGET_DIR not provided"
    exit 1
fi

echo "=== RuntipiOS Post-Build Script ==="
echo "TARGET_DIR: ${TARGET_DIR}"

# Create necessary directories
mkdir -p "${TARGET_DIR}/opt/runtipi"
mkdir -p "${TARGET_DIR}/data"
mkdir -p "${TARGET_DIR}/mnt/boot"
mkdir -p "${TARGET_DIR}/mnt/data"

# Create runtipi user and group
if ! grep -q "^runtipi:" "${TARGET_DIR}/etc/passwd" 2>/dev/null; then
    echo "Creating runtipi user..."
    echo "runtipi:x:1000:1000:Runtipi User:/opt/runtipi:/bin/bash" >> "${TARGET_DIR}/etc/passwd"
    echo "runtipi:x:1000:" >> "${TARGET_DIR}/etc/group"
    echo "runtipi:*:19000:0:99999:7:::" >> "${TARGET_DIR}/etc/shadow"
fi

# Set permissions for runtipi directories (don't fail if chown doesn't work)
chown -R 1000:1000 "${TARGET_DIR}/opt/runtipi" 2>/dev/null || echo "Warning: Could not chown /opt/runtipi"
chown -R 1000:1000 "${TARGET_DIR}/data" 2>/dev/null || echo "Warning: Could not chown /data"

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

# Set default SSH configuration (only if sshd_config exists)
if [ -f "${TARGET_DIR}/etc/ssh/sshd_config" ]; then
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' "${TARGET_DIR}/etc/ssh/sshd_config" || true
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' "${TARGET_DIR}/etc/ssh/sshd_config" || true
fi

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
if [ -d "${TARGET_DIR}/usr/share/zoneinfo" ]; then
    ln -sf /usr/share/zoneinfo/Europe/Paris "${TARGET_DIR}/etc/localtime" 2>/dev/null || true
fi

# Create version file
cat > "${TARGET_DIR}/etc/runtipios-release" << EOF
RUNTIPIOS_VERSION=1.0.0
BUILD_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
BUILD_ID=${BUILD_ID:-unknown}
EOF

# Make sure scripts are executable
chmod +x "${TARGET_DIR}/usr/local/bin/"* 2>/dev/null || true

echo "=== Post-Build Script Completed ==="
