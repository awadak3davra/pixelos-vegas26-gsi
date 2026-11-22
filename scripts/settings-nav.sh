# runs on the phone (sh): open Settings, enter and leave subpages, scroll; ~16 s
am start -W -n com.android.settings/.Settings >/dev/null; sleep 1.5
for a in android.settings.WIFI_SETTINGS android.settings.DISPLAY_SETTINGS android.settings.SOUND_SETTINGS android.settings.APPLICATION_SETTINGS android.settings.BATTERY_SAVER_SETTINGS; do
  am start -a $a >/dev/null; sleep 1.2
  input swipe 540 1700 540 700 250; sleep 0.8
  input keyevent BACK; sleep 1.0
done
input swipe 540 1800 540 600 300; sleep 0.8; input swipe 540 600 540 1800 300; sleep 0.8
input keyevent HOME
