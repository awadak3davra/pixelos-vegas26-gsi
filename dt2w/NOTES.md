# vegas26 double tap to wake (DT2W) - how it works and why it did not

Based on driver/HAL disassembly of the stock vendor and device logs.

## Chain on the stock vendor (W1WEOS36.48-22-3-3-4-3)
1. `/sys/class/touchscreen/primary/gesture` = 49 (double tap on; 48 off, 33/32 single tap).
   Stock: TouchHwAidlService -> IMotTouch.setGesture(49). Ours: vegas-dt2w.sh at boot.
2. Screen off: driver loads the gesture firmware, `fts_gesture_type_store: set gesture type:2`
   (reg 0xCF: 1 single, 2 double, 3 both).
3. Double tap: `fts_gesture_readdata gesture_id=38 (0x26)` -> `Gesture Code=18` (double),
   DT has `focaltech,report_gesture_key` -> EV_KEY KEY_F4 (62) down/up on input device
   "double-tap" (event9, caps KEY_F1 KEY_F4), `input report: N` (running counter), 5 s wakeup source.
   (single tap: code 22 -> KEY_F1 59; without report_gesture_key: ABS_DISTANCE counter.)
4. **The vendor sensors sub-HAL `sensors.moto.so` (loaded by multihal, hals.conf) opens that input
   device and EVIOCGRABs it in the `DoubleTapSensor` constructor** (ioctl 0x40044590, arg 1).
   It exposes it as sensor `dt-gesture` (Focaltech, type `com.motorola.sensor.double_tap` 65566,
   handle 0x01000005, flags 0x7 = wake-up + SPECIAL_TRIGGER); activation writes
   `/sys/class/sensors/dt-gesture/enable` (init.mmi.overlay.rc chowns it root:input).

## Why it did nothing on the GSI
- Because of the grab, InputReader (and getevent) never see KEY_F4 -> `double-tap.kl` (62 WAKEUP)
  can never apply. That is why getevent showed nothing while the kernel logged "input report".
- The overlay pointed Doze at `com.motorola.sensor.tap` ("Mot Tap", handle 0x86, sensor hub, MTK
  sensors.mediatek.V2.0.so): a different, non-touch sensor. Wrong sensor.
- Even with the right sensor, SystemUI DozeSensors.TriggerSensor uses requestTriggerSensor(),
  which SystemSensorManager refuses for anything but REPORTING_MODE_ONE_SHOT
  ("AsyncSensorManager: Requesting ... failed").

## Fix (2026-11-21, build 19)
- overlay VegasFrameworkDefaults: config_dozeDoubleTapSensorType = com.motorola.sensor.double_tap.
- frameworks/base patch 0005 (SystemUI DozeSensors): non-one-shot wake-up sensors are registered
  with registerListener() and their events go through the same path as onTrigger (without dropping
  the registration). DozeTriggers then does onSlpiTap + gentleWakeUp (REASON_SENSOR_DOUBLE_TAP).
- vegas-dt2w.sh (gesture=49) stays: the driver only arms the double tap with it.
- double-tap.kl stays as a fallback for the case the sensor HAL is not running.

## Check on device
- `dumpsys sensorservice | grep -i -A3 "dt-gesture"` while dozing: an active connection from
  com.android.systemui on handle 0x01000005.
- `dumpsys activity service com.android.systemui/.SystemUIService` DozeSensors dump / DozeLog:
  "sensor registered: {Sensor name=\"dt-gesture\"...}" with registered=true.
- Kernel: `fts_gesture_report: input report: N`; logcat: `DozeLog`/`PowerManagerService Waking up
  from Dozing ... reason=WAKE_REASON_GESTURE` (gentle wake).

## Reliability (1/3 taps detected in one test)
- Detection is in the touch firmware (gesture-app fw loaded on suspend). Misses are logged by the
  kernel as nothing at all (no TOUCH_GESTURE irq), so nothing above the driver can help.
- The driver drops gestures when "wakeable" is not set ("Gesture got but wakeable not set. Skip this
  gesture."): watch for that line; activating dt-gesture is what stock does, so it should be set.
