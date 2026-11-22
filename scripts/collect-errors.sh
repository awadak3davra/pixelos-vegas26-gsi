#!/usr/bin/env bash
# Collect error logs from the phone over adb (no root) and print a summary.
# Usage (Git Bash): bash scripts/collect-errors.sh <out-dir>
set -uo pipefail
D="${1:?out dir}"; mkdir -p "$D"; cd "$D"
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
A() { adb shell "$@" 2>&1 | tr -d '\r'; }
A 'getprop ro.build.date; getprop ro.build.fingerprint; cat /proc/uptime' > build.txt
adb logcat -d -b all -v threadtime > logcat-all.txt 2>&1
adb logcat -d -b crash -v threadtime > logcat-crash.txt 2>&1
adb logcat -d -b kernel -v threadtime > kernel.txt 2>&1
A dumpsys dropbox --print > dropbox.txt
A dumpsys activity exit-info > exit-info.txt
A 'getprop' > props.txt
A 'dumpsys SurfaceFlinger --latency-clear >/dev/null; dumpsys gfxinfo --stats' > /dev/null
A 'dumpsys SurfaceFlinger' > surfaceflinger.txt
A 'dumpsys gfxinfo com.android.systemui' > gfxinfo-systemui.txt
A 'dumpsys gfxinfo com.android.launcher3' > gfxinfo-launcher.txt
A 'dumpsys gfxinfo com.google.android.apps.nexuslauncher' >> gfxinfo-launcher.txt

{
echo "== uptime: $(sed -n 3p build.txt)"
echo "== crash buffer: processes"
grep -E 'Process: |>>> .* <<<' logcat-crash.txt | sed -E 's/.*Process: ([^,]+).*/java \1/; s/.*>>> ([^ ]+) <<<.*/native \1/' | sort | uniq -c | sort -rn
echo "== dropbox entries by tag"
grep -oE '^[0-9-]+ [0-9:.]+ [a-z_A-Z0-9]+' dropbox.txt | awk '{print $3}' | sort | uniq -c | sort -rn
echo "== ANR"
grep -oE 'ANR in [^ ]+' logcat-all.txt | sort | uniq -c
echo "== avc denials (scontext tcontext tclass perm)"
grep -h 'avc:  denied' logcat-all.txt kernel.txt | sed -E 's/.*denied  \{ ([^}]+) \}.*scontext=u:r:([^:]+):.*tcontext=u:object_r:([^:]+):.*tclass=([^ ]+).*/\2 \3 \4 {\1}/; s/.*denied  \{ ([^}]+) \}.*scontext=u:r:([^:]+):.*tcontext=u:r:([^:]+):.*tclass=([^ ]+).*/\2 \3 \4 {\1}/' | sort | uniq -c | sort -rn | head -40
echo "== service restarts / init errors"
grep -hE 'init *: .*(exited with status|killed by signal|Could not|Unable to|failed)' kernel.txt logcat-all.txt | sed -E 's/^.{0,40}init *: //' | sed -E 's/[0-9]+ ms/N ms/; s/pid [0-9]+/pid N/' | sort | uniq -c | sort -rn | head -40
echo "== E/F log tags (top 40)"
awk '$5=="E"||$5=="F"{t=$6; sub(/:$/,"",t); print $5" "t}' logcat-all.txt | sort | uniq -c | sort -rn | head -40
echo "== HAL / VINTF / service not found"
grep -hoE "(Could not find|failed to get|getService.*(null|failed)|is not declared in VINTF|Service .* didn't start|waitForService|not found in VINTF)[^\"]{0,100}" logcat-all.txt | sed -E 's/[0-9]{3,}/N/g' | sort | uniq -c | sort -rn | head -30
} > summary.txt
cat summary.txt
