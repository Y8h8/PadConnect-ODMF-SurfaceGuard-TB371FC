#!/system/bin/sh

ORIGINAL=/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar
PATCHED="$MODPATH/system/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar"
ORIGINAL_SHA=628595d2cd39df8a47abc43c74a55232e3a4a0d92a02700821a02bcc1deb5e3d
PATCHED_SHA=@PATCHED_SHA@

ui_print "***************************************"
ui_print " PadConnect ODMF SurfaceGuard v1.0"
ui_print " Device: TB371FC / third-party ColorOS port"
ui_print " ROM port: Coolapk user 兰微卡鱼"
ui_print "***************************************"

if [ "$BOOTMODE" != "true" ]; then
    abort "Install this module from the Magisk app, not recovery."
fi

if [ ! -f "$ORIGINAL" ]; then
    abort "ODMF target was not found on this device."
fi

current_sha=$(sha256sum "$ORIGINAL" | awk '{print $1}')
patch_sha=$(sha256sum "$PATCHED" | awk '{print $1}')
ui_print "Stock ODMF SHA: $current_sha"

if [ "$current_sha" != "$ORIGINAL_SHA" ]; then
    if [ "$current_sha" = "$PATCHED_SHA" ]; then
        abort "A RAM test is still active. Reboot, then install again."
    fi
    abort "Unsupported ODMF version. Module was not installed."
fi

if [ "$patch_sha" != "$PATCHED_SHA" ]; then
    abort "Module payload hash mismatch. Build the module again."
fi

set_perm "$PATCHED" 0 0 0644 u:object_r:system_file:s0
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755

ui_print "Verified SurfaceGuard payload."
ui_print "Reboot after installation, then test PadConnect."
ui_print "Disable or uninstall this module before a system update."
