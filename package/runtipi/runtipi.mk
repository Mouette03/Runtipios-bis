################################################################################
#
# runtipi
#
################################################################################

RUNTIPI_VERSION = v3.7.0
RUNTIPI_SITE = $(call github,runtipi,runtipi,$(RUNTIPI_VERSION))
RUNTIPI_LICENSE = GPL-3.0
RUNTIPI_LICENSE_FILES = LICENSE

define RUNTIPI_INSTALL_TARGET_CMDS
	# Create runtipi directory structure
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/opt/runtipi
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/opt/runtipi/state
	
	# Install runtipi installer script (will be called by post-boot service)
	# Note: Docker will be installed by Runtipi's official installer
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_RUNTIPIOS_PATH)/package/runtipi/runtipi-install.sh \
		$(TARGET_DIR)/usr/local/bin/runtipi-install
endef

$(eval $(generic-package))
