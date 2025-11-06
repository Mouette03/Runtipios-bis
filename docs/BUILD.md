# RuntipiOS Build Guide

This guide provides detailed instructions for building RuntipiOS from source.

## System Requirements

### Hardware
- **CPU**: Modern multi-core processor (recommended: 4+ cores)
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: 20GB free disk space for build artifacts
- **Network**: Stable internet connection for downloading sources

### Software
- **OS**: Ubuntu 22.04 LTS or newer (other Linux distros may work)
- **Tools**: Git, Make, GCC, and Buildroot dependencies

## Build Process

### 1. Install Dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential git wget cpio rsync bc bison flex gettext \
  libssl-dev libncurses5-dev file python3 tar xz-utils unzip \
  device-tree-compiler u-boot-tools
```

### 2. Clone Repository

```bash
git clone https://github.com/Mouette03/Runtipios-bis.git
cd Runtipios-bis
```

### 3. Configure Build

You can customize the build by editing configuration files:

**Basic Configuration** (`config.yml.example`):
```yaml
hostname: runtipios
timezone: Europe/Paris
locale: en_US.UTF-8
wifi_country: FR
```

**Advanced Configuration** (`configs/runtipios_rpi4_64_defconfig`):
- Kernel version
- Included packages
- Filesystem options
- System services

### 4. Build Image

```bash
# Simple build with defaults
./build.sh

# Build with custom options
./build.sh -j 8              # Use 8 parallel jobs
./build.sh -m                # Open menuconfig before building
./build.sh -c                # Clean build
```

### 5. Wait for Completion

First build takes **1-2 hours** depending on your hardware:
- Downloads: ~2GB
- Build artifacts: ~10-15GB
- Final image: ~500MB

Subsequent builds are much faster thanks to caching.

## Build Artifacts

After successful build, find your image in:
```
output/runtipios-runtipios_rpi4_64-YYYYMMDD-HHMMSS.img.gz
```

## Customization

### Adding Packages

1. Edit `configs/runtipios_rpi4_64_defconfig`
2. Add package selection (e.g., `BR2_PACKAGE_HTOP=y`)
3. Rebuild

### Custom Scripts

Add scripts to `board/runtipi/rootfs-overlay/usr/local/bin/`:
```bash
# Your custom script
#!/bin/bash
echo "Custom setup"
```

Make executable:
```bash
chmod +x board/runtipi/rootfs-overlay/usr/local/bin/your-script
```

### System Services

Add systemd services to `board/runtipi/rootfs-overlay/etc/systemd/system/`:
```ini
[Unit]
Description=My Custom Service

[Service]
ExecStart=/usr/local/bin/your-script

[Install]
WantedBy=multi-user.target
```

Enable in `board/runtipi/post-build.sh`:
```bash
systemctl --root="${TARGET_DIR}" enable your-service.service
```

## Troubleshooting

### Build Fails

**Out of memory**:
```bash
# Reduce parallel jobs
./build.sh -j 2
```

**Missing dependencies**:
```bash
# Reinstall all dependencies
sudo apt-get install -y $(grep -o 'BR2_PACKAGE_[A-Z_]*' configs/*.defconfig | cut -d'_' -f3- | tr '_' '-' | tr '[:upper:]' '[:lower:]')
```

**Corrupted cache**:
```bash
# Clean and rebuild
./build.sh -c
```

### Testing Image

Use QEMU for quick testing (x86 build required):
```bash
# TODO: Add QEMU testing instructions
```

## CI/CD

GitHub Actions automatically builds on:
- Push to `main` or `develop`
- Pull requests
- Manual workflow dispatch

Artifacts are available for 30 days after build.

## Advanced Topics

### Cross-Compilation

RuntipiOS uses Buildroot's internal toolchain for ARM64 cross-compilation.

### Kernel Configuration

```bash
cd buildroot
make linux-menuconfig
make linux-savedefconfig
```

### U-Boot Configuration

```bash
cd buildroot
make uboot-menuconfig
```

## Resources

- [Buildroot Manual](https://buildroot.org/downloads/manual/manual.html)
- [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/)
- [Runtipi Documentation](https://runtipi.io/docs)

## Support

Need help? Open an issue on GitHub with:
- Build log (`buildroot/build.log`)
- System info (`uname -a`, `lsb_release -a`)
- Steps to reproduce
