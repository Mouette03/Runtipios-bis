#!/bin/bash
# Post-build script for RuntipiOS - Common actions for all platforms

set -e

TARGET_DIR="${1}"

if [ -z "${TARGET_DIR}" ]; then
    echo "Error: TARGET_DIR not provided"
    exit 1
fi

echo "=== RuntipiOS Common Post-Build Script ==="
echo "TARGET_DIR: ${TARGET_DIR}"

# Create necessary directories
mkdir -p "${TARGET_DIR}/data"
mkdir -p "${TARGET_DIR}/root/.ssh"
mkdir -p "${TARGET_DIR}/var/log/lighttpd"
mkdir -p "${TARGET_DIR}/var/cache/lighttpd/compress"
mkdir -p "${TARGET_DIR}/var/www/html"
mkdir -p "${TARGET_DIR}/var/www/cgi-bin"

# Set correct permissions
chmod 755 "${TARGET_DIR}/data"
chmod 700 "${TARGET_DIR}/root/.ssh"
chmod 755 "${TARGET_DIR}/var/www"
chmod 755 "${TARGET_DIR}/var/www/html"
chmod 755 "${TARGET_DIR}/var/www/cgi-bin"
chmod 755 "${TARGET_DIR}/var/log/lighttpd"
chmod 755 "${TARGET_DIR}/var/cache/lighttpd"

# Ensure CGI scripts are executable
if [ -d "${TARGET_DIR}/var/www/cgi-bin" ]; then
    chmod +x "${TARGET_DIR}"/var/www/cgi-bin/*.sh 2>/dev/null || true
fi

echo "Common post-build actions completed"
