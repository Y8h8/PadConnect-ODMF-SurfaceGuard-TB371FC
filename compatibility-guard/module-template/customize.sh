#!/system/bin/sh

EXPECTED_BUILD="OPD2413_15.0.1.801(CN01)"
EXPECTED_PORT="15 Final by 酷安@兰微卡鱼"
EXPECTED_BOARD="spinel"
EXPECTED_WIDTH_GROUP="1840,1840,1840,1840"
EXPECTED_HEIGHT_GROUP="2944,2944,2944,2944"

ODMF_ORIGINAL=/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar
ODMF_PATCHED="$MODPATH/system/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar"
ODMF_ORIGINAL_SHA=628595d2cd39df8a47abc43c74a55232e3a4a0d92a02700821a02bcc1deb5e3d
ODMF_PATCHED_SHA=@PATCHED_SHA@

SURFACE_MOD=/data/adb/modules/padconnect_odmf_surfaceguard
OLD_DISPLAY_MOD=/data/adb/modules/padconnect_stable_display_size_guard_tb371fc
MIGRATION_LOG="$MODPATH/migration.txt"

ui_print "*********************************************"
ui_print " PadConnect ODMF SurfaceGuard v1.1-test"
ui_print " TB371FC / ColorOS 15.0.1.801 Final port"
ui_print " SurfaceGuard + StableDisplaySize Guard"
ui_print " Module ID: padconnect_odmf_surfaceguard"
ui_print "*********************************************"

if [ "$BOOTMODE" != "true" ]; then
    abort "Install this module from the Magisk app, not recovery."
fi

BUILD=$(getprop ro.build.display.id)
PORT=$(getprop ro.build.version.oplusrom.display)
BOARD=$(getprop ro.product.board)
WIDTH_GROUP=$(getprop persist.oplus.display.screen.widthgroup)
HEIGHT_GROUP=$(getprop persist.oplus.display.screen.heightgroup)
ENFORCE=$(getenforce 2>/dev/null)

ui_print "Build: $BUILD"
ui_print "Port: $PORT"
ui_print "Board: $BOARD"
ui_print "Display group: ${WIDTH_GROUP} x ${HEIGHT_GROUP}"
ui_print "SELinux: $ENFORCE"

[ "$BUILD" = "$EXPECTED_BUILD" ] || abort "Unsupported build. Module was not installed."
[ "$PORT" = "$EXPECTED_PORT" ] || abort "Unsupported ROM port. Module was not installed."
[ "$BOARD" = "$EXPECTED_BOARD" ] || abort "Unsupported board. Module was not installed."
[ "$WIDTH_GROUP" = "$EXPECTED_WIDTH_GROUP" ] || abort "Unexpected physical display width group."
[ "$HEIGHT_GROUP" = "$EXPECTED_HEIGHT_GROUP" ] || abort "Unexpected physical display height group."
[ "$ENFORCE" = "Enforcing" ] || abort "SELinux must be Enforcing before installation."
[ -x /system/bin/abx2xml ] || abort "Required system tool abx2xml was not found."
[ -x /system/bin/xml2abx ] || abort "Required system tool xml2abx was not found."
[ -f "$ODMF_ORIGINAL" ] || abort "ODMF target was not found on this device."
[ -f "$ODMF_PATCHED" ] || abort "SurfaceGuard payload is missing from the module."

ODMF_CURRENT_SHA=$(sha256sum "$ODMF_ORIGINAL" 2>/dev/null | awk '{print $1}')
ODMF_PAYLOAD_SHA=$(sha256sum "$ODMF_PATCHED" 2>/dev/null | awk '{print $1}')
ui_print "Current ODMF SHA: $ODMF_CURRENT_SHA"

[ "$ODMF_PAYLOAD_SHA" = "$ODMF_PATCHED_SHA" ] || abort "SurfaceGuard payload hash mismatch."

KNOWN_PATCH_OWNER=0
for KNOWN_MOD in "$SURFACE_MOD" "$OLD_DISPLAY_MOD"; do
    KNOWN_JAR="$KNOWN_MOD/system/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar"
    if [ -f "$KNOWN_JAR" ]; then
        KNOWN_SHA=$(sha256sum "$KNOWN_JAR" 2>/dev/null | awk '{print $1}')
        [ "$KNOWN_SHA" = "$ODMF_PATCHED_SHA" ] && KNOWN_PATCH_OWNER=1
    fi
done

case "$ODMF_CURRENT_SHA" in
    "$ODMF_ORIGINAL_SHA")
        ODMF_INSTALL_STATE="STOCK_VISIBLE"
        ;;
    "$ODMF_PATCHED_SHA")
        [ "$KNOWN_PATCH_OWNER" = "1" ] || abort "Patched ODMF is visible, but no known PadConnect module owns this exact patch. Reboot to stock ODMF and retry."
        ODMF_INSTALL_STATE="KNOWN_PADCONNECT_PATCH_VISIBLE"
        ;;
    *)
        abort "Unsupported ODMF version. Module was not installed."
        ;;
esac

DISPLAY_DUMP=$(dumpsys display 2>/dev/null)
if echo "$DISPLAY_DUMP" | grep -Fq "mStableDisplaySize=Point(2400, 3392)"; then
    DISPLAY_INSTALL_STATE="STALE_2400X3392"
