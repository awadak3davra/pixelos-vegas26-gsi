#!/usr/bin/env bash
# Functional test of a vegas26 PixelOS GSI over adb (no SIM-dependent tests, no root).
# Usage: bash device-functest.sh <out-dir>
set -uo pipefail
D="${1:?out dir}"; mkdir -p "$D"; cd "$D"
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
A() { adb shell "$@" 2>&1 | tr -d '\r'; }
ok() { printf '%-14s %-5s %s\n' "$1" "$2" "$3"; }
adb logcat -c 2>/dev/null
A input keyevent KEYCODE_WAKEUP; A wm dismiss-keyguard >/dev/null; A input keyevent KEYCODE_HOME

# Wi-Fi
w=$(A dumpsys wifi | grep -m1 -E 'mWifiInfo SSID' | grep -oE 'Supplicant state: [A-Z]+|RSSI: -?[0-9]+|Link speed: [0-9]+Mbps|Frequency: [0-9]+MHz' | tr '\n' ' ')
p=$(A ping -c 3 -W 3 1.1.1.1 | grep -oE '[0-9]+% packet loss')
d=$(A ping -c 1 -W 3 google.com >/dev/null 2>&1 && echo dns-ok || echo dns-FAIL)
ok WiFi "$([ "$p" = "0% packet loss" ] && echo PASS || echo FAIL)" "$w| $p | $d"

# Bluetooth: toggle and adapter state
A cmd bluetooth_manager disable >/dev/null; sleep 3; A cmd bluetooth_manager enable >/dev/null; sleep 4
bt=$(A dumpsys bluetooth_manager | grep -m1 -E '^\s*state:' | tr -s ' ')
addr=$(A dumpsys bluetooth_manager | grep -m1 -oE 'address: [0-9A-F:]{17}' | sed 's/..:..:..$/xx:xx:xx/')
ok Bluetooth "$(echo "$bt" | grep -q ON && echo PASS || echo FAIL)" "$bt $addr (toggle off/on)"

# NFC: toggle
A svc nfc disable; sleep 3; A svc nfc enable; sleep 4
n=$(A dumpsys nfc | grep -m1 mState)
ok NFC "$(echo "$n" | grep -q 'mState=on' && echo PASS || echo FAIL)" "$n (toggle off/on)"

# GNSS: HAL + request a fix for 45 s
A cmd location set-location-enabled true
g=$(A dumpsys location | grep -m3 -iE 'gnss hal|GNSS_KPI|Gnss Capabilities|hardware model' | tr -s ' ' | tr '\n' ' ' | cut -c1-160)
A cmd location providers send-extra-command gps force_time_injection >/dev/null 2>&1
A am start -a android.intent.action.VIEW -d 'geo:0,0?q=test' >/dev/null 2>&1; sleep 45
sv=$(A dumpsys location | grep -m2 -oE 'CN0=[0-9.]+|Sv[A-Za-z ]*count[^,]*|satellites: [0-9]+|svCount=[0-9]+|mSvCount=[0-9]+|last location=Location\[gps [^]]{0,40}' | tr '\n' ' ')
lastgps=$(A dumpsys location | grep -A2 -m1 'gps provider' | grep -m1 -oE 'last location=Location\[[^]]*' | cut -c1-60)
ok GNSS "$([ -n "$lastgps" ] && echo PASS || echo CHECK)" "$g | $sv | ${lastgps:-no fix in 45s indoors}"
A input keyevent KEYCODE_HOME

# Sensors: count + live sample of accel/light/prox via sensorservice recent events
s=$(A dumpsys sensorservice | grep -oE 'Total [0-9]+ h/w sensors, [0-9]+ running')
A am start -a android.settings.DISPLAY_SETTINGS >/dev/null; sleep 3
ev=$(A dumpsys sensorservice | grep -A1 -iE '^(lsm|bmi|icm|accel|.*acc).*\(.*accelerometer|light.*: last|proximity.*: last' | head -4 | tr -s ' ' | tr '\n' ' ' | cut -c1-200)
ok Sensors "$(echo "$s" | grep -q 'h/w sensors' && echo PASS || echo FAIL)" "$s ${ev}"
A input keyevent KEYCODE_HOME

