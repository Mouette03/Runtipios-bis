#!/bin/bash
CONFIG_FILE="/boot/config.yml"
USERNAME=$(grep 'default_user:' $CONFIG_FILE | awk '{print $2}')
PASSWORD=$(grep 'default_password:' $CONFIG_FILE | awk '{print $2}')
HASH=$(echo "$PASSWORD" | openssl passwd -6 -stdin)
echo "${USERNAME}:${HASH}" > /boot/userconf.txt
