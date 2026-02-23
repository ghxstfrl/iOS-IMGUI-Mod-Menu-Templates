export THEOS=/var/jb/var/mobile/theos
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = X2NIOSVN

# This exactly matches the repo layout you just showed me!
X2NIOSVN_FILES = Esp/PubgLoad.mm \
                 ImGuiDrawView.mm \
                 KittyMemory/KittyMemory.cpp \
                 KittyMemory/MemoryPatch.cpp \
                 KittyMemory/KittyUtils.cpp \
                 KittyMemory/writeData.cpp \
                 KittyMemory/imgui.cpp \
                 KittyMemory/imgui_demo.cpp \
                 KittyMemory/imgui_draw.cpp \
                 KittyMemory/imgui_tables.cpp \
                 KittyMemory/imgui_widgets.cpp \
                 KittyMemory/imgui_impl_metal.mm

X2NIOSVN_FRAMEWORKS = UIKit Foundation Security QuartzCore CoreGraphics CoreText Metal MetalKit

# These -I flags tell the compiler exactly where to look for your .h and .hpp files!
X2NIOSVN_CCFLAGS = -std=c++14 -fno-rtti -fno-exceptions -DNDEBUG -I./Esp -I./KittyMemory
X2NIOSVN_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -I./Esp -I./KittyMemory
include $(THEOS_MAKE_PATH)/tweak.mk
