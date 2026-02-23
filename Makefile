diff --git a/Makefile b/Makefile
index 1aaee9743399b6732a109aa92d1d23f692838130..872f82900d8136cb1f10891846c2eef1666d8be2 100644
--- a/Makefile
+++ b/Makefile
@@ -1,29 +1,32 @@
-export THEOS=/var/mobile/theos
+export THEOS ?= /var/mobile/theos
+
+ifeq ($(wildcard $(THEOS)/makefiles/common.mk),)
+$(error THEOS is not configured. Set THEOS to your theos path (example: export THEOS=$$HOME/theos))
+endif
 
 
 ARCHS = arm64 
 
 DEBUG = 0
 FINALPACKAGE = 1
 FOR_RELEASE = 1
 
 include $(THEOS)/makefiles/common.mk
 
 TWEAK_NAME = X2NIOSVN
 
 
 X2NIOSVN_FRAMEWORKS =  UIKit Foundation Security QuartzCore CoreGraphics CoreText  AVFoundation Accelerate GLKit SystemConfiguration GameController
 
 X2NIOSVN_CCFLAGS = -std=c++11 -fno-rtti -fno-exceptions -DNDEBUG
 X2NIOSVN_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value
 
 X2NIOSVN_FILES =   ImGuiDrawView.mm $(wildcard Esp/*.mm)   $(wildcard Esp/*.m) $(wildcard KittyMemory/*.cpp) $(wildcard KittyMemory/*.mm) 
 
 
 
 #X2NIOSVN_LIBRARIES += substrate
 # GO_EASY_ON_ME = 1
 
 include $(THEOS_MAKE_PATH)/tweak.mk
 
-

