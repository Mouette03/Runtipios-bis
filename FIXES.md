# Corrections apportées pour résoudre les problèmes

## 1. Installation de Docker via Runtipi ✅
- **Modifié** `package/runtipi/runtipi-install.sh` : utilise maintenant `curl -L https://setup.runtipi.io | bash`
- **Modifié** `package/runtipi/Config.in` : supprimé les dépendances Docker (sera installé par Runtipi)
- **Modifié** `configs/runtipios_rpi4_64_defconfig` : retiré BR2_PACKAGE_DOCKER_* pour éviter les conflits
- **Modifié** `runtipi-install.service` : s'exécute en tant que root, timeout augmenté à 1200s

## 2. Support Raspberry Pi 5 ✅
- **Créé** `configs/runtipios_rpi5_64_defconfig` : configuration dédiée Pi 5
- **Créé** `board/runtipi/config_rpi5.txt` : boot config pour Pi 5
- **Créé** `board/runtipi/genimage-rpi5.cfg` : layout d'image pour Pi 5
- **Modifié** `.github/workflows/build.yml` : build maintenant Pi 4 ET Pi 5

## 3. Correction génération d'image ✅
- **Modifié** `board/runtipi/genimage.cfg` : utilise "Image" au lieu de "kernel8.img", corrigé la structure overlays
- **Modifié** `board/runtipi/post-image.sh` : détecte automatiquement le type de board, gère les noms de kernel correctement
- **Modifié** defconfigs : simplifié les scripts POST_IMAGE (retiré support/scripts/genimage.sh qui causait des erreurs)

## 4. Correction scripts de build ✅
- **Modifié** `board/runtipi/post-build.sh` : 
  - Ajout de vérifications d'erreurs
  - Ne plante plus si chown échoue
  - Vérifie que TARGET_DIR est fourni
  - Gestion des erreurs pour tous les sed/ln

## Résultat attendu

Le workflow GitHub Actions devrait maintenant :
1. ✅ Générer 2 images complètes (pas 300ko) : 
   - `runtipios-runtipios_rpi4_64-XX.img.gz` (~400-500 MB)
   - `runtipios-runtipios_rpi5_64-XX.img.gz` (~400-500 MB)
2. ✅ Docker installé automatiquement par Runtipi lors du premier boot
3. ✅ Images bootables et fonctionnelles

## Test en local

```bash
chmod +x build.sh
./build.sh -b runtipios_rpi4_64
# ou
./build.sh -b runtipios_rpi5_64
```
