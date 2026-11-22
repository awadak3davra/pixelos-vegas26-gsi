# TrebleDroid patch rebase onto PixelOS 16.2 (sixteen-qpr2), 2026-11-20

Overrides committed in /src/pixelos trees on top of the already-applied TrebleDroid commits; each override passes `git apply --check -R` on its commit.

- trebledroid/fb/0012 HOME wake: rebased. KEYCODE_FOCUS is gone from isWakeKey(); KEYCODE_HOME added after KEYCODE_MENU.
- trebledroid/fb/0031 MTK power hints: rebased. Android.bp: no Samsung sysinput entry here (skipped Samsung patches), so only `vendor.mediatek.hardware.mtkpower-V1.1-java` is added (lib from vendor/interfaces, gen_java true). DisplayPolicy.java hunks unchanged.
- trebledroid/fb/0049 dynamic UDFPS try/catch: NOT PORTABLE. It wraps the AuthService.dynamicUdfpsProps() block in FingerprintProvider that skipped 0037 (FOD) adds; neither exists in the tree. No override written.
- staging/fb/0001 prefer HIDL over virtual AIDL FP: rebased. Hunk 1 unchanged. PixelOS registerFingerprintSensors() adds HIDL and AIDL sensors side by side (HIDL first, ctor arg `!(hidl present)`), so the port computes preferHidlSensor the same way and only skips addAidlSensors() when it is set; ctor arg left as is (already false when HIDL is present).
- staging/fb/0004 status bar / corner sysprops: rebased. Only PhoneStatusBarView.java import context differed (no android.view.Display import); code identical to upstream. Other 4 files unchanged.
- staging/device_phh_treble/0002 goodix guard: rebased, line offset only.
