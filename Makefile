export THEOS=/var/jb/var/mobile/theos
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = X2NIOSVN

# If ImGuiDrawView is ALSO in the esp folder:
X2NIOSVN_FILES = Esp/PubgLoad.mm \
                 Esp/ImGuiDrawView.mm \
                 KittyMemory/KittyMemory.cpp \
                 KittyMemory/MemoryPatch.cpp \
                 KittyMemory/KittyUtils.cpp \
                 writeData.cpp \
                 imgui.cpp \
                 imgui_demo.cpp \
                 imgui_draw.cpp \
                 imgui_tables.cpp \
                 imgui_widgets.cpp \
                 imgui_impl_metal.mm

X2NIOSVN_FRAMEWORKS = UIKit Foundation Security QuartzCore CoreGraphics CoreText Metal MetalKit
X2NIOSVN_CCFLAGS = -std=c++11 -fno-rtti -fno-exceptions -DNDEBUG
X2NIOSVN_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value

include $(THEOS_MAKE_PATH)/tweak.mk
