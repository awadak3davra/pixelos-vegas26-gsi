#!/usr/bin/env bash
# Install GCam (MGC 9.7.047) and the vegas26 config on a running phone over adb.
# GCam is not part of the image (see vegas.mk, VEGAS_GCAM); it is a normal user app.
# Usage (Git Bash): bash scripts/install-gcam.sh [path/to/GCam.apk]
# After install: open GCam, double-tap the dark area around the shutter -> pick vegas-gcam.xml -> Restore.
set -euo pipefail
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
HERE="$(cd "$(dirname "$0")/.." && pwd)"
APK="${1:-$HERE/preinstall/GCam.apk}"
CFG="$HERE/preinstall/vegas-gcam.xml"
[ -f "$APK" ] || { echo "no APK: $APK"; exit 1; }
adb install -r -g "$APK"
adb shell mkdir -p /sdcard/GcamConfigs
adb push "$CFG" /sdcard/GcamConfigs/vegas-gcam.xml >/dev/null
echo "GCam installed; config at /sdcard/GcamConfigs/vegas-gcam.xml (load it in GCam once)"
