#!/bin/bash
#==============================================================================
# RuntipiOS Build Script
# Builds a customized Debian/Raspberry Pi OS image for running Runtipi
#==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load configuration
source "${SCRIPT_DIR}/config/runtipios.conf"

#==============================================================================
# FUNCTIONS
#==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    local deps=("wget" "curl" "unzip" "xz" "fdisk" "losetup" "mkfs.ext4" "mkfs.vfat" "qemu-arm-static")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt-get install wget curl unzip xz-utils fdisk util-linux e2fsprogs dosfstools qemu-user-static"
        exit 1
    fi
}

usage() {
    cat << EOF
Usage: $0 <platform> [options]

Platforms:
  rpi5          Raspberry Pi 5 (64-bit)
  rpi4          Raspberry Pi 4 (64-bit) [Coming soon]
  
Options:
  -h, --help    Show this help message
  -c, --clean   Clean build directory before building
  
Examples:
  sudo $0 rpi5
  sudo $0 rpi5 --clean

EOF
    exit 1
}

#==============================================================================
# MAIN
#==============================================================================

# Check for root
check_root

# Parse arguments
PLATFORM=""
CLEAN_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        rpi5|rpi4)
            PLATFORM="$1"
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            ;;
    esac
done

if [ -z "$PLATFORM" ]; then
    log_error "Platform not specified"
    usage
fi

# Check dependencies
check_dependencies

# Create build directories
BUILD_DIR="${SCRIPT_DIR}/build/${PLATFORM}"
OUTPUT_DIR="${SCRIPT_DIR}/output"
DOWNLOAD_DIR="${SCRIPT_DIR}/downloads"

if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR" ]; then
    log_info "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR" "$DOWNLOAD_DIR"

log_info "========================================="
log_info "Building RuntipiOS for ${PLATFORM}"
log_info "========================================="
log_info "Build directory: ${BUILD_DIR}"
log_info "Output directory: ${OUTPUT_DIR}"
log_info ""

# Load platform-specific build script
PLATFORM_BUILD_SCRIPT="${SCRIPT_DIR}/platforms/${PLATFORM}/build-${PLATFORM}.sh"

if [ ! -f "$PLATFORM_BUILD_SCRIPT" ]; then
    log_error "Platform build script not found: ${PLATFORM_BUILD_SCRIPT}"
    exit 1
fi

# Export variables for platform script
export SCRIPT_DIR BUILD_DIR OUTPUT_DIR DOWNLOAD_DIR PLATFORM
export RUNTIPIOS_HOSTNAME RUNTIPIOS_TIMEZONE RUNTIPIOS_LOCALE
export RUNTIPIOS_HOTSPOT_SSID RUNTIPIOS_HOTSPOT_PASSWORD
export RUNTIPIOS_RUNTIPI_VERSION RUNTIPIOS_RUNTIPI_DIR

# Run platform-specific build
source "$PLATFORM_BUILD_SCRIPT"

log_success "========================================="
log_success "Build completed successfully!"
log_success "========================================="
log_info "Image location: ${OUTPUT_DIR}/"
ls -lh "${OUTPUT_DIR}"/runtipios-${PLATFORM}-*.img* 2>/dev/null || true
log_info ""
log_info "Flash to SD card with:"
log_info "  sudo dd if=${OUTPUT_DIR}/runtipios-${PLATFORM}-*.img of=/dev/sdX bs=4M status=progress conv=fsync"
log_info ""
