TARGET := iphone:clang:latest:latest
INSTALL_TARGET_PROCESSES = ACCompanion

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = X2NIOSVN

X2NIOSVN_FILES = ImGuiDrawView.mm Esp/*.m Esp/*.mm KittyMemory/*.cpp
X2NIOSVN_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
