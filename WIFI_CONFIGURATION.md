# Configuration WiFi - Méthode Officielle Raspberry Pi

## ✅ Vérification et Corrections Effectuées

### 📋 Ce qui a été vérifié

1. ✅ La variable `WIFI_COUNTRY` provient bien de `config.yml` → `system.wifi_country: "FR"`
2. ✅ Le workflow GitHub Actions extrait correctement cette valeur
3. ✅ La variable est passée au script `configure-image.sh`

### 🔧 Corrections appliquées

#### Avant (Problèmes identifiés)
```bash
# ❌ PROBLÈME 1: Utilisation de wpa_supplicant (OBSOLÈTE dans Bookworm)
echo "country=$WIFI_COUNTRY" | sudo tee "$ROOT_MOUNT/etc/wpa_supplicant/wpa_supplicant.conf"

# ❌ PROBLÈME 2: Seulement REGDOMAIN, pas de configuration NetworkManager
echo "REGDOMAIN=$WIFI_COUNTRY" | sudo tee -a "$ROOT_MOUNT/etc/default/crda"

# ❌ PROBLÈME 3: Service basique sans dépendances correctes
```

#### Après (Méthode officielle complète)
```bash
# ✅ MÉTHODE 1: REGDOMAIN (pour CRDA - Central Regulatory Domain Agent)
echo "REGDOMAIN=$WIFI_COUNTRY" | sudo tee "$ROOT_MOUNT/etc/default/crda"

# ✅ MÉTHODE 2: Configuration NetworkManager (Bookworm utilise NetworkManager)
sudo tee "$ROOT_MOUNT/etc/NetworkManager/conf.d/wifi-country.conf" > /dev/null <<EOF
[device-wifi]
wifi.country=$WIFI_COUNTRY
EOF

# ✅ MÉTHODE 3: Service systemd avec dépendances correctes
sudo tee "$ROOT_MOUNT/etc/systemd/system/set-wifi-region.service" > /dev/null <<EOF
[Unit]
Description=Set WiFi regulatory domain (Country: $WIFI_COUNTRY)
Before=network-pre.target NetworkManager.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/sbin/iw reg set $WIFI_COUNTRY
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF
```

## 🎯 Pourquoi 3 méthodes ?

| Méthode | Rôle | Composant concerné |
|---------|------|-------------------|
| **REGDOMAIN** | Configure CRDA (Central Regulatory Domain Agent) | Kernel / Driver WiFi |
| **NetworkManager** | Configure le gestionnaire réseau moderne | NetworkManager (Bookworm) |
| **Service systemd** | Force l'application au boot | Commande `iw reg set` |

### Pourquoi c'est important ?

1. **CRDA** (`/etc/default/crda`)
   - Lu par le kernel et les drivers WiFi
   - Définit les restrictions réglementaires (canaux autorisés, puissance max)
   - Ancienne méthode, mais encore utilisée par certains drivers

2. **NetworkManager** (`/etc/NetworkManager/conf.d/wifi-country.conf`)
   - **NOUVEAU** dans Bookworm
   - Remplace wpa_supplicant comme gestionnaire WiFi principal
   - Méthode officielle recommandée

3. **Service systemd + iw reg set**
   - S'exécute **avant** NetworkManager
   - Applique directement au kernel via la commande `iw`
   - Garantit que le domaine est défini même si les fichiers config échouent

## 📊 Ordre d'exécution au boot

```
1. sysinit.target
   └─> set-wifi-region.service (iw reg set FR)
       ↓
2. network-pre.target
       ↓
3. NetworkManager.service (lit wifi-country.conf)
       ↓
4. network-online.target
```

## 🔍 Vérifications à faire sur le Raspberry Pi

Une fois l'image bootée, vérifiez que tout fonctionne :

