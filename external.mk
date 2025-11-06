# RuntipiOS - BR2_EXTERNAL Makefile
#
# This file includes additional packages for RuntipiOS

include $(sort $(wildcard $(BR2_EXTERNAL_RUNTIPIOS_PATH)/package/*/*.mk))
