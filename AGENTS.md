# Context for AI assistants

This repo is a guide plus source for building and installing a PixelOS 16 GSI on the Moto G Power 2026
(XT2617V, vegas26, MediaTek MT6835, stock vendor W1WEOS36.48-22-3-3-4-3). README.md is the guide.

## Safety rails (always)
- Ask the user before every flash, wipe, unlock or reboot into a flashing mode.
- Never flash or erase: preloader, lk, seccfg, gpt, efuse, md1img_b, nvram, nvdata, protect1, protect2,
  persist, prodpersist, proinfo, frp (the only exception is the documented frp byte in the unlock guide).
- Wipe only with Wipe data/factory reset in stock recovery. Never `fastboot -w`.
- Do not use `adb root` on this device: it drops USB.
- Make sure the user has a full partition backup before anything is modified.
- Never print, log, commit or upload serial numbers, unlock keys, IMEI, EID, ICCID, MAC addresses,
  partition dumps or raw logs. Redact them in anything shown or shared.
- Never commit proprietary blobs (APKs from stock firmware) or signing keys.

## Useful facts
- Active slot is usually `_a`. fastbootd is a separate USB device from the bootloader (driver bind twice).
- vbmeta can only be flashed from the bootloader, not from fastbootd.
- On the GSI, /product points to /system/product.
- Release builds: userdebug with VEGAS_DEBUG=0 and release keys (README Part 6).
