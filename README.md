# RuntipiOS

**Lightweight Linux distribution for running Runtipi on embedded devices**

Built on Debian/Raspberry Pi OS Lite for maximum stability and compatibility.

## 🎯 Features

- 🔥 **Debian-based** - Rock-solid foundation with official Raspberry Pi support
- 🚀 **Pre-configured** - Boot and go, Runtipi ready in minutes
- 📡 **WiFi Hotspot** - Automatic captive portal for easy initial setup (only if no Ethernet)
- 🐳 **Docker Ready** - Installed automatically by Runtipi
- 🔧 **Multi-platform** - Raspberry Pi 5, Pi 4, and more to come
- ⚡ **Lightweight** - Minimal footprint, maximum performance

## 🏗️ Supported Platforms

| Platform | Status | Architecture | Notes |
|----------|--------|--------------|-------|
| **Raspberry Pi 5** | ✅ Ready | ARM64 | Primary target |
| Raspberry Pi 4 | 🔄 Planned | ARM64 | Coming soon |
| Raspberry Pi Zero 2 W | 🔄 Planned | ARM64 | Coming soon |
| x86_64 | 🔄 Planned | x86_64 | For VMs/NUCs |

## 🚀 Quick Start

### Prerequisites

**Linux (Ubuntu/Debian recommended) or WSL2:**
```bash
sudo apt-get update
sudo apt-get install -y git wget curl unzip xz-utils qemu-user-static \
  debootstrap debian-archive-keyring systemd-container
```

### Build an Image

1. **Clone this repository:**
```bash
git clone https://github.com/Mouette03/Runtipios-bis.git
cd Runtipios-bis
```

2. **Build for your platform:**
```bash
# For Raspberry Pi 5
sudo ./build.sh rpi5

# For other platforms (when available)
# sudo ./build.sh rpi4
# sudo ./build.sh x86_64
```

3. **Flash to SD card:**
```bash
# The image will be in output/
sudo dd if=output/runtipios-rpi5-*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### First Boot

1. Insert SD card and power on
2. **If Ethernet connected**: 
   - System uses wired network
   - Runtipi installs automatically (wait 5-10 minutes)
   - Access at `http://runtipios.local` when ready
3. **If no Ethernet**: WiFi hotspot starts: **RuntipiOS-Setup**
   - Connect to hotspot (password: `runtipios2024`)
   - Open browser → automatic redirect to setup portal
   - Configure WiFi credentials
   - Device reboots and connects to your network
   - Runtipi installs automatically after connection
4. Login via SSH: `ssh runtipi@runtipios.local` (password: `runtipi`)
5. Check installation: `systemctl status runtipi-install`
6. Access Runtipi at `http://runtipios.local` when installation completes

## 📁 Project Structure

```
RuntipiOS/
├── platforms/              # Platform-specific configurations
│   ├── common/            # Shared across all platforms
│   │   ├── overlays/      # Filesystem overlays
│   │   └── scripts/       # Common scripts
│   └── rpi5/              # Raspberry Pi 5 specific
│       ├── config/        # Boot config, cmdline.txt
│       └── firmware/      # Platform firmware (if needed)
├── scripts/               # Build and customization scripts
│   ├── build.sh          # Main build script
│   ├── customize.sh      # System customization
│   ├── install-runtipi.sh
│   └── setup-hotspot.sh
├── config/               # Global configuration
│   └── runtipios.conf   # Common settings for all platforms
└── .github/workflows/   # CI/CD
    └── build.yml        # Automated builds
```

## ⚙️ Configuration

Edit `config/runtipios.conf` to customize default settings:

```bash
# System
RUNTIPIOS_HOSTNAME="runtipios"
RUNTIPIOS_TIMEZONE="Europe/Paris"
RUNTIPIOS_LOCALE="en_US.UTF-8"

# Network
RUNTIPIOS_HOTSPOT_SSID="RuntipiOS-Setup"
RUNTIPIOS_HOTSPOT_PASSWORD="runtipios2024"

# Runtipi
RUNTIPIOS_RUNTIPI_VERSION="v3.7.0"
```

## 🛠️ Development

### Adding a New Platform

1. Create platform directory: `platforms/your-platform/`
2. Add platform config: `platforms/your-platform/config/platform.conf`
3. Add any platform-specific files
4. Update `scripts/build.sh` to support new platform
5. Test and submit PR!

### Customizing the Image

- **Add packages:** Edit `scripts/customize.sh` → `PACKAGES` array
- **Add services:** Place systemd units in `platforms/common/overlays/etc/systemd/system/`
- **Modify boot config:** Edit `platforms/*/config/config.txt`

## 📝 Technical Details

### Base System
- **OS:** Debian 12 (Bookworm) / Raspberry Pi OS Lite
- **Init:** systemd
- **Kernel:** Official Raspberry Pi kernel
- **Packages:** Minimal install + Docker + networking tools

### Build Process
1. Download official Raspberry Pi OS Lite image
2. Mount and customize filesystem
3. Install packages and configure services
4. Apply platform-specific overlays
5. Configure first-boot setup
6. Shrink and compress image

### Services Included
- `runtipios-setup` - First boot configuration
- `runtipios-hotspot` - WiFi hotspot for setup
- `runtipi-install` - Runtipi installer (one-shot)
- `docker` - Container runtime
- `lighttpd` - Captive portal web server

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

GPL-3.0 - See [LICENSE](LICENSE) file

## 🙏 Credits

- Based on [Raspberry Pi OS](https://www.raspberrypi.com/software/)
- Inspired by [Home Assistant OS](https://github.com/home-assistant/operating-system)
- Powered by [Runtipi](https://runtipi.io)

## 📞 Support

- 🐛 Issues: [GitHub Issues](https://github.com/Mouette03/Runtipios-bis/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/Mouette03/Runtipios-bis/discussions)

---

**Made with ❤️ for the self-hosting community**
