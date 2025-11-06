# RuntipiOS - Buildroot-Based OS for Runtipi

RuntipiOS is a lightweight Linux distribution for running Runtipi on various hardware.

## Features
✅ Ultra-lightweight (~300-500MB)
✅ Automatic Runtipi installation
✅ WiFi captive portal
✅ Zero SSH requirement
✅ Multi-architecture support
✅ Fast boot (15-20 seconds)

## Quick Start
1. Extract archive
2. Add Buildroot: `git submodule add https://github.com/buildroot/buildroot.git`
3. Build: `cd buildroot && make BR2_EXTERNAL=.. rpi4-64_defconfig && make -j$(nproc)`
4. Flash: `dd if=buildroot/output/images/runtipi-rpi4-64.img of=/dev/sdX bs=4M`

## Access
- Ethernet: Plug in and wait 2-3 minutes
- WiFi: Connect to "RuntipiOS-Setup" and configure
- Browse to: http://runtipi.local

## Support
- Runtipi: https://runtipi.io
- Buildroot: https://buildroot.org
