# vegas26 chop chop flashlight (Moto Actions replacement)

## Findings (2026-11-21)
- Sensor: `ChopChop`, handle 0x63, `com.motorola.sensor.chopchop` (65546), flags 0x7
  (wake-up + special trigger), vendor Motorola. Handle range 0x0..0xff = MediaTek sensor hub
  (sensors.mediatek.V2.0.so / SCP), not sensors.moto.so (0x01000000+ handles, dt-gesture).
- **The gesture already works on the GSI with no extra enabling step.** During the first test
  (TapTest listener, 13:26), `dumpsys sensorservice` "ChopChop: last 10 events" recorded 4 events,
  values[0] = 1.00 each (one per detected gesture), 13:26:55-13:27:02.
- Why TapTest logged nothing: it was started while the screen was off (`isSleeping=true`,
  `isVisible=false`), so its uid was background and sensorservice showed
  `org.vegas26.drminfo.TapTest | ... | has sensor access: false`: SensorService drops events for
  idle uids. The dt-gesture test worked because that listener is SystemUI (persistent).
- So no vendor prop, sysfs node, companion sensor or Moto HAL call is needed: activating the
  sensor (batch + activate through the multihal) is what arms it on the SCP.

## Implementation
- `VegasActions` (system_ext priv-app, platform cert, sharedUserId android.uid.system,
  persistent + directBootAware, no components). Application.onCreate finds the sensor by string
  type, registers a listener, and on each event (1 s debounce) toggles the back flash torch via
  CameraManager.setTorchMode, tracking state with a TorchCallback (so the QS tile stays in sync),
  plus an EFFECT_CLICK haptic (USAGE_HARDWARE_FEEDBACK) and a 2 s partial wakelock.
- Setting: `settings put secure vegas_chop_torch 0|1` (unset = on), observed live.
- System uid: avoids the Secure-settings readable-key restriction and background sensor-access
  rules; no privileged permissions requested, so no privapp allowlist entry is needed.
- cameraserver setTorchMode has no permission check (CameraService.cpp), so no CAMERA grant.

## Check on device
- `ps -A | grep vegas.actions` (uid system); `logcat -s VegasActions`: "chop chop listener
  registered=true (ChopChop)", per gesture "chop event value=1.0" + "torch on/off (camera 0)".
- `dumpsys sensorservice | grep -A2 "ChopChop 0x"`: connection from org.pixelos.vegas.actions with
  `has sensor access: true`.