elif echo "$DISPLAY_DUMP" | grep -Fq "mStableDisplaySize=Point(1840, 2944)"; then
    DISPLAY_INSTALL_STATE="ALREADY_1840X2944"
else
    abort "Unexpected StableDisplaySize. Expected 2400x3392 or 1840x2944."
fi

MIGRATED_BACKUP=0
if [ "$DISPLAY_INSTALL_STATE" = "ALREADY_1840X2944" ]; then
    OLD_BACKUP="$OLD_DISPLAY_MOD/display-manager-state.original.abx"
    OLD_HASHES="$OLD_DISPLAY_MOD/state_hashes.txt"
    [ -f "$OLD_BACKUP" ] || abort "Display size is already corrected, but the rollback backup was not found in the previous StableDisplay/Compatibility module."
    [ -f "$OLD_HASHES" ] || abort "Display size is already corrected, but rollback hashes were not found in the previous StableDisplay/Compatibility module."

    RECORDED_ORIGINAL_SHA=$(sed -n 's/^ORIGINAL_SHA=//p' "$OLD_HASHES" | head -n 1)
    RECORDED_PATCHED_SHA=$(sed -n 's/^PATCHED_SHA=//p' "$OLD_HASHES" | head -n 1)
    ACTUAL_BACKUP_SHA=$(sha256sum "$OLD_BACKUP" 2>/dev/null | awk '{print $1}')
    [ -n "$RECORDED_ORIGINAL_SHA" ] || abort "Old rollback metadata is incomplete."
    [ -n "$RECORDED_PATCHED_SHA" ] || abort "Old rollback metadata is incomplete."
    [ "$ACTUAL_BACKUP_SHA" = "$RECORDED_ORIGINAL_SHA" ] || abort "Old rollback backup hash verification failed."

    cp -p "$OLD_BACKUP" "$MODPATH/display-manager-state.original.abx" || abort "Failed to migrate the display rollback backup."
    cp -p "$OLD_HASHES" "$MODPATH/state_hashes.txt" || abort "Failed to migrate the display rollback hashes."
    MIGRATED_BACKUP=1
fi

if [ -d "$OLD_DISPLAY_MOD" ]; then
    touch "$OLD_DISPLAY_MOD/disable" 2>/dev/null || abort "Failed to disable the old StableDisplay/Compatibility module."
    OLD_DISPLAY_ACTION="DISABLED_FOR_NEXT_BOOT"
else
    OLD_DISPLAY_ACTION="NOT_INSTALLED"
fi

# This package intentionally reuses the original SurfaceGuard module ID.
# Clear stale state markers from the old v1.0 instance so the upgraded module
# is not left disabled/queued for removal after Magisk swaps modules on reboot.
if [ -d "$SURFACE_MOD" ]; then
    rm -f "$SURFACE_MOD/disable" "$SURFACE_MOD/remove" 2>/dev/null
    SURFACE_ID_ACTION="REUSED_AS_UPGRADE"
else
    SURFACE_ID_ACTION="FRESH_INSTALL"
fi

{
    echo "ODMF_INSTALL_STATE=$ODMF_INSTALL_STATE"
    echo "DISPLAY_INSTALL_STATE=$DISPLAY_INSTALL_STATE"
    echo "MIGRATED_DISPLAY_BACKUP=$MIGRATED_BACKUP"
    echo "SURFACE_ID_ACTION=$SURFACE_ID_ACTION"
    echo "OLD_DISPLAY_ACTION=$OLD_DISPLAY_ACTION"
    echo "TIME=$(date '+%Y-%m-%d %H:%M:%S %z')"
} > "$MIGRATION_LOG"

set_perm "$ODMF_PATCHED" 0 0 0644 u:object_r:system_file:s0
set_perm "$MODPATH/customize.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/README_zh-CN.txt" 0 0 0644
[ -f "$MODPATH/display-manager-state.original.abx" ] && set_perm "$MODPATH/display-manager-state.original.abx" 0 0 0600
[ -f "$MODPATH/state_hashes.txt" ] && set_perm "$MODPATH/state_hashes.txt" 0 0 0600

rm -f "$MODPATH/status.txt" "$MODPATH/surfaceguard-status.txt" \
    "$MODPATH/post-fs-data-status.txt" "$MODPATH/verification-status.txt" \
    "$MODPATH/verification.txt" "$MODPATH/display-manager-state.decoded.xml" \
    "$MODPATH/display-manager-state.patched.xml" "$MODPATH/display-manager-state.patched.abx" \
    "$MODPATH/display-manager-state.verify.xml"

ui_print "SurfaceGuard payload verified."
if [ "$MIGRATED_BACKUP" = "1" ]; then
    ui_print "Existing StableDisplaySize rollback backup migrated."
else
    ui_print "StableDisplaySize is stale; a fresh rollback backup will be created at next boot."
fi
if [ "$OLD_DISPLAY_ACTION" = "DISABLED_FOR_NEXT_BOOT" ]; then
    ui_print "Old StableDisplay/Compatibility module will be disabled on the next boot."
fi
ui_print "Original SurfaceGuard module ID will be retained."
ui_print "Install checks passed. Reboot once, then verify status."
