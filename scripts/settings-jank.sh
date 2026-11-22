#!/bin/bash
# Settings jank A/B on the phone. Usage: settings-jank.sh <step>
#   state     dexopt, refresh rate, blur, animation scales, SF composition summary
#   trace N   20 s layers trace while the user opens/closes Settings subpages -> logs/settings-N.pftrace
#   compile   AOT-compile Settings (speed) and SystemUI/launcher stay as they are
#   blur on|off, anim 1|0.5 (backpressure is build-time: persist.sys.phh.* needs root, no adb root)
set -e
OUT="${VEGAS_LOGDIR:-$(dirname "$0")/../../logs}"; mkdir -p "$OUT"
A=adb; H="$(dirname "$0")"
case "$1" in
state)
  $A shell 'dumpsys package dexopt | grep -A2 "\[com.android.settings\]"
    echo "refresh: $(settings get system peak_refresh_rate) / $(settings get system min_refresh_rate)"
    echo "blurs_disabled: $(settings get global disable_window_blurs) supports_blur: $(getprop ro.surface_flinger.supports_background_blur)"
    echo "anim: $(settings get global window_animation_scale) $(settings get global transition_animation_scale) $(settings get global animator_duration_scale)"
    echo "backpressure: $(getprop persist.sys.phh.enable_sf_hwc_backpressure) gl: $(getprop debug.sf.enable_gl_backpressure)"
    echo "renderengine: $(getprop debug.renderengine.backend) hwui: $(getprop debug.hwui.renderer)"
    dumpsys SurfaceFlinger | grep -E "^ *(Display|HWC|Composition|  [A-Z])" | grep -iE "client|device|composition" | head -40' ;;
trace)
  $A push "$H/jank-layers.cfg" /data/misc/perfetto-configs/jank-layers.cfg >/dev/null
  echo "Recording 20 s: open 3-4 Settings subpages and go back each time"
  $A shell perfetto --txt -c /data/misc/perfetto-configs/jank-layers.cfg -o /data/misc/perfetto-traces/settings.pftrace
  $A pull /data/misc/perfetto-traces/settings.pftrace "$OUT/settings-${2:-1}.pftrace" ;;
compile)
  $A shell cmd package compile -m speed -f com.android.settings ;;
blur)  [ "$2" = off ] && v=1 || v=0; $A shell settings put global disable_window_blurs $v ;;
anim)  for k in window_animation_scale transition_animation_scale animator_duration_scale; do $A shell settings put global $k "$2"; done ;;
*) sed -n 2,7p "$0" ;;
esac
