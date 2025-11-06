# Changelog

All notable changes to RuntipiOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Complete Buildroot-based build system (Home Assistant OS approach)
- WiFi captive portal for easy setup without keyboard/monitor
- Automated Runtipi installation via systemd service
- Configuration via `config.yml` on boot partition
- Support for Raspberry Pi 4 and 5 (64-bit)
- Docker and Docker Compose built-in
- Web-based WiFi configuration portal
- Systemd-based initialization
- GitHub Actions CI/CD workflow
- Comprehensive documentation

### Changed
- Migrated from custom scripts to Buildroot BR2_EXTERNAL tree
- Improved WiFi country configuration reliability
- Optimized image size (~500MB)

### Fixed
- WiFi rfkill blocking issues
- User creation reliability
- First-boot configuration flow

## [1.0.0] - 2025-11-06

### Added
- Initial release of RuntipiOS
- Buildroot-based minimal Linux distribution
- Raspberry Pi 4/5 support
- Automated Runtipi installation
- WiFi hotspot mode for initial setup
- Configuration management via YAML
