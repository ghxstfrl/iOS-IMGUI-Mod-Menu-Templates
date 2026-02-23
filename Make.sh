 (cd "$(git rev-parse --show-toplevel)" && git apply --3way <<'EOF' 
diff --git a/Make.sh b/Make.sh
old mode 100644
new mode 100755
index e38158cdf9325213e9231e0679c7a560e411ee63..354c23c15b0fe4478595784f8510e202d43ec8cf
--- a/Make.sh
+++ b/Make.sh
@@ -1 +1,13 @@
-make package install
\ No newline at end of file
+#!/usr/bin/env bash
+set -euo pipefail
+
+export THEOS="${THEOS:-/var/mobile/theos}"
+
+if [[ ! -f "$THEOS/makefiles/common.mk" || ! -f "$THEOS/makefiles/tweak.mk" ]]; then
+  echo "[error] THEOS is not configured correctly: $THEOS"
+  echo "[hint] Install Theos and/or export THEOS to the correct path."
+  echo "[hint] Example: export THEOS=$HOME/theos"
+  exit 1
+fi
+
+make clean package install
 
EOF
)
