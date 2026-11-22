#!/bin/bash
# settings-trace-auto.sh <tag>: layers trace while settings-nav.sh drives Settings
set -e; H="$(cd "$(dirname "$0")" && pwd)"; OUT="$H/../../logs"
adb push "$H/jank-layers.cfg" /data/misc/perfetto-configs/jank-layers.cfg >/dev/null
adb push "$H/settings-nav.sh" /data/local/tmp/settings-nav.sh >/dev/null
adb shell 'input keyevent WAKEUP; input keyevent HOME; am force-stop com.android.settings; sleep 1
  rm -f /data/misc/perfetto-traces/settings.pftrace
  perfetto --background --txt -c /data/misc/perfetto-configs/jank-layers.cfg -o /data/misc/perfetto-traces/settings.pftrace >/dev/null
  sleep 1; sh /data/local/tmp/settings-nav.sh; sleep 4'
adb pull /data/misc/perfetto-traces/settings.pftrace "$OUT/settings-$1.pftrace" | tail -1
