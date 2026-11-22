#!/system/bin/sh
# vegas26 double-tap-to-wake: what Motorola's TouchHwAidlService does on stock.
# Gesture codes for /sys/class/touchscreen/primary/gesture: 49 = double tap on, 48 = off.
#
#   vegas-dt2w.sh boot  -> AOSP secure setting double_tap_to_wake decides (unset = ON),
#                          unless the Phh toggle says 1
#   vegas-dt2w.sh phh   -> Phh Treble Settings toggle (persist.sys.phh.xiaomi.dt2w) decides.
# The patched Treble app (default ON) rewrites the toggle at every startup, so the prop always
# holds the user's choice once the app has run; before that it may be TrebleDroid's shipped 0,
# which only ever comes before the app sets the real value, so following it is safe.
NODE=/sys/class/touchscreen/primary/gesture
mode="${1:-boot}"
if [ "$mode" = "phh" ]; then
    [ "$(getprop sys.boot_completed)" = "1" ] || exit 0
    want=$(getprop persist.sys.phh.xiaomi.dt2w)
    # keep the AOSP setting in sync with the toggle
    settings put secure double_tap_to_wake "$want" >/dev/null 2>&1
else
    want=$(settings get secure double_tap_to_wake 2>/dev/null)
    [ "$(getprop persist.sys.phh.xiaomi.dt2w)" = "1" ] && want=1
    case "$want" in 0) ;; *) want=1; settings put secure double_tap_to_wake 1 >/dev/null 2>&1 ;; esac
fi
[ "$want" = "1" ] && v=49 || v=48
if [ -e "$NODE" ] && echo "$v" > "$NODE" 2>/dev/null; then
    log -t vegas-dt2w "mode=$mode gesture=$v via sysfs"
else
    service call com.motorola.hardware.display.touch.IMotTouch/default 16 i32 "$v" >/dev/null 2>&1 \
        && log -t vegas-dt2w "mode=$mode gesture=$v via IMotTouch" \
        || log -t vegas-dt2w "mode=$mode failed to set gesture=$v"
fi
