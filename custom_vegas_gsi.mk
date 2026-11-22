#
# PixelOS GSI for Moto G Power 2026 (XT2617V, vegas26, MediaTek MT6835)
#
# A system-only arm64 A/B image (ext4) on top of TrebleDroid, plus the vegas26 bits:
# MediaTek IMS for VoLTE, the hole-punch cutout and Aperture aux-camera overlays.
#
# SPDX-License-Identifier: Apache-2.0
#

# Generic arm64 system (same base as TrebleDroid treble_arm64_bvN)
include build/make/target/product/aosp_arm64.mk
$(call inherit-product, device/phh/treble/base.mk)

# PixelOS
# EPPE (every PRODUCT_PACKAGES entry must exist) off: TrebleDroid's base.mk / overlay.mk list
# optional modules that no upstream tree provides (HardwareOverlayPicker, QtiAudio) and
# Qualcomm-only ones (QcRilAm, vendor.qti.*-java) that are useless on MT6835. Lineage-based
# TrebleDroid builds drop them silently the same way.
TARGET_DISABLE_EPPE := true
# PixelOS writes ro.custom.device twice: from CUSTOM_BUILD (lunch name, "vegas_gsi") in
# vendor/custom/config/version.mk and from the device name in Soong's gen_build_prop.
# On a real device they match; on a GSI the device is tdgsi_arm64_ab, so align them.
CUSTOM_BUILD := tdgsi_arm64_ab
$(call inherit-product, vendor/custom/config/common_full_phone.mk)

# vegas26 additions
$(call inherit-product, device/pixelos/vegas_gsi/vegas.mk)

PRODUCT_NAME := custom_vegas_gsi
PRODUCT_DEVICE := tdgsi_arm64_ab
PRODUCT_BRAND := google
PRODUCT_SYSTEM_BRAND := google
PRODUCT_MANUFACTURER := google
PRODUCT_MODEL := PixelOS GSI (vegas26)

# Overwrite the inherited "emulator" characteristics
PRODUCT_CHARACTERISTICS := device