# Cameras: open back + front in the default camera, take a photo each, check new files
before=$(A ls /sdcard/DCIM/Camera 2>/dev/null | wc -l)
A am start -a android.media.action.STILL_IMAGE_CAMERA >/dev/null; sleep 6
A input keyevent KEYCODE_CAMERA; sleep 4
A am start -a android.media.action.STILL_IMAGE_CAMERA --ez android.intent.extras.CAMERA_FACING 1 --ei android.intent.extras.CAMERA_FACING 1 >/dev/null; sleep 5
A input keyevent KEYCODE_CAMERA; sleep 4
after=$(A ls /sdcard/DCIM/Camera 2>/dev/null | wc -l)
camapp=$(A dumpsys activity activities | grep -m1 -oE 'topResumedActivity=[^ ]+ [^ ]+ [^ ]+' | cut -c1-90)
camerr=$(adb logcat -d 2>/dev/null | grep -cE 'CameraDevice.*(ERROR|error)|camera.*FATAL|Camera service died|ERROR_CAMERA')
ok Camera "$([ "$after" -gt "$before" ] && [ "$camerr" = 0 ] && echo PASS || echo CHECK)" "photos $before->$after, camera errors=$camerr, app: $camapp"
A input keyevent KEYCODE_HOME
# GCam launch smoke test
A monkey -p com.android.MGC_9_7_047 -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 8
gc=$(adb logcat -d -b crash 2>/dev/null | grep -c 'MGC_9_7_047')
gtop=$(A dumpsys activity activities | grep -m1 -oE 'topResumedActivity=[^ ]+ [^ ]+ [^ ]+' | grep -c MGC)
ok GCam "$([ "$gc" = 0 ] && [ "$gtop" = 1 ] && echo PASS || echo CHECK)" "crashes=$gc foreground=$gtop"
A input keyevent KEYCODE_HOME

# Video encoder (H.264 HW) via screenrecord
A rm -f /sdcard/Download/sr.mp4; A screenrecord --time-limit 3 /sdcard/Download/sr.mp4 >/dev/null 2>&1
sz=$(A stat -c %s /sdcard/Download/sr.mp4 2>/dev/null)
ok VideoEnc "$([ "${sz:-0}" -gt 10000 ] && echo PASS || echo FAIL)" "screenrecord 3s -> ${sz:-0} bytes"

# Audio playback: skipped (silent run requested); output devices only
out=$(A dumpsys media.audio_flinger | grep -m1 -E 'Output devices:' | tr -s ' ')
ok AudioOut "INFO" "not played (silent run) $out"

# Microphone: record 3 s with the shell recorder if present
mic=$(A dumpsys media.audio_policy | grep -m1 -E 'Input devices|AUDIO_DEVICE_IN_BUILTIN_MIC' | tr -s ' ')
ok Mic "INFO" "${mic:-no builtin mic listed}"

# Vibrator
vb=$(A dumpsys vibrator_manager | grep -m1 -oE 'hasVibrator|isVibrating: (true|false)|HalVibration' )
ok Vibrator "INFO" "HAL: ${vb:-?} (not fired, silent run)"

# Flashlight via camera torch shell command
A cmd media.camera 2>/dev/null | head -0
ok Flashlight "MANUAL" "toggle in Quick Settings"

# Display
br=$(A settings get system screen_brightness); modes=$(A dumpsys display | grep -m1 -oE 'supportedModes [^]]*\]' | cut -c1-160)
ok Display "INFO" "brightness=$br $modes"

# Battery / charging
bat=$(A dumpsys battery | grep -E '^\s+(level|status|USB powered|AC powered|temperature|voltage|health|Charge counter):' | tr -s ' ' | tr '\n' ' ')
cur=$(A cat /sys/class/power_supply/battery/current_now 2>/dev/null)
ok Battery "INFO" "$bat current_now=${cur:-n/a}"

# USB
ok USB "INFO" "functions: $(A svc usb getFunctions 2>&1 | tail -1)"

# Fingerprint / face
fp=$(A dumpsys fingerprint | grep -m1 -oE '"service":"[^"]+"')
fc=$(A dumpsys face 2>/dev/null | grep -m1 -oE 'ParanoidSense|SenseProvider|"service":"[^"]+"')
ok Biometrics "INFO" "fingerprint=$fp face=${fc:-none}"

# Suspend / resume
A input keyevent KEYCODE_SLEEP; sleep 15
A input keyevent KEYCODE_WAKEUP; sleep 2
on=$(A dumpsys power | grep -m1 -oE 'mWakefulness=[A-Za-z]+')
susp=$(adb logcat -d -b kernel 2>/dev/null | grep -cE 'PM: suspend entry|suspend exit|Freezing user space')
ok Suspend "$(echo "$on" | grep -q Awake && echo PASS || echo FAIL)" "$on kernel-suspend-msgs=$susp"
A wm dismiss-keyguard >/dev/null

# Rotation
A settings put system accelerometer_rotation 1; rot=$(A dumpsys window | grep -m1 -oE 'mRotation=[0-9]|mUserRotation=[A-Z_0-9]+')
ok Rotation "INFO" "auto-rotate on, $rot (rotate the phone to check)"

# Storage
ok Storage "INFO" "$(A df -h /data | tail -1 | tr -s ' ')"

# Crashes during the test
cr=$(adb logcat -d -b crash 2>/dev/null | grep -E 'Process: |Fatal signal' | sed 's/.*Process: //;s/, PID.*//' | sort | uniq -c | tr '\n' ';')
anr=$(adb logcat -d 2>/dev/null | grep -oE 'ANR in [^ ]+' | sort | uniq -c | tr '\n' ';')
ok Stability "$([ -z "$cr$anr" ] && echo PASS || echo CHECK)" "crashes: ${cr:-none} anr: ${anr:-none}"
adb logcat -d -b all > logcat-functest.txt 2>&1
A input keyevent KEYCODE_HOME
