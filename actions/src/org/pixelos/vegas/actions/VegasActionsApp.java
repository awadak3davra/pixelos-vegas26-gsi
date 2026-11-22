/*
 * vegas26: Motorola "chop chop" flashlight without Moto Actions.
 *
 * The MediaTek sensor hub exposes the gesture as the wake-up sensor "ChopChop"
 * (com.motorola.sensor.chopchop, special trigger). Activating it is all the vendor needs; each
 * detected chop-chop gesture arrives as one event (values[0] = 1). This persistent system app
 * keeps a listener on it and toggles the back flash torch with a short haptic click.
 *
 * Setting: Settings.Secure "vegas_chop_torch" (unset or 1 = on, 0 = off), e.g.
 *   adb shell settings put secure vegas_chop_torch 0
 *
 * SPDX-License-Identifier: Apache-2.0
 */
package org.pixelos.vegas.actions;

import android.app.Application;
import android.database.ContentObserver;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.os.SystemClock;
import android.os.VibrationAttributes;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.provider.Settings;
import android.util.Log;

public class VegasActionsApp extends Application implements SensorEventListener {
    private static final String TAG = "VegasActions";
    private static final String SETTING = "vegas_chop_torch";
    private static final String CHOP_TYPE = "com.motorola.sensor.chopchop";
    /** One gesture can be reported more than once; ignore repeats within this window. */
    private static final long DEBOUNCE_MS = 1000;

    private Handler mHandler;
    private SensorManager mSensorManager;
    private Sensor mChop;
    private boolean mListening;
    private CameraManager mCameraManager;
    private String mTorchId;
    private boolean mTorchOn;
    private long mLastToggle;
    private PowerManager.WakeLock mWakeLock;
    private Vibrator mVibrator;

    private final CameraManager.TorchCallback mTorchCallback = new CameraManager.TorchCallback() {
        @Override
        public void onTorchModeChanged(String cameraId, boolean enabled) {
            if (cameraId.equals(mTorchId)) mTorchOn = enabled;
        }

        @Override
        public void onTorchModeUnavailable(String cameraId) {
            if (cameraId.equals(mTorchId)) mTorchOn = false;
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        mHandler = new Handler(Looper.getMainLooper());
        mSensorManager = getSystemService(SensorManager.class);
        for (Sensor s : mSensorManager.getSensorList(Sensor.TYPE_ALL)) {
            if (CHOP_TYPE.equals(s.getStringType())) {
                mChop = s;
                break;
            }
        }
        if (mChop == null) {
            Log.w(TAG, "no " + CHOP_TYPE + " sensor, nothing to do");
            return;
        }
        mCameraManager = getSystemService(CameraManager.class);
        mCameraManager.registerTorchCallback(mTorchCallback, mHandler);
        mWakeLock = getSystemService(PowerManager.class)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, TAG + ":chop");
        mWakeLock.setReferenceCounted(false);
        mVibrator = getSystemService(VibratorManager.class).getDefaultVibrator();

        getContentResolver().registerContentObserver(Settings.Secure.getUriFor(SETTING), false,
                new ContentObserver(mHandler) {
                    @Override
                    public void onChange(boolean selfChange) {
                        update();
                    }
                });
        update();
    }

    private void update() {
        boolean enabled = Settings.Secure.getInt(getContentResolver(), SETTING, 1) != 0;
        if (enabled && !mListening) {
            mListening = mSensorManager.registerListener(this, mChop,
                    SensorManager.SENSOR_DELAY_NORMAL, mHandler);
            Log.i(TAG, "chop chop listener registered=" + mListening + " (" + mChop.getName() + ")");
        } else if (!enabled && mListening) {
            mSensorManager.unregisterListener(this, mChop);
            mListening = false;
            Log.i(TAG, "chop chop listener off");
        }
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        long now = SystemClock.elapsedRealtime();
        Log.i(TAG, "chop event value=" + (event.values.length > 0 ? event.values[0] : -1));
        if (now - mLastToggle < DEBOUNCE_MS) return;
        mLastToggle = now;
        mWakeLock.acquire(2000);
        toggleTorch();
    }

    private void toggleTorch() {
        try {
            if (mTorchId == null) mTorchId = findTorchCamera();
            if (mTorchId == null) {
                Log.w(TAG, "no camera with a flash unit");
                return;
            }
            boolean on = !mTorchOn;
            mCameraManager.setTorchMode(mTorchId, on);
            mTorchOn = on;
            mVibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK),
                    VibrationAttributes.createForUsage(VibrationAttributes.USAGE_HARDWARE_FEEDBACK));
            Log.i(TAG, "torch " + (on ? "on" : "off") + " (camera " + mTorchId + ")");
        } catch (CameraAccessException | IllegalArgumentException e) {
            Log.w(TAG, "torch toggle failed: " + e);
        }
    }

    private String findTorchCamera() throws CameraAccessException {
        String fallback = null;
        for (String id : mCameraManager.getCameraIdList()) {
            CameraCharacteristics c = mCameraManager.getCameraCharacteristics(id);
            if (!Boolean.TRUE.equals(c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE))) continue;
            Integer facing = c.get(CameraCharacteristics.LENS_FACING);
            if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) return id;
            if (fallback == null) fallback = id;
        }
        return fallback;
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }
}
