#!/system/bin/sh

MODDIR=${0%/*}
ODMF_TARGET=/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar
ODMF_ORIGINAL_SHA=628595d2cd39df8a47abc43c74a55232e3a4a0d92a02700821a02bcc1deb5e3d
SURFACE_STATUS="$MODDIR/surfaceguard-status.txt"

STATE=/data/system/display-manager-state.xml
BACKUP="$MODDIR/display-manager-state.original.abx"
DECODED="$MODDIR/display-manager-state.decoded.xml"
PATCHED_XML="$MODDIR/display-manager-state.patched.xml"
PATCHED_ABX="$MODDIR/display-manager-state.patched.abx"
VERIFY_XML="$MODDIR/display-manager-state.verify.xml"
DISPLAY_STATUS="$MODDIR/post-fs-data-status.txt"
HASHES="$MODDIR/state_hashes.txt"

EXPECTED_BUILD="OPD2413_15.0.1.801(CN01)"
EXPECTED_PORT="15 Final by 酷安@兰微卡鱼"
EXPECTED_BOARD="spinel"
OLD_WIDTH='<stable-display-width>2400</stable-display-width>'
OLD_HEIGHT='<stable-display-height>3392</stable-display-height>'
NEW_WIDTH='<stable-display-width>1840</stable-display-width>'
NEW_HEIGHT='<stable-display-height>2944</stable-display-height>'

write_surface_status() {
    {
        echo "STATE=$1"
        echo "DETAIL=$2"
        echo "STOCK_ODMF_SHA=$3"
        echo "TIME=$(date '+%Y-%m-%d %H:%M:%S %z')"
    } > "$SURFACE_STATUS"
}

ODMF_SHA=$(sha256sum "$ODMF_TARGET" 2>/dev/null | awk '{print $1}')
if [ "$ODMF_SHA" != "$ODMF_ORIGINAL_SHA" ]; then
    touch "$MODDIR/disable"
    write_surface_status "AUTO_DISABLED" "STOCK_ODMF_SHA_CHANGED" "$ODMF_SHA"
    {
        echo "STATE=NOT_APPLIED"
        echo "DETAIL=MODULE_AUTO_DISABLED_FOR_ODMF_MISMATCH"
        echo "TIME=$(date '+%Y-%m-%d %H:%M:%S %z')"
    } > "$DISPLAY_STATUS"
    exit 0
fi
write_surface_status "STOCK_VERIFIED" "OVERLAY_ALLOWED" "$ODMF_SHA"

cleanup_temp() {
    rm -f "$DECODED" "$PATCHED_XML" "$PATCHED_ABX" "$VERIFY_XML"
}

write_display_status() {
    {
        echo "STATE=$1"
        echo "DETAIL=$2"
        echo "CONTEXT=$(id -Z 2>/dev/null)"
        echo "TIME=$(date '+%Y-%m-%d %H:%M:%S %z')"
    } > "$DISPLAY_STATUS"
}

fail_safe() {
    write_display_status "NOT_APPLIED" "$1"
    cleanup_temp
    exit 0
}

cleanup_temp
[ "$(getprop ro.build.display.id)" = "$EXPECTED_BUILD" ] || fail_safe "BUILD_MISMATCH"
[ "$(getprop ro.build.version.oplusrom.display)" = "$EXPECTED_PORT" ] || fail_safe "PORT_MISMATCH"
[ "$(getprop ro.product.board)" = "$EXPECTED_BOARD" ] || fail_safe "BOARD_MISMATCH"
[ -x /system/bin/abx2xml ] || fail_safe "ABX2XML_MISSING"
[ -x /system/bin/xml2abx ] || fail_safe "XML2ABX_MISSING"
[ -f "$STATE" ] || fail_safe "STATE_FILE_MISSING"

/system/bin/abx2xml "$STATE" "$DECODED" 2>/dev/null || fail_safe "ABX_DECODE_FAILED"

if grep -Fq "$NEW_WIDTH" "$DECODED" 2>/dev/null && \
   grep -Fq "$NEW_HEIGHT" "$DECODED" 2>/dev/null; then
    if [ -f "$BACKUP" ] && [ -f "$HASHES" ]; then
        write_display_status "ALREADY_APPLIED" "STABLE_DISPLAY_1840X2944_PRESENT_BACKUP_AVAILABLE"
    else
        write_display_status "ALREADY_APPLIED_NO_ROLLBACK" "STABLE_DISPLAY_1840X2944_PRESENT_BACKUP_MISSING"
    fi
    cleanup_temp
    exit 0
fi

OLD_WIDTH_COUNT=$(grep -Fo "$OLD_WIDTH" "$DECODED" 2>/dev/null | wc -l)
OLD_HEIGHT_COUNT=$(grep -Fo "$OLD_HEIGHT" "$DECODED" 2>/dev/null | wc -l)
[ "$OLD_WIDTH_COUNT" = "1" ] || fail_safe "EXPECTED_OLD_WIDTH_NOT_UNIQUE"
[ "$OLD_HEIGHT_COUNT" = "1" ] || fail_safe "EXPECTED_OLD_HEIGHT_NOT_UNIQUE"

if [ ! -f "$BACKUP" ]; then
    cp -p "$STATE" "$BACKUP" 2>/dev/null || fail_safe "BACKUP_FAILED"
fi

ORIGINAL_SHA=$(sha256sum "$STATE" 2>/dev/null | awk '{print $1}')
BACKUP_SHA=$(sha256sum "$BACKUP" 2>/dev/null | awk '{print $1}')
[ -n "$ORIGINAL_SHA" ] || fail_safe "ORIGINAL_HASH_FAILED"
[ "$ORIGINAL_SHA" = "$BACKUP_SHA" ] || fail_safe "BACKUP_HASH_MISMATCH"

sed \
    -e "s#$OLD_WIDTH#$NEW_WIDTH#" \
    -e "s#$OLD_HEIGHT#$NEW_HEIGHT#" \
    "$DECODED" > "$PATCHED_XML" 2>/dev/null || fail_safe "XML_PATCH_FAILED"

grep -Fq "$NEW_WIDTH" "$PATCHED_XML" 2>/dev/null || fail_safe "PATCHED_WIDTH_VALIDATION_FAILED"
grep -Fq "$NEW_HEIGHT" "$PATCHED_XML" 2>/dev/null || fail_safe "PATCHED_HEIGHT_VALIDATION_FAILED"
grep -Fq "$OLD_WIDTH" "$PATCHED_XML" 2>/dev/null && fail_safe "OLD_WIDTH_REMAINS"
grep -Fq "$OLD_HEIGHT" "$PATCHED_XML" 2>/dev/null && fail_safe "OLD_HEIGHT_REMAINS"

/system/bin/xml2abx "$PATCHED_XML" "$PATCHED_ABX" 2>/dev/null || fail_safe "ABX_ENCODE_FAILED"
/system/bin/abx2xml "$PATCHED_ABX" "$VERIFY_XML" 2>/dev/null || fail_safe "ABX_ROUNDTRIP_DECODE_FAILED"
grep -Fq "$NEW_WIDTH" "$VERIFY_XML" 2>/dev/null || fail_safe "ROUNDTRIP_WIDTH_VALIDATION_FAILED"
grep -Fq "$NEW_HEIGHT" "$VERIFY_XML" 2>/dev/null || fail_safe "ROUNDTRIP_HEIGHT_VALIDATION_FAILED"

PATCHED_SHA=$(sha256sum "$PATCHED_ABX" 2>/dev/null | awk '{print $1}')
[ -n "$PATCHED_SHA" ] || fail_safe "PATCHED_HASH_FAILED"

cat "$PATCHED_ABX" > "$STATE" 2>/dev/null || fail_safe "STATE_WRITE_FAILED"
sync

WRITTEN_SHA=$(sha256sum "$STATE" 2>/dev/null | awk '{print $1}')
if [ "$WRITTEN_SHA" != "$PATCHED_SHA" ]; then
    cat "$BACKUP" > "$STATE" 2>/dev/null
    sync
    fail_safe "WRITE_VERIFY_FAILED_BACKUP_RESTORED"
fi

/system/bin/abx2xml "$STATE" "$VERIFY_XML" 2>/dev/null || {
    cat "$BACKUP" > "$STATE" 2>/dev/null
    sync
    fail_safe "FINAL_DECODE_FAILED_BACKUP_RESTORED"
}
grep -Fq "$NEW_WIDTH" "$VERIFY_XML" 2>/dev/null || {
    cat "$BACKUP" > "$STATE" 2>/dev/null
    sync
    fail_safe "FINAL_WIDTH_INVALID_BACKUP_RESTORED"
}
grep -Fq "$NEW_HEIGHT" "$VERIFY_XML" 2>/dev/null || {
    cat "$BACKUP" > "$STATE" 2>/dev/null
    sync
    fail_safe "FINAL_HEIGHT_INVALID_BACKUP_RESTORED"
}

{
    echo "ORIGINAL_SHA=$ORIGINAL_SHA"
    echo "PATCHED_SHA=$PATCHED_SHA"
} > "$HASHES"
cleanup_temp
write_display_status "APPLIED_PENDING_BOOT_VERIFY" "ABX_STABLE_DISPLAY_2400X3392_TO_1840X2944"
exit 0
