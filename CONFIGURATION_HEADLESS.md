# Configuration Headless - Méthodes Officielles Raspberry Pi

## 📋 Vue d'ensemble

Ce document explique les méthodes officielles utilisées pour la configuration headless (sans écran/clavier) de RuntipiOS, basées sur la documentation officielle Raspberry Pi.

## 🔧 Méthodes Officielles Implémentées

### 1. Création d'utilisateur : `userconf.txt`

**Documentation officielle** : https://www.raspberrypi.com/documentation/computers/configuration.html#configure-a-user-manually

#### Comment ça fonctionne :

1. **Fichier** : `/boot/firmware/userconf.txt` (racine de la partition boot)
2. **Format** : Une seule ligne avec `username:encrypted_password`
3. **Contraintes du nom d'utilisateur** :
   - Uniquement lettres minuscules, chiffres et tirets
   - Doit commencer par une lettre
   - Maximum 31 caractères
4. **Mot de passe** : Crypté avec `openssl passwd -6` (SHA-512)

#### Le service `userconfig.service` :
- Service système officiel de Raspberry Pi OS
- Lit `/boot/firmware/userconf.txt` au premier démarrage
- Crée l'utilisateur avec les groupes appropriés (sudo, etc.)
- Supprime `userconf.txt` pour la sécurité
- S'autodétruit après exécution

#### Exemple de génération :
```bash
# Générer le hash du mot de passe
echo "monmotdepasse" | openssl passwd -6 -stdin

# Créer userconf.txt
echo "monuser:$6$xyz..." > /boot/firmware/userconf.txt
```

#### Pourquoi cette méthode est plus fiable :
- ✅ Méthode officielle Raspberry Pi, testée et maintenue
- ✅ Gère tous les cas particuliers et appartenances aux groupes
- ✅ S'exécute très tôt dans le processus de démarrage
- ✅ Pas de scripts custom à maintenir

### 2. Activation SSH : fichier `ssh`

**Documentation officielle** : https://www.raspberrypi.com/documentation/computers/configuration.html#boot-folder-contents

#### Comment ça fonctionne :

1. **Fichier** : `/boot/firmware/ssh` (peut aussi être `ssh.txt`)
2. **Contenu** : Vide (le contenu n'a pas d'importance)
3. **Action** : Le firmware détecte ce fichier et active SSH au premier démarrage

```bash
touch /boot/firmware/ssh
```

### 3. Configuration WiFi (Bookworm et ultérieur)

**⚠️ CHANGEMENT MAJEUR** : Depuis Raspberry Pi OS Bookworm, `wpa_supplicant.conf` ne fonctionne plus !

**Documentation officielle** : 
- https://www.raspberrypi.com/documentation/computers/configuration.html#connect-to-a-wireless-network
- https://www.raspberrypi.com/documentation/computers/configuration.html#localisation-options

#### Configuration du pays WiFi (OBLIGATOIRE)

Le pays WiFi **DOIT** être configuré sinon le WiFi reste bloqué par rfkill !

**Méthode officielle via raspi-config** :
```bash
sudo raspi-config nonint do_wifi_country "FR"
```

**Ce que fait raspi-config** :
1. Configure `/etc/default/crda` avec `REGDOMAIN=FR`
2. Configure la base de données réglementaire du kernel
3. Configure NetworkManager (fichier `/etc/NetworkManager/conf.d/wifi-country.conf`)

**Configuration manuelle (3 méthodes complémentaires)** :

```bash
# Méthode 1: REGDOMAIN (fichier CRDA)
echo "REGDOMAIN=FR" > /etc/default/crda

# Méthode 2: NetworkManager (Bookworm utilise NetworkManager)
cat > /etc/NetworkManager/conf.d/wifi-country.conf << 'EOF'
[device-wifi]
wifi.country=FR
EOF

# Méthode 3: Service systemd pour appliquer tôt (avec iw reg set)
cat > /etc/systemd/system/set-wifi-region.service << 'EOF'
[Unit]
Description=Set WiFi regulatory domain
Before=network-pre.target NetworkManager.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/sbin/iw reg set FR
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF
systemctl enable set-wifi-region.service
```

**Important** : Les 3 méthodes sont recommandées pour une compatibilité maximale :
- ✅ **REGDOMAIN** : Lu par CRDA (Central Regulatory Domain Agent)
- ✅ **NetworkManager config** : Utilisé par NetworkManager dans Bookworm
- ✅ **Service systemd** : Force l'application au boot via `iw reg set`

#### Connexion à un réseau WiFi

**Option 1 : NetworkManager CLI (recommandée pour Bookworm)**
```bash
# Lister les réseaux disponibles
sudo nmcli dev wifi list

# Se connecter à un réseau
sudo nmcli --ask dev wifi connect "MonSSID"

# Se connecter avec mot de passe en ligne de commande
sudo nmcli dev wifi connect "MonSSID" password "MonMotDePasse"

# Réseau caché
sudo nmcli --ask dev wifi connect "MonSSID" hidden yes
```

**Option 2 : Via raspi-config**
```bash
# Configuration interactive
sudo raspi-config

# Configuration non-interactive
sudo raspi-config nonint do_wifi_ssid_passphrase "MonSSID" "MonMotDePasse"
# Pour réseau caché, ajouter : 1
sudo raspi-config nonint do_wifi_ssid_passphrase "MonSSID" "MonMotDePasse" 1
```

