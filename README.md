# Moto G Power 2026 (XT2617V / vegas26): PixelOS 16 GSI with VoLTE, eSIM, Android Auto and all cameras

A reproducible guide and the full source to build and install **PixelOS 16.2 (Android 16 QPR2)** as a
GSI on the **Moto G Power 2026 (XT2617V, MediaTek MT6835)**, with the device-specific fixes a plain GSI
lacks: VoLTE, eSIM, wired Android Auto, the ultrawide camera, double tap to wake, NFC, hardware key
attestation and a smoother UI.

This repo contains instructions and source only. No firmware, no prebuilt images, no proprietary
blobs. A prebuilt image will be published separately.

Verified on a real device, 2026-11.

---

## Table of contents

- [What you get](#what-you-get)
- [Tested device / compatibility](#tested-device--compatibility)
- [Warnings](#warnings)
- [Using an AI assistant](#using-an-ai-assistant)
- [Before you start](#before-you-start)
- [Prerequisites](#prerequisites)
- [How the pieces fit (the layer model)](#how-the-pieces-fit-the-layer-model)
- [Part 1: Bootloader unlock](#part-1-bootloader-unlock)
- [Part 2: Install the PixelOS GSI](#part-2-install-the-pixelos-gsi)
- [Part 3: SIM / network unlock (modem)](#part-3-sim--network-unlock-modem)
- [Part 4: Cellular, VoLTE and eSIM](#part-4-cellular-volte-and-esim)
- [Part 5: What this build fixes, and how](#part-5-what-this-build-fixes-and-how)
- [Part 6: Build it yourself](#part-6-build-it-yourself)
- [Troubleshooting](#troubleshooting)
- [Known issues](#known-issues)
- [How updates work](#how-updates-work)
- [Repo contents](#repo-contents)
- [Credits and prior work](#credits-and-prior-work)
- [Quick reference](#quick-reference)

---

## What you get

- PixelOS 16.2 (`sixteen-qpr2`, Android 16 QPR2) with Google apps, as an arm64 A/B system image on the
  stock Motorola vendor.
- Calls, SMS, mobile data and **VoLTE** through the MediaTek IMS stack.
- **eSIM**: add a profile by QR code or activation code from Settings (stock Google eSIM manager).
- **Wired and wireless Android Auto** (wired needed a USB fix, see Part 5).
- **All cameras**, including the ultrawide, in the stock Camera app.
- **Double tap to wake** and Motorola's **chop-chop flashlight** gesture.
- NFC, fingerprint, GPS, Wi-Fi, Bluetooth, auto-brightness with the stock Motorola curve.
- **Widevine L1**, Play Store and Google services. Play Integrity: BASIC (see Part 5).
- Smoother UI: SurfaceFlinger moved off the little cores, GPU backpressure tuned.

## Tested device / compatibility

| Item | Value |
|---|---|
| Model / SKU | moto g power - 2026 / XT2617V (`vegas26`, bootloader `vegas`) |
| Carrier variant | Straight Talk / Tracfone (`ro.carrier=tracfone`) |
| Stock build (vendor) | W1WEOS36.48-22-3-3-4-3 (Android 16) |
| SoC | MediaTek MT6835 (Dimensity 6300), Mali-G57 |
| Kernel | `5.15.189-android13-8-...` |
| Display | 1080x2388, 120 Hz |

The image runs on top of the stock vendor. If your vendor build differs, re-verify everything.

## Warnings

**Safety and legal notice:** use this guide only on devices you own or are explicitly authorized to
service. Nothing here modifies the IMEI.

Bootloader and modem modification can brick a device with no guaranteed recovery. Unlocking and
installing wipe userdata. Never flash or erase: `preloader`, `lk`, `seccfg`, `gpt`, `efuse`,
`md1img_b`, `nvram`, `nvdata`, `protect1`, `protect2`, `persist`, `prodpersist`, `proinfo`, `frp`
(except the documented `frp` byte in Part 1). Losing `nvram`/`nvdata`/`persist` loses the IMEI,
Wi-Fi/Bluetooth MACs and calibration.

Never publish your serial number, unlock keys, IMEI, EID, ICCID, MAC addresses, partition dumps or raw
logs (logcat and dumpsys contain most of these). Placeholders like `<YOUR SERIAL>` must stay redacted
in anything you share.

## Using an AI assistant

You can have an AI coding assistant (Claude Code, Codex, OpenCode and similar) walk you through the
guide and run the adb/fastboot commands. Open it inside this repo so it reads `AGENTS.md`:

```
git clone <this repo>
cd pixelos-vegas26-gsi
claude        # or: codex / opencode
```

First message (fill in the brackets):

```
This is my own Moto G Power 2026 (XT2617V, vegas26). I want to follow README.md in this repo
(safety rules are in AGENTS.md). My setup: [Windows/Linux], phone currently on [stock / unlocked /
another GSI], SIM [carrier / eSIM]. I want to do [install the PixelOS image / build it myself].
Explain each step, run adb/fastboot for me where you can, and ask me before every flash or wipe.
```

## Before you start

- **Skill level:** intermediate: terminal, `adb`, `fastboot`. Building (Part 6) is advanced.
- **Time:** an afternoon for unlock and install. A first build takes several hours.
- **You need:** the phone, a PC (Windows or Linux), a good USB data cable directly into the PC.
- **Back up first.** The partition backup in Part 1 is your only way back.

## Prerequisites

Tools:

- **Android platform-tools** (adb/fastboot): https://developer.android.com/tools/releases/platform-tools
- **Google USB Driver** (Windows; the bootloader and fastbootd each need it bound):
  https://developer.android.com/studio/run/win-usb
- **xz** to unpack the image (7-Zip on Windows).
- For building: Linux (Ubuntu 24.04, also inside WSL2), see Part 6.

Guides and projects this builds on:

- **Bootloader unlock, SIM unlock, LineageOS GSI on this phone:**
  [qfertig/vegas26-gsi](https://github.com/qfertig/vegas26-gsi) (Parts 1 and 3 here follow it)
- **Base bootloader guide:**
  [parsimo2010/moto-g-power-2026-straight-talk-wifi-root-guide](https://github.com/parsimo2010/moto-g-power-2026-straight-talk-wifi-root-guide)
- **LK patcher:** https://github.com/Maikyxd/val-protocol
- **Modem SIM-unlock tool:** https://github.com/andrewwm/vegas-freedom
- **PixelOS:** https://github.com/PixelOS-AOSP (manifest branch `sixteen-qpr2`)
- **TrebleDroid (phh) GSI base:** https://github.com/TrebleDroid
- **TrebleDroid patch set used:** https://github.com/MisterZtr/LineageOS_gsi
- **MediaTek IMS for GSIs:** https://github.com/techyminati/android_vendor_mediatek_ims
- **Stock firmware mirror:** https://mirrors.lolinet.com/firmware/moto/
- **Android 16 GSI release notes** (wipe requirement): https://developer.android.com/about/versions/16/gsi-release-notes
- **GCam (optional, not bundled):** any GCam port for MediaTek, installed as a normal app.

## How the pieces fit (the layer model)

- **`system`** = the PixelOS GSI. Replaced as a whole on every update. All fixes in this repo live here.
- **`vendor`, `product`, `odm`** = stock Motorola partitions. Never touched by this guide.
- **`userdata` (`/data`)** = apps and settings. Survives a system update signed with the same keys.
- **`md1img`** = the modem. A SIM unlock lives here and survives OS flashing.

---

## Part 1: Bootloader unlock

Follow **Part 1 of [qfertig/vegas26-gsi](https://github.com/qfertig/vegas26-gsi#part-1-bootloader-unlock)**:
temporary root, full partition backup, patched LK, and the carrier OEM-unlock wall (`frp` last byte).
It is device-specific (your serial, your keys, your LK) and is not repeated here.

Before going on, confirm:

```
fastboot getvar securestate     # flashing_unlocked
adb shell getprop ro.boot.slot_suffix     # note the active slot, usually _a
```

Keep the backup private. It contains device-unique data.

---

## Part 2: Install the PixelOS GSI

The image is an arm64 A/B ext4 system image: `PixelOS-16.2-vegas26-gsi-arm64-ab-<variant>-<date>.img.xz`.
Check its SHA-256 against the published value before flashing.

### 2.1 How you wipe decides whether it survives a reboot

`/data` uses metadata encryption with hardware-wrapped keys. `fastboot -w` erases but does not format
`/data` and `/metadata`, so a GSI boots once and then shows "Can't load Android system" on every
reboot. Always wipe with **Wipe data/factory reset in stock recovery**. Never `fastboot -w`.

Recovery menu: on the "No command" screen, **hold Power and tap Volume Up once**.

### 2.2 Flash

```
xz -d PixelOS-16.2-vegas26-gsi-arm64-ab-<variant>-<date>.img.xz
adb reboot bootloader
# verified boot off, FROM THE BOOTLOADER (fastbootd cannot see vbmeta on this device);
# use the stock vbmeta images from your backup or the stock firmware:
fastboot --disable-verity --disable-verification flash vbmeta        vbmeta_a.img
fastboot --disable-verity --disable-verification flash vbmeta_system vbmeta_system_a.img
fastboot reboot fastboot                 # fastbootd is a separate USB device: bind the driver again
fastboot flash system PixelOS-16.2-vegas26-gsi-arm64-ab-<variant>-<date>.img
fastboot reboot recovery
# stock recovery: Wipe data/factory reset, then Reboot system now
```

If `flash system` reports "not enough space": in fastbootd run
`fastboot delete-logical-partition product_a` (and `product_b` if it exists), then flash again. On this
GSI `/product` points to `/system/product`, so the stock `product` partition is not used; flashing the
stock firmware brings it back.

The "bootloader is unlocked" warning shown at every boot comes from the bootloader itself. It cannot be
removed without modifying `lk`, which this guide never does. It does not affect anything; the phone
continues after a few seconds.

First boot takes several minutes.

### 2.3 After first boot

- Settings > Network > SIMs: pick the SIM for calls, SMS and data.
- To use adb: Settings > About phone, tap Build number 7 times, then System > Developer options >
  USB debugging, and authorize the computer on the phone.

### 2.4 Back to stock

Flash the stock `system` (and stock `vbmeta`/`vbmeta_system` without the disable flags) from your
backup or the stock firmware, then factory reset in recovery.

---

## Part 3: SIM / network unlock (modem)

A carrier-locked unit shows `NETWORK_LOCKED`. Follow **Part 3 of
[qfertig/vegas26-gsi](https://github.com/qfertig/vegas26-gsi#part-3-sim--network-unlock-modem)**
(vegas-freedom, flash `md1img_a` only, never `md1img_b`). It is independent of the OS and survives
GSI updates.

---

## Part 4: Cellular, VoLTE and eSIM

### 4.1 Mobile data (APN)

PixelOS ships the AOSP/carrier APN list; most SIMs get the right APN automatically. For US Mobile
Dark Star (AT&T) the APN is `ereseller`. If data does not come up: Settings > Network > SIMs > the SIM >
Access Point Names, select the carrier's APN, toggle airplane mode once.

### 4.2 VoLTE

The build includes `com.mediatek.ims` (MediaTek IMS service plus its overlays), so VoLTE works without
extra steps. Check with:

```
adb shell pm list packages | grep mediatek.ims
adb logcat -b radio | grep -i "setImsRegistrationState"     # registered=true
```

### 4.3 eSIM

Settings > Network > SIMs > Add eSIM shows the QR scanner and manual code entry. The eSIM chip is on
SIM slot 2 and runs in MEP mode (multiple enabled profiles, MEP-A1). Profiles from carriers that support
eSIM download and activate normally (tested with US Mobile). A new line can take a while to be
activated on the carrier side: calls answered with "busy" and data without internet right after the
download usually mean the line is not active yet.

---

## Part 5: What this build fixes, and how

Everything below is in the source of this repo. Each item names the symptom on a plain GSI, the cause
and the fix.

### 5.1 Ultrawide camera
- **Symptom:** only main and front cameras. **Cause:** the vendor sensor HAL
  (`libcam.halsensor.so`, `HalSensorList::isGsiMode()`) probes every sensor only when
  `ro.product.manufacturer` is `motorola` or `lenovo`. **Fix:** `ro.product.manufacturer=motorola`, plus
  an Aperture overlay that exposes aux cameras. Apps and EXIF see Motorola as the maker.
- The phone has two rear cameras (main 50 MP and ultrawide 8 MP) and a front camera; the third circle on
  the back is the flash and a flicker sensor.

### 5.2 Wired Android Auto
- **Symptom:** wireless Android Auto works, wired fails with "Android Auto cannot start due to an
  error", while other phones work on the same cable. **Cause:** after the car sends `ACCESSORY_START`,
  an Android Open Accessory device must re-enumerate as Google `18d1:2d00` (or `2d01` with adb). Stock
  sets that in Motorola's `/system_ext/etc/init/hw/init.usb.rc`, which a GSI does not have, so the phone
  stayed `22b8:2e81`; the car never found the accessory and reset the port.
  **Fix:** `usb/usb-aoa-gsi.rc` writes the AOA VID/PID when the MediaTek gadget HAL selects accessory or
  audio_source functions. Verified with a PC acting as the head unit (AOA handshake, re-enumeration as
  `18d1:2d01`).

### 5.3 eSIM
- **Symptom:** "Add eSIM" does nothing; `EuiccConnector` stays in `UnavailableState`. **Cause:** a GSI
  ships no eSIM manager (LPA). An open-source LPA (OpenEUICC) was tried first: on this MEP-A1 eUICC the
  modem refuses its ISD-R channel (`MISSING_RESOURCE`, SW `6A81`), because the platform path sends ISD-R
  commands as ES10 commands and a third-party LPA does not. **Fix:** the stock Google eSIM manager
  (`EuiccGoogle`) and Motorola's `EuiccPartnerApp` as product priv-apps, their permission files, and
  `non_removable_euicc_slots=[1]`. These APKs are proprietary and not in this repo; Part 6 shows how to
  take them from your own stock firmware.

### 5.4 Double tap to wake
- Three parts are needed (details in `dt2w/NOTES.md`): arm the touch gesture at boot
  (`/sys/class/touchscreen/primary/gesture` = `49`), point SystemUI Doze at the vendor wake-up sensor
  `com.motorola.sensor.double_tap`, and patch SystemUI `DozeSensors` to register non-one-shot wake-up
  sensors. The Phh Treble Settings toggle defaults to on.

### 5.5 Chop-chop flashlight
- The vendor exposes Motorola's chop gesture as the wake-up sensor `com.motorola.sensor.chopchop`.
  `actions/` (VegasActions) is a small system app that listens to it and toggles the torch.

### 5.6 NFC
- **Symptom:** NFC never turns on, `com.android.nfc` ANRs. **Cause:** the vendor NXP HAL starts only
  when `persist.vendor.nfc.config_file_name` is set, which a Motorola component does on stock.
  **Fix:** `nfc/nfc-hal-gsi.rc`.

### 5.7 Hardware key attestation (RKP) and Play Integrity
- The Trustonic KeyMint has no factory attestation keybox; stock uses Google Remote Key Provisioning.
  The build sets `remote_provisioning.hostname=remoteprovisioning.googleapis.com`, so attested key
  generation works and the chain ends at Google's roots.
- Play Integrity: BASIC. The TEE reports the bootloader as unlocked, so DEVICE cannot pass without
  faking hardware attestation, which this build does not do. PixelOS's property spoofing for Google Play
  services is kept (with a crash fix for its first run); it is not applied to the Play Store, because
  spoofing the Play Store breaks its update list ("Something went wrong").

### 5.8 Widevine
- L1 works. The `keybox has bad magic` log line is harmless.

### 5.9 UI smoothness
- AOSP `task_profiles.json` puts SurfaceFlinger's main thread and RenderEngine in the
  `system-background` cpuset, which on MT6835 is the six little cores. The build moves both to
  `foreground` (all cores). In a perfetto trace this halved janky SurfaceFlinger frames (44% to 25%) and
  removed most prediction errors.
- HWC backpressure stays on (AOSP default; TrebleDroid turns it off), GL backpressure is off as on
  stock, `debug.sf.predict_hwc_composition_strategy=0`.

### 5.10 Smaller items
- Auto-brightness uses the stock Motorola curve from the vendor overlay. If it seems frozen, check that
  "adaptive brightness one shot" (`auto_brightness_one_shot`) is off.
- Centered hole-punch cutout, battery percentage, carrier config for Wi-Fi calling and VoLTE defaults.
- NFC, RKP, SurfaceFlinger and double tap to wake findings were also proposed (pull request) to
  [qfertig/vegas26-gsi](https://github.com/qfertig/vegas26-gsi) for LineageOS users.

---

## Part 6: Build it yourself

### 6.1 Host

- Linux x86_64, Ubuntu 24.04 (WSL2 works). At least 32 GB RAM plus 32 GB swap (soong runs out of memory
  without swap), about 400 GB free disk on a non-compressed filesystem, many CPU cores.
- Packages: the usual AOSP build dependencies, `repo`, `git-lfs`, `openjdk-17-jdk-headless` (Treble
  app), `ccache` (optional).

### 6.2 Source

```
mkdir -p /src/pixelos && cd /src/pixelos
repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b sixteen-qpr2 --git-lfs --depth=1
mkdir -p .repo/local_manifests
cp <this repo>/manifest/vegas_gsi.xml .repo/local_manifests/
repo sync -c -j8 --no-tags --no-clone-bundle
```

The local manifest adds TrebleDroid (device_phh_treble, treble_app, vendor_hardware_overlay,
vendor_interfaces), the extra VNDK snapshots, MediaTek IMS and the pinned TrebleDroid patch set.

### 6.3 Proprietary blobs for eSIM (from your own stock firmware)

`esim/Android.bp` expects `esim/EuiccGoogle.apk` and `esim/EuiccPartnerApp.apk`. Take them from your
phone's stock `product` partition, from the same stock build as your vendor:

- On stock, before installing the GSI: `adb pull /product/priv-app/EuiccGoogle/EuiccGoogle.apk` and
  `adb pull /product/priv-app/EuiccPartnerApp/EuiccPartnerApp.apk`.
- Or from the stock firmware package: unpack `super` with `lpunpack`, extract `product_a.img` (EROFS)
  with `fsck.erofs --extract`, and copy the two APKs from `priv-app/`.

Do not commit them. `esim/.gitignore` ignores `*.apk`. Without them, remove `EuiccGoogle` from
`vegas.mk` and the build has no eSIM manager.

### 6.4 Build

```
bash <this repo>/scripts/build.sh userdebug             # first time: patches the tree, builds Treble app
bash <this repo>/scripts/build.sh userdebug --repatch   # start patches over
```

`build.sh` copies this repo to `device/pixelos/vegas_gsi`, applies the TrebleDroid patches and
`patches/vegas/`, builds the Treble app from `treble_app`, runs `lunch custom_vegas_gsi-bp4a-<variant>`
and `m systemimage`, then writes `PixelOS-16.2-vegas26-gsi-arm64-ab-<variant>-<date>.img.xz` and its
`.sha256` to `VEGAS_OUTDIR`.

- `VEGAS_DEBUG=1` (default for userdebug): bring-up build. adb on from first boot without
  authorization, persistent logcat, privapp violations only logged. For testing only.
- `VEGAS_DEBUG=0`: release settings. adb needs authorization, `ro.debuggable=0`, privapp allowlist
  enforced, release keys (6.5).
- `VEGAS_GCAM=1` bundles a GCam APK you place in `preinstall/` yourself (off by default).
- A `user` build is not possible with the TrebleDroid sepolicy (it has permissive domains, which user
  builds reject); release builds are `userdebug` with `VEGAS_DEBUG=0`, like official LineageOS builds.

### 6.5 Release keys

Generate your own keys once (keep them private and backed up; losing them means the next build cannot
be installed over the old one without a wipe):

```
cd /src/pixelos
mkdir -p vendor/lineage-priv/keys && cd vendor/lineage-priv/keys
for k in releasekey platform shared media networkstack nfc bluetooth sdk_sandbox testkey; do
  /src/pixelos/development/tools/make_key $k '/C=US/O=<your project>/CN=<your project>'
done
```

`vendor/lineage-priv/keys/keys.mk` (included by `vendor/lineage/config/common.mk`):

```
ifneq ($(VEGAS_DEBUG),1)
PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/lineage-priv/keys/releasekey
# the Bluetooth app inside com.android.bt is signed with this bluetooth key; without the next line
# its SELinux seinfo keeps the AOSP test certificate and Bluetooth crashes at start
PRODUCT_MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES := vendor/lineage-priv/keys
endif
```

`patches/vegas/platform_build/0004` removes the GSI board's hard-coded `ro.adb.secure=0`, so release
builds keep adb authorization.

### 6.6 Checks before publishing an image

- `ro.build.tags=release-keys`, `ro.debuggable=0`, `ro.adb.secure=1` in `/system/build.prop`.
- Every priv-app's privileged permissions are allowlisted (release builds enforce the allowlist and
  system_server aborts on a gap).
- No personal data in the image or the repo (paths, names, serials, addresses).
- Clean install on a phone through recovery factory reset; check calls, data, eSIM, Bluetooth, Wi-Fi,
  cameras, Android Auto.

### 6.7 Device diagnostics

`scripts/device-diag.sh`, `scripts/collect-errors.sh` and `scripts/device-functest.sh` collect logs
and run checks over adb; `scripts/settings-trace-auto.sh` records a perfetto trace while it opens and
closes Settings pages. Their output contains device identifiers: keep it private.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `fastboot devices` empty or `< waiting for any device >` | Driver not bound for this mode | Bind "Android Bootloader Interface"; the bootloader and fastbootd are separate devices. |
| Boots once, then "Can't load Android system" | `fastboot -w` does not format `/data` | Factory reset in stock recovery (2.1). |
| Can't find Wipe data in recovery | Menu hidden behind "No command" | Hold Power, tap Volume Up once. |
| `flash system`: not enough space | Super partition full | `fastboot delete-logical-partition product_a` (and `_b`), flash again. |
| Calls answered "busy", data has no internet, right after adding a line | Line not active yet at the carrier | Wait for activation; check the carrier's app. |
| Wired Android Auto fails, wireless works | Plain GSI keeps the Motorola USB ID in accessory mode | Fixed in this build (5.2). |
| Add eSIM does nothing | No eSIM manager in a GSI | Fixed in this build (5.3); needs the stock blobs when building. |
| Play Store: Updates "Something went wrong" | Play Store saw spoofed Pixel properties | Fixed in this build (5.7). |
| Bluetooth keeps stopping (own release build) | Bluetooth seinfo still on the AOSP test certificate | `PRODUCT_MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES` (6.5). |
| Only two cameras | `ro.product.manufacturer` not `motorola` | Set in this build (5.1). |
| Double tap to wake off after a clean install | Treble app toggle | On by default in this build; toggle in Phh Treble Settings > Misc. |
| `adb root` makes the phone vanish from USB | adbd restart drops the USB gadget | Don't use `adb root`. |

## Known issues

- First GPS fix can be slow.
- Settings page transitions are less smooth than the rest of the UI (GPU composition on window
  transitions).
- logd buffers stay at the default size at boot; boot logs are short.
- Apps and EXIF report Motorola as the maker (required for the ultrawide camera).
- GCam is not bundled.

## How updates work

GSIs have no OTA. To update, flash the new image in fastbootd (`fastboot flash system <image>`) and
reboot. Data, apps and settings stay as long as the new image is signed with the same keys as the
installed one. Moving between differently signed builds (for example from a test build to a release
build) needs a factory reset in recovery.

## Repo contents

- `README.md`: this guide. `AGENTS.md`: context and safety rules for AI assistants.
- `manifest/vegas_gsi.xml`: local manifest for a PixelOS `sixteen-qpr2` tree.
- `AndroidProducts.mk`, `custom_vegas_gsi.mk`, `vegas.mk`: the product.
- `patches/`: TrebleDroid overrides rebased onto PixelOS (`override/`), patches not applied with reasons
  (`skip.txt`), and the vegas26 patches (`vegas/`: SurfaceFlinger cpuset, AttestationService fix,
  Play Integrity property spoofing, SystemUI DozeSensors, Treble app DT2W default, GSI adb prop, and
  others).
- `overlay/`: framework defaults (DT2W sensor, battery percentage), centered cutout, Aperture aux
  camera, carrier config.
- `usb/`: AOA USB IDs for wired Android Auto. `esim/`: eSIM manager module (blobs not included).
- `dt2w/`, `actions/`, `nfc/`, `sf/`, `privapp/`, `sepolicy/`, `preinstall/`: the other fixes.
- `brightness/NOTES.md`, `dt2w/NOTES.md`, `actions/NOTES.md`: how those were worked out.
- `scripts/`: build, patching and on-device diagnostics.

## Credits and prior work

- [qfertig/vegas26-gsi](https://github.com/qfertig/vegas26-gsi): unlock, SIM unlock and LineageOS GSI
  guide for this phone.
- [parsimo2010](https://github.com/parsimo2010/moto-g-power-2026-straight-talk-wifi-root-guide),
  [Maikyxd/val-protocol](https://github.com/Maikyxd/val-protocol),
  [andrewwm/vegas-freedom](https://github.com/andrewwm/vegas-freedom).
- [PixelOS](https://github.com/PixelOS-AOSP), [TrebleDroid / phhusson](https://github.com/TrebleDroid),
  [MisterZtr/LineageOS_gsi](https://github.com/MisterZtr/LineageOS_gsi),
  [techyminati MediaTek IMS](https://github.com/techyminati/android_vendor_mediatek_ims),
  [AndyCGYan](https://github.com/AndyCGYan), the AOSP and LineageOS projects.
- Firmware mirror: [lolinet](https://mirrors.lolinet.com/firmware/moto/).

## Quick reference

- Install: vbmeta with verification off from the bootloader, `flash system` in fastbootd, factory reset
  in stock recovery, never `fastboot -w`.
- Ultrawide needs `ro.product.manufacturer=motorola`.
- Wired Android Auto needs AOA `18d1:2d0x` (`usb/usb-aoa-gsi.rc`).
- eSIM on this MEP-A1 chip needs the stock Google eSIM manager, not a third-party LPA.
- Release keys: also set `PRODUCT_MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES`.
- Play Integrity: BASIC with an unlocked bootloader.
