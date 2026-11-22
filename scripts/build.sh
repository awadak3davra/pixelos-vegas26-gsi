#!/usr/bin/env bash
# Build the PixelOS vegas26 GSI.  Run as builder inside the `pixelos` WSL distro:
#   bash <port>/scripts/build.sh [userdebug|user] [--repatch]
#   --repatch  reset every patched project to its manifest revision and apply all patches again
#   VEGAS_TOP (source tree, default /src/pixelos), VEGAS_OUTDIR (where images go)
set -euo pipefail
VARIANT="${1:-userdebug}"
PORT="$(cd "$(dirname "$0")/.." && pwd)"
TOP="${VEGAS_TOP:-/src/pixelos}"
OUTDIR="${VEGAS_OUTDIR:-$PORT/../out}"
cd "$TOP"
sudo swapon /swapfile 2>/dev/null || true

# The distro's ext4.vhdx grows on the host drive; if that drive fills up mid-build the WSL VM
# dies with "Bus error" (seen 2026-11-20). Refuse to start without headroom.
HOST_FREE_G="$(df -BG --output=avail "${VEGAS_HOST_DRIVE:-$TOP}" 2>/dev/null | tail -1 | tr -dc 0-9)"
if [ -n "$HOST_FREE_G" ] && [ "$HOST_FREE_G" -lt "${MIN_HOST_FREE_G:-60}" ]; then
  echo "host drive (VEGAS_HOST_DRIVE) has only ${HOST_FREE_G}G free (< ${MIN_HOST_FREE_G:-60}G); free space first" >&2; exit 2
fi

# 1. port tree into the source tree (copy, not symlink: Soong does not follow symlinks out of the tree)
mkdir -p device/pixelos/vegas_gsi
rsync -a --delete --exclude .git "$PORT/" device/pixelos/vegas_gsi/
# files edited on Windows may carry CRLF; patches and scripts must be LF
find device/pixelos/vegas_gsi -type f \( -name '*.sh' -o -name '*.mk' -o -name '*.bp' -o -name '*.xml' -o -name '*.patch' \) \
  -exec sed -i 's/\r$//' {} +

# 2. patches: applied once per tree state (stamp in out/), --repatch starts over
if [ "${2:-}" = "--repatch" ]; then bash device/pixelos/vegas_gsi/scripts/reset-patched.sh; fi
if [ ! -f out/.vegas-patched ]; then
  bash device/pixelos/vegas_gsi/scripts/apply-patches.sh
fi

# 3. TrebleApp from source (vendor/hardware_overlay is patched to take treble_app/TrebleApp.apk,
#    so the patched treble_app is what ships). Rebuilt whenever treble_app HEAD changes.
TA_STAMP="out/.trebleapp-$(git -C treble_app rev-parse --short HEAD)"
if [ ! -f treble_app/TrebleApp.apk ] || [ ! -f "$TA_STAMP" ]; then
  dpkg -s openjdk-17-jdk-headless >/dev/null 2>&1 || sudo apt-get install -y -qq openjdk-17-jdk-headless >/dev/null
  ( cd treble_app && bash build.sh release )
  rm -f out/.trebleapp-*; touch "$TA_STAMP"
fi

# 4. build
if [ "$VARIANT" = "userdebug" ]; then export VEGAS_DEBUG="${VEGAS_DEBUG:-1}"; else export VEGAS_DEBUG=0; fi
# vendor/lineage turns adb auth off (ro.adb.secure=0) only through this switch
if [ "$VEGAS_DEBUG" = "1" ]; then export WITH_ADB_INSECURE=true; else unset WITH_ADB_INSECURE; fi
export VEGAS_GCAM="${VEGAS_GCAM:-0}"
echo "variant=$VARIANT VEGAS_DEBUG=$VEGAS_DEBUG WITH_ADB_INSECURE=${WITH_ADB_INSECURE:-} VEGAS_GCAM=$VEGAS_GCAM"
export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache CCACHE_DIR=/src/.ccache
ccache -M 40G >/dev/null
set +u; source build/envsetup.sh
REL="$(sed -n 's/^aosp_target_release=//p' vendor/lineage/vars/aosp_target_release 2>/dev/null)"
REL="${REL:-bp4a}"
lunch "custom_vegas_gsi-${REL}-${VARIANT}"
set -u
# JOBS: the WSL VM has ~30 GB RAM shared with other distros (Frigate); 24 jobs OOM-killed ninja
# in the Java/dex phase on 2026-11-20, so default to 12.
m -j"${JOBS:-12}" systemimage

# 5. package: raw ext4 system.img -> xz
IMG="$OUT/system.img"
file "$IMG"
if file "$IMG" | grep -q 'Android sparse'; then simg2img "$IMG" "$OUT/system-raw.img"; IMG="$OUT/system-raw.img"; fi
STAMP="$(date +%Y%m%d-%H%M)"
NAME="PixelOS-16.2-vegas26-gsi-arm64-ab-${VARIANT}-${STAMP}.img"
mkdir -p "$OUTDIR"
xz -T0 -6 -c "$IMG" > "$OUTDIR/$NAME.xz"
sha256sum "$OUTDIR/$NAME.xz" | tee "$OUTDIR/$NAME.xz.sha256"
ls -la "$OUTDIR/$NAME.xz"
