#!/system/bin/sh
# vegas26 GSI: install bundled apps ONCE as normal user apps, so the user can uninstall them.
# A global setting remembers each install; an uninstalled app is never pushed back.
DIR=/system/etc/vegas-preinstall
log -t vegas-preinstall "start"

install_once() { # <apk> <package> <key>
    [ "$(settings get global "$3")" = "1" ] && return 0
    if pm list packages "$2" | grep -q "package:$2\$"; then
        settings put global "$3" 1; return 0
    fi
    if pm install -r -g --user 0 "$1" >/dev/null 2>&1; then
        settings put global "$3" 1
        log -t vegas-preinstall "installed $2"
        return 0
    fi
    log -t vegas-preinstall "install of $2 failed"
    return 1
}

# GCam (MGC 9.7.047 BSG) with the OV50D low-noise config
GCAM=com.android.MGC_9_7_047
if install_once "$DIR/GCam.apk" "$GCAM" vegas_preinstalled_gcam; then
    # config for the in-app "Load config" menu
    mkdir -p /data/media/0/GcamConfigs
    cp -n "$DIR/vegas-gcam.xml" /data/media/0/GcamConfigs/vegas-gcam.xml
    chown -R 1023:1023 /data/media/0/GcamConfigs
    # seed the default prefs before the first launch so the config is active right away
    DATA=/data/user/0/$GCAM
    PREFS=$DATA/shared_prefs/${GCAM}_preferences.xml
    if [ -d "$DATA" ] && [ ! -f "$PREFS" ] && [ "$(settings get global vegas_gcam_config_seeded)" != "1" ]; then
        uid=$(stat -c %u "$DATA")
        mkdir -p "$DATA/shared_prefs"
        cp "$DIR/vegas-gcam.xml" "$PREFS"
        chown -R "$uid:$uid" "$DATA/shared_prefs"
        chmod 771 "$DATA/shared_prefs"; chmod 660 "$PREFS"
        restorecon -R "$DATA/shared_prefs"
        settings put global vegas_gcam_config_seeded 1
        log -t vegas-preinstall "seeded GCam config"
    fi
fi
log -t vegas-preinstall "done"