### 1. Vérifier le domaine réglementaire
```bash
# Afficher le domaine réglementaire actuel
iw reg get

# Devrait afficher :
# country FR: DFS-ETSI
#     (2402 - 2482 @ 40), (20, 20), (N/A)
#     (5170 - 5250 @ 80), (20, 20), (N/A), AUTO-BW
#     ...
```

### 2. Vérifier que rfkill n'est PAS actif
```bash
# Vérifier l'état du blocage WiFi
rfkill list

# Devrait afficher :
# 0: phy0: Wireless LAN
#     Soft blocked: no      ← IMPORTANT !
#     Hard blocked: no
```

Si "Soft blocked: yes", c'est que la configuration du pays a échoué !

### 3. Vérifier NetworkManager
```bash
# Vérifier la configuration NetworkManager
cat /etc/NetworkManager/conf.d/wifi-country.conf

# Devrait afficher :
# [device-wifi]
# wifi.country=FR
```

### 4. Vérifier le service systemd
```bash
# Vérifier que le service a bien démarré
systemctl status set-wifi-region.service

# Devrait afficher :
# ● set-wifi-region.service - Set WiFi regulatory domain (Country: FR)
#      Loaded: loaded
#      Active: active (exited) since ...
```

### 5. Vérifier que le WiFi est détecté
```bash
# Lister les interfaces réseau
ip link show

# Devrait montrer wlan0 :
# 3: wlan0: <BROADCAST,MULTICAST,UP> mtu 1500 qdisc ...

# Scanner les réseaux WiFi
sudo nmcli dev wifi list
```

## 🐛 Troubleshooting

### Problème : WiFi bloqué (rfkill)
```bash
# Symptôme
rfkill list
# 0: phy0: Wireless LAN
#     Soft blocked: yes  ← PROBLÈME

# Solution
sudo iw reg set FR
sudo rfkill unblock wifi
```

### Problème : Pas de réseaux WiFi visibles
```bash
# Vérifier que le driver est chargé
lsmod | grep brcm

# Vérifier les messages kernel
dmesg | grep -i wifi
dmesg | grep -i brcm

# Redémarrer NetworkManager
sudo systemctl restart NetworkManager
```

### Problème : Le pays n'est pas persistant après reboot
```bash
# Vérifier que le service est activé
systemctl is-enabled set-wifi-region.service

# Si désactivé, activer :
sudo systemctl enable set-wifi-region.service

# Vérifier les fichiers de config
ls -la /etc/default/crda
ls -la /etc/NetworkManager/conf.d/wifi-country.conf
```

## 📚 Références Officielles

- **Configuration WiFi Bookworm** : https://www.raspberrypi.com/documentation/computers/configuration.html#connect-to-a-wireless-network
- **Localisation (WiFi Country)** : https://www.raspberrypi.com/documentation/computers/configuration.html#localisation-options
- **NetworkManager** : https://networkmanager.dev/docs/
- **iw (wireless tools)** : https://wireless.wiki.kernel.org/en/users/documentation/iw
- **CRDA** : https://wireless.wiki.kernel.org/en/developers/regulatory/crda

## ✨ Résumé

### Configuration actuelle dans config.yml
```yaml
system:
  wifi_country: "FR"  # ← Utilisé par les 3 méthodes
```

### Ce qui est configuré automatiquement
1. ✅ `/etc/default/crda` avec `REGDOMAIN=FR`
2. ✅ `/etc/NetworkManager/conf.d/wifi-country.conf` avec `wifi.country=FR`
3. ✅ Service systemd `set-wifi-region.service` avec `iw reg set FR`

### Pourquoi c'est mieux que l'ancienne version
- ❌ Avant : wpa_supplicant.conf (obsolète dans Bookworm)
- ✅ Maintenant : NetworkManager (méthode officielle Bookworm)
- ✅ Triple configuration pour compatibilité maximale
- ✅ Documentation et commentaires explicites dans le code

---

**Date de mise à jour** : 5 novembre 2025  
**Version Raspberry Pi OS** : Bookworm (Debian 12)  
**Architecture** : ARM64
