# RuntipiOS - Buildroot-Based Linux for Runtipi

<div align="center">
  <img src="https://raw.githubusercontent.com/runtipi/runtipi/develop/screenshots/logo.png" width="200" alt="RuntipiOS"/>
  
  [![Build](https://github.com/Mouette03/Runtipios-bis/actions/workflows/build.yml/badge.svg)](https://github.com/Mouette03/Runtipios-bis/actions/workflows/build.yml)
  [![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
  
  **Ultra-lightweight Linux distribution for running Runtipi home server**
</div>

---

## 🌟 Features

- **🪶 Lightweight**: ~500MB base system, optimized for Raspberry Pi
- **🚀 Fast Boot**: 15-20 seconds to ready state
- **📡 WiFi Captive Portal**: Easy setup without keyboard/monitor
- **🐳 Docker Built-in**: Ready for Runtipi containers
- **🔧 Auto-configuration**: Configure everything via `config.yml`
- **🌍 Multi-language**: Support for EN, FR, DE, ES, IT
- **🔒 Secure**: AppArmor, systemd hardening, minimal attack surface

## 📋 Requirements

### For Building
- Linux system (Ubuntu 22.04+ recommended)
- 4GB+ RAM
- 20GB+ free disk space
- Build dependencies (installed automatically by build script)

### For Running
- Raspberry Pi 4 (1GB+ RAM) or Raspberry Pi 5
- 8GB+ microSD card
- Power supply (5V/3A recommended)
- Optional: WiFi network for initial setup

## 🚀 Quick Start

### 1. Build the Image

```bash
# Clone repository
git clone https://github.com/Mouette03/Runtipios-bis.git
cd Runtipios-bis

# Make build script executable
chmod +x build.sh

# Build (takes 1-2 hours on first build)
./build.sh
```

### 2. Flash to SD Card

```bash
# Find your SD card device (e.g., /dev/sdb)
lsblk

# Flash the image
sudo dd if=output/runtipios-*.img.gz bs=4M status=progress | gunzip | sudo dd of=/dev/sdX bs=4M status=progress

# Or use Balena Etcher / Raspberry Pi Imager
```

### 3. Configure (Optional)

Mount the boot partition and edit `config.yml`:

```yaml
# RuntipiOS Configuration
hostname: runtipios
timezone: Europe/Paris
locale: en_US.UTF-8
keyboard: us

# WiFi credentials
wifi_country: FR
wifi_ssid: "MyWiFiNetwork"
wifi_password: "MyPassword"

# User account
username: runtipi
password: changeme
```

### 4. Boot and Access

**Option A: Pre-configured WiFi**
- Insert SD card and power on
- Wait 30-60 seconds
- Access via: `http://runtipios.local`

**Option B: WiFi Setup Portal**
- Insert SD card and power on
- Connect to WiFi: `RuntipiOS-Setup` (password: `runtipios2024`)
- Open browser to: `http://192.168.42.1`
- Enter your WiFi credentials
- System will reboot and connect

## 📖 Documentation

### Build Options

```bash
./build.sh [OPTIONS]

Options:
  -b, --board BOARD       Board config (default: runtipios_rpi4_64)
  -v, --version VERSION   Buildroot version (default: 2024.08.x)
  -j, --jobs JOBS         Parallel jobs (default: CPU cores)
  -c, --clean             Clean before building
  -m, --menuconfig        Configure before building
  -h, --help              Show help
```

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| SSH | runtipi | changeme |
| WiFi Portal | - | runtipios2024 |
| Runtipi (after install) | admin | Auto-generated |

**⚠️ Change default passwords immediately after first boot!**

### Project Structure

```
Runtipios-bis/
├── Config.in                   # BR2_EXTERNAL config
├── external.mk                 # External packages
├── external.desc               # Project description
├── build.sh                    # Main build script
├── config.yml.example          # Configuration template
├── configs/
│   └── runtipios_rpi4_64_defconfig  # Buildroot defconfig
├── board/runtipi/
│   ├── config.txt              # Raspberry Pi boot config
│   ├── genimage.cfg            # Disk image layout
│   ├── post-build.sh           # Post-build customization
│   ├── post-image.sh           # Image generation
│   └── rootfs-overlay/         # System overlay
│       ├── etc/
│       │   ├── systemd/system/ # Systemd services
│       │   └── lighttpd/       # Web server config
│       ├── usr/local/bin/      # Custom scripts
│       └── var/www/            # Captive portal web UI
├── package/runtipi/            # Runtipi package
│   ├── Config.in
│   ├── runtipi.mk
│   └── runtipi-install.sh
└── .github/workflows/
    └── build.yml               # CI/CD workflow
```

## 🔧 Advanced Configuration

### Custom Buildroot Configuration

```bash
# Configure interactively
./build.sh -m

# Save changes to defconfig
cd build/buildroot
make savedefconfig BR2_DEFCONFIG=../../configs/runtipios_rpi4_64_defconfig
```

### Add Custom Packages

1. Create package directory:
   ```bash
   mkdir -p package/mypackage
   ```

2. Create `package/mypackage/Config.in`:
   ```makefile
   config BR2_PACKAGE_MYPACKAGE
       bool "mypackage"
       help
         My custom package
   ```

3. Create `package/mypackage/mypackage.mk`:
   ```makefile
   MYPACKAGE_VERSION = 1.0
   MYPACKAGE_SITE = https://example.com/mypackage.tar.gz
   $(eval $(generic-package))
   ```

4. Add to `Config.in`:
   ```makefile
   source "$BR2_EXTERNAL_RUNTIPIOS_PATH/package/mypackage/Config.in"
   ```

### Customize System Services

Edit files in `board/runtipi/rootfs-overlay/`:
- Services: `etc/systemd/system/`
- Scripts: `usr/local/bin/`
- Web UI: `var/www/html/`

## 🐛 Troubleshooting

### Build Issues

**Problem**: Missing dependencies
```bash
# Install all build dependencies
sudo apt-get update
sudo apt-get install build-essential git wget cpio rsync bc bison flex \
  libssl-dev libncurses5-dev file python3 tar xz-utils unzip
```

**Problem**: Out of disk space
```bash
# Clean build artifacts
./build.sh -c

# Or manually
rm -rf build/
```

### Boot Issues

**Problem**: WiFi not working
- Check WiFi credentials in `config.yml`
- Verify WiFi country code matches your location
- Connect to `RuntipiOS-Setup` hotspot for manual config

**Problem**: Cannot access web interface
```bash
# Find IP address
# Connect via Ethernet, then SSH:
ssh runtipi@runtipios.local
ip addr show

# Check services
sudo systemctl status runtipi-install
sudo systemctl status docker
```

**Problem**: Runtipi not installed
```bash
# Check installation logs
sudo journalctl -u runtipi-install

# Manually trigger installation
sudo systemctl restart runtipi-install
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📜 License

GPL-3.0 - See [LICENSE](LICENSE) file

## 🙏 Acknowledgments

- [Runtipi](https://runtipi.io) - The home server platform
- [Buildroot](https://buildroot.org) - Embedded Linux build system
- [Home Assistant OS](https://github.com/home-assistant/operating-system) - Inspiration for architecture
- Raspberry Pi Foundation - Hardware and firmware

## 📞 Support

- 🐛 Issues: [GitHub Issues](https://github.com/Mouette03/Runtipios-bis/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/Mouette03/Runtipios-bis/discussions)
- 📖 Runtipi Docs: [runtipi.io/docs](https://runtipi.io/docs)

---

<div align="center">
  Made with ❤️ for the self-hosting community
</div>
