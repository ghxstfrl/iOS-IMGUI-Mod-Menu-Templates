diff --git a/README.md b/README.md
index e0dafe8f497f41ab4344455e89ccdcbd227735a1..42ae7568899f2ccd9908fca4a91c4fb51856d3eb 100644
--- a/README.md
+++ b/README.md
@@ -1,6 +1,38 @@
 <b>iOS IMGUI Mod Menu by Nguyen Nam<b/><br>
 
 <b>This project makes it possible for users to create cheat menu with IMGUI.<b/><br>
 <b>Project by Nguyen Nam (X2NIOS).<b/><br>
 <b>Share with credit!<b/><br>
 Thx.
+
+## Build prerequisites
+
+This tweak requires a working Theos install. The Makefile expects Theos makefiles at:
+
+- `$(THEOS)/makefiles/common.mk`
+- `$(THEOS)/makefiles/tweak.mk`
+
+The default path is `/var/mobile/theos`, but you can override it by exporting `THEOS`.
+
+### Quick verification
+
+Run these commands in your build shell:
+
+```bash
+echo "$THEOS"
+ls "$THEOS/makefiles/common.mk" "$THEOS/makefiles/tweak.mk"
+```
+
+If those files do not exist, install Theos or point `THEOS` to the correct folder.
+
+### Windows note
+
+`make`/Theos builds should run in a Unix-like shell (jailbroken iOS shell, macOS, Linux, or WSL).
+If you run the check directly in PowerShell with an empty `THEOS`, it expands to `C:\makefiles\...` and fails.
+
+### Build command
+
+```bash
+export THEOS=${THEOS:-$HOME/theos}
+make clean package
+```
