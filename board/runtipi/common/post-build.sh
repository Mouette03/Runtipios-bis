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

# Set correct permissions
chmod 755 "${TARGET_DIR}/data"
chmod 700 "${TARGET_DIR}/root/.ssh"

echo "Common post-build actions completed"
