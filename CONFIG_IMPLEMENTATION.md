# RuntipiOS Configuration Variables - Implementation Status

## ✅ Toutes les variables sont maintenant implémentées !

### 📦 `raspios` section
| Variable | Status | Usage |
|----------|--------|-------|
| `url` | ✅ **Implemented** | Workflow downloads this image |
| `arch` | ⚠️ **Informational** | Used for documentation only (detected from image) |

### 🖥️ `system` section
| Variable | Status | Implementation |
|----------|--------|----------------|
| `hostname` | ✅ **Implemented** | Set in `/etc/hostname` and `/etc/hosts` |
| `timezone` | ✅ **Implemented** | Symlink to `/usr/share/zoneinfo/...` |
| `locale` | ✅ **Implemented** | Configured in `/etc/locale.gen` and `/etc/default/locale` |
| `keyboard_layout` | ✅ **Implemented** | Set in `/etc/default/keyboard` |
| `wifi_country` | ✅ **Implemented** | Set in `wpa_supplicant.conf` and `hostapd.conf` |
| `default_user` | ✅ **Implemented** | Created via `userconf.txt` (script `00-setup-userconf.sh`) |
| `default_password` | ✅ **Implemented** | Hashed and set via `userconf.txt` |
| `autologin` | ✅ **Implemented** | Getty service override for tty1 autologin |
| `show_motd` | ✅ **Implemented** | Custom RuntipiOS MOTD created |

### 🏃 `runtipi` section
| Variable | Status | Notes |
|----------|--------|-------|
| `auto_install` | ✅ **Used** | Controls if Runtipi installs automatically with Ethernet |

### 📡 `wifi_connect` section
| Variable | Status | Implementation |
|----------|--------|----------------|
| `version` | ⚠️ **Informational** | For future versioning |
| `ssid` | ✅ **Implemented** | Used in `hostapd.conf` and display messages |

### 🏗️ `build` section
| Variable | Status | Notes |
|----------|--------|-------|
| `image_size` | ⚠️ **Reserved** | For future: extend partition size |
| `compression_format` | ✅ **Used** | Workflow uses `xz` compression |

---

## 📝 New Scripts Created

### `05-setup-system.sh`
Configures all system-level settings from `config.yml`:
- Hostname
- Timezone
- Locale
- Keyboard layout
- WiFi country code
- Autologin (optional)
- Custom MOTD (optional)
- Creates first-boot service for locale generation

### `runtipios-firstboot.service`
Systemd service that runs once on first boot to:
- Generate locales (`locale-gen`)
- Update locale settings
- Self-disable after running

---

## 🔄 Modified Scripts

### `10-setup-hotspot.sh`
- Now reads `wifi_connect.ssid` from `config.yml`
- Uses `wifi_country` for hostapd and wpa_supplicant
- No longer hardcodes "RuntipiOS-Setup"

### `detect-network.sh`
- Reads hotspot SSID from config
- Displays correct SSID in logs and console messages

### `00-setup-userconf.sh`
- Already implemented (unchanged)

---

## 🎯 Workflow Changes

New step added in `.github/workflows/build.yml`:

```yaml
- name: Configure system settings (hostname, locale, timezone, etc.)
  run: |
    sudo chmod +x mnt/opt/runtipi-hotspot/scripts/05-setup-system.sh
    sudo bash mnt/opt/runtipi-hotspot/scripts/05-setup-system.sh mnt mnt/opt/runtipi-hotspot/config.yml
```

This step runs **after** copying files and **before** chroot operations.

---

## 🧪 Testing Your Configuration

Edit `runtipios/config.yml` and rebuild:

```yaml
system:
  hostname: "my-runtipi"          # Will set hostname to "my-runtipi"
  timezone: "America/New_York"     # Set your timezone
  locale: "en_US.UTF-8"            # Set your locale
  keyboard_layout: "us"            # Set keyboard (us, fr, de, etc.)
  wifi_country: "US"               # Set WiFi country code
  autologin: true                  # Enable autologin (or false for login prompt)
  show_motd: true                  # Show custom RuntipiOS welcome message

wifi_connect:
  ssid: "MyCustomHotspot"          # Your custom hotspot name
```

All settings will be applied automatically during image build!

---

## ✨ What Happens Now

### First Boot Sequence:
1. **runtipios-firstboot.service** runs:
   - Generates locales
   - Sets up system language
   - Self-disables

2. **runtipi-wifi.service** runs:
   - Detects network (Ethernet or WiFi needed)
   - Starts hotspot OR installs Runtipi

3. **Configured system** is ready:
   - Hostname is set
   - Timezone is correct
   - Locale is generated
   - Keyboard layout is configured
   - WiFi country is set
   - Autologin (if enabled) works
   - Custom MOTD displays

### User Experience:
- **With autologin=true**: Automatically logged in as configured user
- **With autologin=false**: Login prompt (more secure for servers)
- **Custom hostname**: `ssh user@your-hostname.local`
- **Custom MOTD**: Welcome message when logging in
