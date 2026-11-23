export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = GlassClock
GlassClock_FILES = Tweak.x
GlassClock_CFLAGS = -fobjc-arc
GlassClock_FRAMEWORKS = UIKit QuartzCore
include $(THEOS_MAKE_PATH)/tweak.mk