**Option 3 : Configuration dans l'image (pour setup headless initial)**

⚠️ **Note** : Depuis Bookworm, il n'y a plus de méthode officielle "fichier" pour le WiFi headless initial.
Les méthodes recommandées sont :
1. Utiliser Raspberry Pi Imager avec "Advanced Settings" pour pré-configurer le WiFi
2. Connecter en Ethernet pour la première configuration
3. Utiliser un hotspot WiFi temporaire (comme dans notre configuration)

### 4. Configuration système via `raspi-config nonint`

**Documentation officielle** : https://www.raspberrypi.com/documentation/computers/configuration.html#non-interactive-raspi-config

#### Exemples de commandes :

```bash
# Hostname
sudo raspi-config nonint do_hostname "monhostname"

# Timezone
sudo raspi-config nonint do_change_timezone "Europe/Paris"

# Locale
sudo raspi-config nonint do_change_locale "fr_FR.UTF-8"

# Clavier
sudo raspi-config nonint do_configure_keyboard "fr"

# Pays WiFi
sudo raspi-config nonint do_wifi_country "FR"

# Boot/Auto login
# B1: console, login requis
# B2: console, auto-login
# B3: desktop, login requis
# B4: desktop, auto-login
sudo raspi-config nonint do_boot_behaviour B2
```

## 🔍 Autres Subtilités Découvertes

### 1. Ordre de démarrage des services

Les services systemd s'exécutent dans cet ordre :
1. `sysinit.target` (très tôt)
   - `userconfig.service` ← Création utilisateur
   - `set-wifi-region.service` ← Configuration WiFi
2. `network-pre.target`
3. `network-online.target`
4. `multi-user.target`
   - Services applicatifs

### 2. Problème rfkill WiFi

**Symptôme** : WiFi bloqué par rfkill (soft block)

**Cause** : Domaine réglementaire WiFi non configuré

**Solution** : Définir le pays WiFi AVANT que le driver charge
```bash
# Dans /etc/default/crda
REGDOMAIN=FR

# Service systemd pour appliquer tôt
[Unit]
Before=network-pre.target

[Service]
ExecStart=/usr/sbin/iw reg set FR
```

### 3. Console vs Getty

**Problème** : Afficher des messages d'installation sans que getty interfère

**Solution** : Condition dans getty@tty1.service
```ini
[Unit]
ConditionPathExists=!/var/lib/runtipi-installing
```

### 4. Autologin

**Documentation** : https://www.raspberrypi.com/documentation/computers/configuration.html#boot-auto-login

**Méthode override getty** :
```ini
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin USERNAME --noclear %I $TERM
```

### 5. MOTD (Message of the Day)

**Fichiers** :
- `/etc/motd` - Contenu statique (notre choix)
- `/etc/update-motd.d/` - Scripts dynamiques

Pour MOTD statique simple :
```bash
cat > /etc/motd << 'EOF'
Bienvenue sur RuntipiOS !
EOF
```

### 6. Désactiver cloud-init

**Pourquoi** : Messages parasites au démarrage

**Méthodes** :
```bash
# Méthode 1: Fichier de désactivation
touch /boot/firmware/cloud-init.disabled

# Méthode 2: Masquer les services
sudo systemctl mask cloud-init.service
sudo systemctl mask cloud-config.service
sudo systemctl mask cloud-final.service
sudo systemctl mask cloud-init-local.service
```

## 📚 Références Officielles

- **Configuration générale** : https://www.raspberrypi.com/documentation/computers/configuration.html
- **Setup Headless** : https://www.raspberrypi.com/documentation/computers/configuration.html#set-up-a-headless-raspberry-pi
- **Networking** : https://www.raspberrypi.com/documentation/computers/configuration.html#networking
- **Boot Folder** : https://www.raspberrypi.com/documentation/computers/configuration.html#boot-folder-contents
- **Device Tree** : https://www.raspberrypi.com/documentation/computers/configuration.html#device-trees-overlays-and-parameters
- **raspi-config CLI** : https://www.raspberrypi.com/documentation/computers/configuration.html#non-interactive-raspi-config

## ✅ Checklist Configuration Headless

- [x] `userconf.txt` créé avec format correct
- [x] Fichier `ssh` vide créé
- [x] Pays WiFi configuré (REGDOMAIN)
- [x] Service set-wifi-region.service créé
- [x] cloud-init désactivé
- [x] Hostname configuré
- [x] Timezone configurée
- [x] Locale configurée
- [x] Keyboard configuré
- [x] Auto-login configuré (optionnel)
- [x] MOTD configuré (optionnel)
- [x] Services systemd avec dépendances correctes

## 🎯 Résumé des Changements

### Avant (custom scripts)
- ❌ Script custom `setup-user.sh`
- ❌ Service custom `setup-user.service`
- ❌ Complexité de maintenance
- ❌ Risque d'erreurs

### Après (méthodes officielles)
- ✅ `userconf.txt` + `userconfig.service` natif
- ✅ Méthodes documentées et supportées
- ✅ Simplicité et fiabilité
- ✅ Maintenance assurée par Raspberry Pi

---

**Date de mise à jour** : 5 novembre 2025  
**Version Raspberry Pi OS** : Bookworm (Debian 12)  
**Architecture** : ARM64
