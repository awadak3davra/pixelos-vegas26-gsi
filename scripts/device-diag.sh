#!/usr/bin/env bash
# Full health check of a running vegas26 PixelOS GSI over adb (no root needed).
# Usage: bash device-diag.sh <out-dir>     -> raw dumps in <out-dir>, summary on stdout
set -uo pipefail
D="${1:?out dir}"; mkdir -p "$D"; cd "$D"
A() { adb shell "$@" 2>&1 | tr -d '\r'; }
adb logcat -d -b all -v threadtime > logcat-all.txt 2>&1
adb logcat -d -b crash -v threadtime > logcat-crash.txt 2>&1
adb logcat -d -b radio -v threadtime > logcat-radio.txt 2>&1
A getprop > getprop.txt; A dmesg > dmesg.txt; A lshal > lshal.txt
A dumpsys dropbox --print > dropbox.txt
for s in telephony.registry wifi bluetooth_manager media.camera media.audio_flinger sensorservice fingerprint nfc location battery thermalservice display SurfaceFlinger ims activity\ services; do
  A dumpsys $s > "dumpsys-${s// /_}.txt"
done
P() { grep -m1 "^\[$1\]" getprop.txt | sed 's/.*: \[\(.*\)\]/\1/'; }
echo "### SYSTEM"
echo "build: $(P ro.build.fingerprint)"
echo "vendor: $(P ro.vendor.build.fingerprint)  vndk $(P ro.vndk.version)  kernel $(A uname -r)"
echo "uptime: $(A cat /proc/uptime | cut -d' ' -f1)s  boot history: $(P persist.sys.boot.reason.history | tr '\n' ' ')"
echo "system_server starts: $(P sys.system_server.start_count)  selinux: $(A getenforce)  encryption: $(P ro.crypto.state)/$(P ro.crypto.type)"
echo "provisioned: $(A settings get global device_provisioned)  user setup: $(A settings get secure user_setup_complete)"
echo "### CRASHES / ANR"
grep -E 'Process: ' logcat-crash.txt | sed 's/.*Process: //; s/, PID.*//' | sort | uniq -c | sed 's/^/crash  /'
grep -E 'Fatal signal' logcat-all.txt | sed -E 's/.*\(([^)]*)\), pid [0-9]+ \(([^)]*)\).*/native \2 \1/' | sort | uniq -c | head
grep -E 'ANR in ' logcat-all.txt | sed 's/.*ANR in //' | sort | uniq -c | sed 's/^/anr    /'
grep -E '^[0-9-]+ [0-9:.]+ (system_app_crash|data_app_crash|system_app_anr|data_app_anr|SYSTEM_TOMBSTONE|system_server_(crash|wtf|watchdog)|SYSTEM_RESTART|SYSTEM_LAST_KMSG)' dropbox.txt | awk '{print $3}' | sort | uniq -c | sed 's/^/dropbox/'
echo "tombstones: $(A ls /data/tombstones 2>&1 | head -3 | tr '\n' ' ')"
echo "### INIT SERVICES (crashed / restarting)"
grep -E 'init *: (Service|service) .* (exited|crashed|killed)' logcat-all.txt dmesg.txt 2>/dev/null | grep -oE "Service '[^']+'|service '[^']+'" | sort | uniq -c | sort -rn | head -12
grep -E 'Could not find .* for ctl\.|interface_start' logcat-all.txt | grep -oE "'[^']+'" | sort | uniq -c | head
echo "### SELINUX DENIALS (top)"
grep -h 'avc:  denied' logcat-all.txt dmesg.txt | grep -oE 'scontext=u:r:[a-z0-9_]+|tcontext=u:object_r:[a-z0-9_]+|tclass=[a-z_]+' | paste - - - | sort | uniq -c | sort -rn | head -12
echo "### PRIVAPP"
grep -c 'Privileged permission .* not in privapp-permissions allowlist' logcat-all.txt | sed 's/^/violations: /'
grep 'not in privapp-permissions allowlist' logcat-all.txt | grep -oE 'Privileged permission [^ ]+ for package [^ ]+' | sort -u | head -15
echo "### HALs not available (declared, no instance)"
grep -E '^ *DM|^ *D ' lshal.txt | grep -c 'N/A' | sed 's/^/declared-not-running: /'
echo "### RADIO / IMS"
echo "sim: $(P gsm.sim.state)  op: $(P gsm.sim.operator.alpha)  net: $(P gsm.network.type)  pref mode: $(A settings get global preferred_network_mode)"
grep -m2 'mServiceState=' dumpsys-telephony.registry.txt | grep -oE 'mVoiceRegState=[^,]*|mDataRegState=[^,]*|mOperatorAlphaLong=[^,]*' | paste - - -
grep -E 'VOICE_REGISTRATION_STATE RegStateResult' logcat-radio.txt | tail -1 | grep -oE 'regState: [A-Z_]+|reasonForDenial: [0-9A-Z]+|rat: [A-Z_]+'
grep -iE 'ImsService|MtkMmTel|ims.*(bind|connected|ready)' logcat-all.txt | tail -2 | cut -c1-160
echo "### CONNECTIVITY"
echo "wifi: $(grep -m1 -E '^Wi-Fi is' dumpsys-wifi.txt)  bt: $(grep -m1 -E 'enabled:|state:' dumpsys-bluetooth_manager.txt | tr -s ' ')"
echo "nfc: $(grep -m1 mState dumpsys-nfc.txt)  gnss: $(grep -m1 -iE 'gnss.*(hal|version)|mGnssHal' dumpsys-location.txt | cut -c1-100)"
echo "### HARDWARE"
echo "cameras: $(grep -cE 'Device [0-9]+ is present|== Camera device' dumpsys-media.camera.txt)  ($(grep -m1 -E 'Number of camera devices' dumpsys-media.camera.txt | tr -s ' '))"
echo "audio outputs: $(grep -cE 'Output thread' dumpsys-media.audio_flinger.txt)  sensors: $(grep -m1 -E 'Total [0-9]+ h/w sensors|sensors' dumpsys-sensorservice.txt | cut -c1-80)"
echo "fingerprint: $(grep -m2 -iE 'sensorId|enrollments|prints' dumpsys-fingerprint.txt | tr -s ' ' | tr '\n' ' ' | cut -c1-140)"
echo "display: $(grep -m1 -oE 'mActiveSfDisplayMode=[^}]*|renderFrameRate [0-9.]+' dumpsys-display.txt | cut -c1-140)  refresh: $(grep -m1 -oE 'refresh-rate *: *[0-9.]+ *Hz' dumpsys-SurfaceFlinger.txt)"
echo "battery: $(grep -E '^  (level|status|AC powered|USB powered|temperature|health):' dumpsys-battery.txt | tr -s ' ' | tr '\n' ' ')"
echo "thermal: $(grep -m1 -E 'Thermal Status|Current temperatures' dumpsys-thermalservice.txt | tr -s ' ')"
echo "### OVERLAYS"
A cmd overlay list | grep -iE 'vegas|mtk-ims|mediatek.ims|treble' | tr -s ' '
echo "### STORAGE / MEMORY"
A df -h /data | tail -1; A cat /proc/meminfo | grep -E 'MemTotal|MemAvailable|SwapTotal'
