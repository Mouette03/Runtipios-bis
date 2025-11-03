#!/bin/bash

# Usage: 00-setup-userconf.sh <boot_mount_point> <config_yml_path>
# Example: 00-setup-userconf.sh mnt/boot mnt/opt/runtipi-hotspot/config.yml

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <boot_mount_point> <config_yml_path>"
    echo "Example: $0 /mnt/boot /mnt/opt/runtipi-hotspot/config.yml"
    exit 1
fi

BOOT_MOUNT="$1"
CONFIG_FILE="$2"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

if [ ! -d "$BOOT_MOUNT" ]; then
    echo "ERROR: Boot mount point not found: $BOOT_MOUNT"
    exit 1
fi

# Extract username and password from config.yml
USERNAME=$(grep 'default_user:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")
PASSWORD=$(grep 'default_password:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "ERROR: Could not extract username or password from $CONFIG_FILE"
    echo "USERNAME: '$USERNAME'"
    echo "PASSWORD: '$PASSWORD'"
    exit 1
fi

# Generate password hash (SHA-512)
HASH=$(echo "$PASSWORD" | openssl passwd -6 -stdin)

if [ -z "$HASH" ]; then
    echo "ERROR: Failed to generate password hash"
    exit 1
fi

# Create userconf.txt in boot partition
USERCONF_PATH="$BOOT_MOUNT/userconf.txt"
echo "${USERNAME}:${HASH}" > "$USERCONF_PATH"

if [ $? -eq 0 ]; then
    echo "✓ userconf.txt created successfully at $USERCONF_PATH"
    echo "  Username: $USERNAME"
    echo "  Hash: ${HASH:0:20}..."
    cat "$USERCONF_PATH"
else
    echo "ERROR: Failed to create $USERCONF_PATH"
    exit 1
fi
