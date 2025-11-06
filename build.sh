#!/bin/bash
# RuntipiOS Build Script
# Based on Home Assistant OS build approach

set -e

# Configuration
BUILDROOT_VERSION="${BUILDROOT_VERSION:-2024.08.x}"
BOARD="${BOARD:-runtipios_rpi4_64}"
BUILD_DIR="${BUILD_DIR:-build}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"
JOBS="${JOBS:-$(nproc)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
  ____              _   _       _    ___  ____  
 |  _ \ _   _ _ __ | |_(_)_ __ (_)  / _ \/ ___| 
 | |_) | | | | '_ \| __| | '_ \| | | | | \___ \ 
 |  _ <| |_| | | | | |_| | |_) | | | |_| |___) |
 |_| \_\\__,_|_| |_|\__|_| .__/|_|  \___/|____/ 
                         |_|                     
EOF
echo -e "${NC}"
echo "RuntipiOS - Lightweight Linux for Runtipi"
echo "=========================================="
echo ""

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=(
        "git" "make" "gcc" "g++" "wget" "cpio" "rsync" 
        "bc" "bison" "flex" "libssl-dev" "libncurses5-dev"
    )
    
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null && ! dpkg -s "$dep" &> /dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt-get install ${missing[*]}"
        exit 1
    fi
    
    log_info "All dependencies satisfied"
}

clone_buildroot() {
    if [ -d "$BUILD_DIR/buildroot" ]; then
        log_info "Buildroot already cloned, updating..."
        cd "$BUILD_DIR/buildroot"
        git fetch origin
        git checkout "$BUILDROOT_VERSION"
        cd ../..
    else
        log_info "Cloning Buildroot $BUILDROOT_VERSION..."
        mkdir -p "$BUILD_DIR"
        git clone --depth=1 --branch "$BUILDROOT_VERSION" \
            https://github.com/buildroot/buildroot.git "$BUILD_DIR/buildroot"
    fi
}

configure_buildroot() {
    log_info "Configuring Buildroot for $BOARD..."
    
    cd "$BUILD_DIR/buildroot"
    
    # Set BR2_EXTERNAL to parent directory
    export BR2_EXTERNAL="$(cd ../..; pwd)"
    
    log_info "Using BR2_EXTERNAL=$BR2_EXTERNAL"
    
    # Load defconfig
    make "${BOARD}_defconfig"
    
    cd ../..
}

build_image() {
    log_info "Building image (this will take a while)..."
    log_info "Using $JOBS parallel jobs"
    
    cd "$BUILD_DIR/buildroot"
    
    # Build with progress
    make -j"$JOBS" 2>&1 | tee build.log
    
    cd ../..
    
    log_info "Build completed successfully!"
}

package_image() {
    log_info "Packaging output image..."
    
    mkdir -p "$OUTPUT_DIR"
    
    local image_file="$BUILD_DIR/buildroot/output/images/sdcard.img"
    
    if [ -f "$image_file" ]; then
        local output_name="runtipios-${BOARD}-$(date +%Y%m%d-%H%M%S).img"
        cp "$image_file" "$OUTPUT_DIR/$output_name"
        
        # Compress
        log_info "Compressing image..."
        gzip -f "$OUTPUT_DIR/$output_name"
        
        log_info "Image saved to: $OUTPUT_DIR/$output_name.gz"
        log_info "Size: $(du -h "$OUTPUT_DIR/$output_name.gz" | cut -f1)"
    else
        log_error "Image file not found: $image_file"
        exit 1
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -b, --board BOARD       Board configuration (default: runtipios_rpi4_64)
    -v, --version VERSION   Buildroot version (default: 2024.08.x)
    -j, --jobs JOBS         Number of parallel jobs (default: $(nproc))
    -c, --clean             Clean build directory before building
    -m, --menuconfig        Run menuconfig before building
    -h, --help              Show this help message

Examples:
    $0                      # Build with defaults
    $0 -j 8                 # Build with 8 parallel jobs
    $0 -c                   # Clean build
    $0 -m                   # Configure before building

EOF
}

# Parse arguments
CLEAN=false
MENUCONFIG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--board)
            BOARD="$2"
            shift 2
            ;;
        -v|--version)
            BUILDROOT_VERSION="$2"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -m|--menuconfig)
            MENUCONFIG=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main build process
log_info "Starting RuntipiOS build"
log_info "Board: $BOARD"
log_info "Buildroot version: $BUILDROOT_VERSION"
log_info "Jobs: $JOBS"
echo ""

# Clean if requested
if [ "$CLEAN" = true ]; then
    log_warn "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# Build steps
check_dependencies
clone_buildroot
configure_buildroot

# Run menuconfig if requested
if [ "$MENUCONFIG" = true ]; then
    log_info "Opening menuconfig..."
    cd "$BUILD_DIR/buildroot"
    make menuconfig
    cd ../..
fi

build_image
package_image

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Flash the image with:"
echo "  sudo dd if=$OUTPUT_DIR/*.img.gz bs=4M status=progress | gunzip | sudo dd of=/dev/sdX bs=4M status=progress"
echo ""
echo "Or use a tool like:"
echo "  - Balena Etcher (GUI)"
echo "  - Raspberry Pi Imager"
echo ""
