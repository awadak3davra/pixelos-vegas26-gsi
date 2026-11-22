# Adaptive brightness on vegas26 GSI (21.11.2026)

## Symptom
Auto brightness set once at screen-on, then frozen. ABC dump: mState=AUTO_BRIGHTNESS_ENABLED,
mLightSensorEnabled=true, ring buffer holds one sample whose age grows. sensorservice history:
"+ 0x5 AutomaticBrightnessController$2" immediately followed by "- 0x5 ...ABC$2" at every wake.

## Root cause: not a code regression
Settings.System `auto_brightness_one_shot=1` (Lineage/PixelOS "One shot auto-brightness",
Settings > Display > Adaptive brightness). Written by com.android.settings (settings generation 2),
i.e. toggled in the Settings UI; framework default is 0 (DisplayPowerController line ~2534).
Timeline from dumpsys: 14:13:37 ABC registered and stayed; 14:13:59 "- ABC" with screen on
(= ABC.handleSettingsChange() when one-shot flipped on). Afterwards every wake: register,
one reading, `updateAutoBrightness()` unregisters (`if (mAutoBrightnessOneShot) unregisterListener`)
while mLightSensorEnabled stays true. That is the designed one-shot behaviour.

None of our framework patches (0002..0005), VegasActions, phh brightness code are involved.

## Fix
`adb shell settings put system auto_brightness_one_shot 0` (same as switching the toggle off in
Settings > Display > Adaptive brightness). No rebuild needed.
Verified 14:20-14:21: ABC$2 stays in the sensorservice active connections, mRecentLightSamples
grows (94 -> 179 in ~6 s), ring buffer filled with 20 ms samples.

## Calibration
Motorola stock curve is already in use: /vendor/overlay/MotoFrameworkResOverlayDeviceConfigOrlando.apk
(stock vendor RRO, enabled) provides config_autoBrightnessLevels (1..30000 lux),
config_autoBrightnessDisplayValuesNits (3..1000 nits), config_screenBrightnessNits/Backlight
(0..255 -> 0..1000 nits); FrameworkResOverlayExt (MTK) provides config_autoBrightnessLcdBacklightValues.
dumpsys display: DisplayDeviceConfig mLoadedFrom=<config.xml>, PhysicalMappingStrategy
mDefaultConfig equals the Moto arrays. No /vendor/etc/displayconfig xml on this device.
So nothing to copy into VegasFrameworkDefaults; adding the arrays there would only duplicate them.

Leftovers seen in the dump (not changed): debounce -1 (Moto overlay sets no
config_autoBrightnessBrighteningLightDebounce), hysteresis 10%/20%.
