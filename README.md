# RuntipiOS - Buildroot-Based OS for Runtipi

Ultra-lightweight Linux distribution for running Runtipi.

## Quick Start
1. Extract archive
2. Add Buildroot: `git submodule add https://github.com/buildroot/buildroot.git buildroot`
3. Build: `cd buildroot && make BR2_EXTERNAL=.. rpi4-64_defconfig && make -j$(nproc)`
4. Flash: `dd if=buildroot/output/images/runtipi-rpi4-64.img of=/dev/sdX bs=4M`

## Features
- Ultra-lightweight (~300-500MB)
- Automatic Runtipi installation
- WiFi captive portal
- Fast boot (15-20 seconds)
- Multi-language support

## Support
https://runtipi.io
