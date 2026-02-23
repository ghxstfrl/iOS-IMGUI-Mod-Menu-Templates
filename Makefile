#!/usr/bin/env bash
set -euo pipefail

export THEOS="${THEOS:-/var/mobile/theos}"

if [[ ! -f "$THEOS/makefiles/common.mk" || ! -f "$THEOS/makefiles/tweak.mk" ]]; then
 echo "[error] THEOS is not configured correctly: $THEOS"
 echo "[hint] Install Theos and/or export THEOS to the correct path."
 echo "[hint] Example: export THEOS=$HOME/theos"
 exit 1
fi

make clean package install
