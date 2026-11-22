#
# vegas26-specific additions to the PixelOS GSI
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/pixelos/vegas_gsi

# MediaTek IMS: com.mediatek.ims + com.mediatek.ims.overlay(.telephony).
# Without it MT6835 gets data and SMS but no VoLTE calls (see vegas26-gsi README Part 4).
$(call inherit-product, vendor/mediatek/ims/ims.mk)

# NFC: the vendor NXP HAL (vendor.nfc_hal_service) only starts once
# persist.vendor.nfc.config_file_name is set, which a Motorola component does on stock but
# nothing does on a GSI -> com.android.nfc ANR loop. nfc-hal-gsi.rc sets it when
# ro.vendor.hw.nfc=nq (verified on LOS 23.2: mState=on, HAL registered).
PRODUCT_PACKAGES += \
    nfc-hal-gsi.rc

# Wired Android Auto: AOA needs 18d1:2d0x after ACCESSORY_START. Stock sets it in Motorola's
# system_ext init.usb.rc, absent on a GSI; the gadget stayed 22b8:2e81 and cars reset the port.
PRODUCT_PACKAGES += \
    usb-aoa-gsi.rc

# eSIM: no LPA on a GSI (EuiccConnector UnavailableState). Stock EuiccGoogle + EuiccPartnerApp as
# product priv-apps, see esim/ (OpenEUICC cannot open ISD-R on this MEP-A1 eUICC).
PRODUCT_PACKAGES += \
    EuiccGoogle

# Radio: default to 5G/LTE (33 = NR/LTE/TDSCDMA/CDMA/EvDo/GSM/WCDMA) on both slots. Without it
# the framework falls back to 0 (WCDMA preferred), the SIM's allowed types are stored as 2G/3G on
# first boot and the phone never registers on US carriers (3G shut down).
PRODUCT_PRODUCT_PROPERTIES += \
    ro.telephony.default_network=33,33

# Display: centered hole-punch (1080x2388), aux rear camera in Aperture;
# battery percentage on by default; Wi-Fi calling + VoLTE available and on by default
PRODUCT_PACKAGES += \
    VegasCutout \
    VegasApertureAux \
    VegasFrameworkDefaults \
    VegasCarrierConfig

# SurfaceFlinger: keep HWC backpressure on (AOSP default). TrebleDroid turns it off for GSI
# compatibility; on the MT6835 HWC that makes SF compose ahead of an unfinished present, which
# showed up in a perfetto trace as "SurfaceFlinger Stuffing"/"Prediction Error" micro-stutter.
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.phh.enable_sf_hwc_backpressure=1

# SurfaceFlinger: no GL backpressure. With HWC backpressure on, GL backpressure (default true)
# makes SF skip a frame whenever any frame is pending (phh patch drops AOSP's narrower check),
# so Settings buffers stayed held (app stuck in dequeueBuffer). Stock leaves it off.
# predict_hwc_composition_strategy=0 as phh's MTK block and stock do.
# vndk.rc copies persist.sys.phh.enable_sf_gl_backpressure into debug.sf.*, so default both.
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.phh.enable_sf_gl_backpressure=0 \
    debug.sf.enable_gl_backpressure=0 \
    debug.sf.predict_hwc_composition_strategy=0 \
    persist.sys.vegas.sf_glbp_reset=0
PRODUCT_PACKAGES += \
    vegas-sf.rc

# privapp allowlist gaps (user builds enforce the allowlist), see privapp/
PRODUCT_PACKAGES += \
    privapp-permissions-vegas-extra.xml

# Stop the wireless-charging HAL (no WLC on this model, it polls forever) and phh's OPPO/OnePlus
# fingerprint compat HALs, see cleanup/
PRODUCT_PACKAGES += \
    vegas-cleanup.rc

# Double tap to wake (FocalTech gesture node + KEY_F4 -> WAKEUP keylayout), see dt2w/
PRODUCT_PACKAGES += \
    vegas-dt2w.sh \
    vegas-double-tap.kl

# Chop chop -> flashlight (vendor ChopChop wake-up sensor; Moto Actions is not in the GSI), see actions/
PRODUCT_PACKAGES += \
    VegasActions

# Camera: expose every camera id the MTK HAL has (rear aux/ultrawide OV08D is hidden otherwise;
# TrebleDroid's toggle, also in Phh Treble Settings)
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.phh.include_all_cameras=true

# Camera: the MTK sensor HAL (vendor libcam.halsensor.so, HalSensorList::isGsiMode) reads
# ro.product.manufacturer; unless it is "motorola" or "lenovo" it treats the system as a GSI and
# searchSensors() stops after sensor index 1, so the ultrawide (OV08D, index 2) is never probed
# and only main + front reach cameraserver. ro.product.manufacturer is otherwise derived from
# ro.product.product.manufacturer (google). Set the base prop to the real maker; the per-partition
# ro.product.{system,product,system_ext}.manufacturer stay google and PixelPropsUtils still
# spoofs Google apps at the Java level.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.product.manufacturer=motorola

# Remote key provisioning: the Trustonic KeyMint has no factory attestation keybox
# (persist has no attest_keybox.so, even in the pre-unlock backup); stock gets attestation keys
# from Google RKP (ro.rkp.csr_uploaded=1). rkpd stays disabled without this hostname, so every
# attested key generation failed. With it the chain goes TEE -> Google "Droid CA" roots.
PRODUCT_SYSTEM_PROPERTIES += \
    remote_provisioning.hostname=remoteprovisioning.googleapis.com

# Camera: GCam (MGC 9.7.047, OV50D low-noise config) installed once after first boot as a
# regular app, so it can be uninstalled if another camera app is preferred (preinstall/).
# Off by default: the image ships Aperture only, GCam is installed separately with
# scripts/install-gcam.sh. Build with VEGAS_GCAM=1 to bundle it again (+458 MB).
ifeq ($(VEGAS_GCAM),1)
PRODUCT_PACKAGES += \
    vegas-preinstall.sh \
    vegas-preinstall-gcam \
    vegas-preinstall-gcam-config
endif
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/pixelos/vegas_gsi/sepolicy

# Boot animation matching the 1080x2388 panel (PixelOS picks it by screen width)
TARGET_SCREEN_WIDTH := 1080
TARGET_SCREEN_HEIGHT := 2388

# Bring-up debugging (VEGAS_DEBUG=1, default for userdebug builds via build.sh):
# adb on from the first boot with no RSA prompt, so a device stuck in boot or setup
# can still be inspected; logcat and kernel log persisted to /data/misc/logd.
# Note: `adb root` drops USB on this device (vegas26-gsi README); use `su` instead.
ifeq ($(VEGAS_DEBUG),1)
# (ro.adb.secure=0 itself comes from vendor/lineage via WITH_ADB_INSECURE, exported by build.sh)
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.usb.config=adb \
    persist.logd.logpersistd=logcatd \
    persist.logd.logpersistd.buffer=all \
    persist.logd.size=16M \
    ro.logd.size=16M \
    ro.logd.kernel=true
# A privileged app missing from the privapp allowlist makes system_server abort at boot under
# "enforce" (vendor/lineage default, made optional by patches/vegas/platform_vendor_lineage);
# bring-up builds only log the violation so it can be fixed from logcat.
PRODUCT_PRODUCT_PROPERTIES += \
    ro.control_privapp_permissions=log
PRODUCT_PACKAGES += \
    logpersist.start
endif

# Density stays on the vendor value (ro.sf.lcd_density from /vendor wins over /system);
# adjust in Settings > Display size if needed (README Part 5.3).
