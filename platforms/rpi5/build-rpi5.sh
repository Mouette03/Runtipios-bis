#!/bin/bash
#==============================================================================
# Raspberry Pi 5 Build Script
#==============================================================================

set -e

log_info "Loading Raspberry Pi 5 configuration..."
source "${SCRIPT_DIR}/platforms/rpi5/config/platform.conf"

#==============================================================================
# Download base image
#==============================================================================

download_base_image() {
    log_info "Downloading Raspberry Pi OS Lite base image..."
    
    local image_path="${DOWNLOAD_DIR}/${RPI5_BASE_IMAGE}"
    
    if [ -f "$image_path" ]; then
        log_info "Base image already downloaded"
    else
        log_info "Downloading from: ${RPI5_BASE_IMAGE_URL}"
        wget -O "$image_path" "${RPI5_BASE_IMAGE_URL}"
    fi
    
    # Extract if needed
    if [ ! -f "${image_path%.xz}" ]; then
        log_info "Extracting base image..."
        xz -dk "$image_path"
    fi
    
    BASE_IMAGE="${image_path%.xz}"
    log_success "Base image ready: ${BASE_IMAGE}"
}

#==============================================================================
# Prepare working image
#==============================================================================

prepare_image() {
    log_info "Preparing working image..."
    
    # Copy base image to build directory
    WORK_IMAGE="${BUILD_DIR}/runtipios-rpi5-work.img"
    cp "$BASE_IMAGE" "$WORK_IMAGE"
    
    # Add extra space
    local extra_space=$((${RUNTIPIOS_IMAGE_EXTRA_SPACE:-512} * 1024 * 1024))
    truncate -s +${extra_space} "$WORK_IMAGE"
    
    log_success "Working image created"
}

#==============================================================================
# Mount image
#==============================================================================

mount_image() {
    log_info "Mounting image partitions..."
    
    # Setup loop device
    LOOP_DEVICE=$(losetup -f --show -P "$WORK_IMAGE")
    log_info "Loop device: ${LOOP_DEVICE}"
    
    # Wait for partitions
    sleep 2
    partprobe "${LOOP_DEVICE}" 2>/dev/null || true
    sleep 1
    
    # Mount partitions
    MOUNT_BOOT="${BUILD_DIR}/mnt/boot"
    MOUNT_ROOT="${BUILD_DIR}/mnt/root"
    
    mkdir -p "$MOUNT_BOOT" "$MOUNT_ROOT"
    
    mount "${LOOP_DEVICE}p1" "$MOUNT_BOOT"
    mount "${LOOP_DEVICE}p2" "$MOUNT_ROOT"
    
    log_success "Partitions mounted"
}

#==============================================================================
# Customize system
#==============================================================================

customize_system() {
    log_info "Customizing system..."
    
    # Run customization script
    "${SCRIPT_DIR}/scripts/customize.sh" "$MOUNT_ROOT" "$MOUNT_BOOT"
    
    log_success "System customized"
}

#==============================================================================
# Unmount and finalize
#==============================================================================

unmount_image() {
    log_info "Unmounting partitions..."
    
    sync
    umount "$MOUNT_BOOT" || true
    umount "$MOUNT_ROOT" || true
    losetup -d "$LOOP_DEVICE" || true
    
    log_success "Partitions unmounted"
}

finalize_image() {
    log_info "Finalizing image..."
    
    # Generate final filename
    local timestamp=$(date +%Y%m%d)
    local final_image="${OUTPUT_DIR}/runtipios-rpi5-${timestamp}.img"
    
    # Copy to output
    cp "$WORK_IMAGE" "$final_image"
    
    # Compress if configured
    if [ "${RUNTIPIOS_IMAGE_COMPRESSION}" = "xz" ]; then
        log_info "Compressing image with xz..."
        xz -9 -T0 "$final_image"
        final_image="${final_image}.xz"
    elif [ "${RUNTIPIOS_IMAGE_COMPRESSION}" = "gzip" ]; then
        log_info "Compressing image with gzip..."
        gzip -9 "$final_image"
        final_image="${final_image}.gz"
    elif [ "${RUNTIPIOS_IMAGE_COMPRESSION}" = "zstd" ]; then
        log_info "Compressing image with zstd..."
        zstd -19 --rm "$final_image"
        final_image="${final_image}.zst"
    fi
    
    log_success "Final image: ${final_image}"
}

#==============================================================================
# Main build flow
#==============================================================================

# Ensure cleanup on exit
cleanup() {
    log_info "Cleaning up..."
    unmount_image 2>/dev/null || true
}
trap cleanup EXIT

# Build steps
download_base_image
prepare_image
mount_image
customize_system
unmount_image
finalize_image

log_success "Raspberry Pi 5 image build complete!"
