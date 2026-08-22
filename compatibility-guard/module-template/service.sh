#!/system/bin/sh

MODDIR=${0%/*}
STATUS="$MODDIR/verification-status.txt"
RESULT="$MODDIR/verification.txt"
ODMF_TARGET=/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar
ODMF_PATCHED_SHA=@PATCHED_SHA@

count=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$count" -lt 120 ]; do
    sleep 1
    count=$((count + 1))
done

sleep 5
DISPLAY_DUMP=$(dumpsys display 2>/dev/null)
STABLE=$(echo "$DISPLAY_DUMP" | grep -m 1 'mStableDisplaySize=')
WIDTH_GROUP=$(getprop persist.oplus.display.screen.widthgroup)
HEIGHT_GROUP=$(getprop persist.oplus.display.screen.heightgroup)
SELINUX_STATE=$(getenforce 2>/dev/null)
ODMF_ACTIVE_SHA=$(sha256sum "$ODMF_TARGET" 2>/dev/null | awk '{print $1}')

{
    echo "PADCONNECT_COMPATIBILITY_GUARD_V1_0_TEST"
    echo "BOOT_COMPLETED=$(getprop sys.boot_completed)"
    echo "SELINUX=$SELINUX_STATE"
    echo "ODMF_ACTIVE_SHA=$ODMF_ACTIVE_SHA"
    echo "ODMF_EXPECTED_PATCHED_SHA=$ODMF_PATCHED_SHA"
    echo "$STABLE"
    echo "WIDTH_GROUP=$WIDTH_GROUP"
    echo "HEIGHT_GROUP=$HEIGHT_GROUP"
    echo "TIME=$(date '+%Y-%m-%d %H:%M:%S %z')"
} > "$RESULT"

ODMF_OK=0
DISPLAY_OK=0
SELINUX_OK=0
[ "$ODMF_ACTIVE_SHA" = "$ODMF_PATCHED_SHA" ] && ODMF_OK=1
if echo "$STABLE" | grep -Fq 'Point(1840, 2944)' && \
   [ "$WIDTH_GROUP" = "1840,1840,1840,1840" ] && \
   [ "$HEIGHT_GROUP" = "2944,2944,2944,2944" ]; then
    DISPLAY_OK=1
fi
[ "$SELINUX_STATE" = "Enforcing" ] && SELINUX_OK=1

if [ "$ODMF_OK" = "1" ] && [ "$DISPLAY_OK" = "1" ] && [ "$SELINUX_OK" = "1" ]; then
    {
        echo "STATE=ACTIVE_VERIFIED"
        echo "DETAIL=SURFACEGUARD_AND_STABLE_DISPLAY_1840X2944"
        echo "TIME=$(date '+%Y-%m-%d %H:%M:%S %z')"
    } > "$STATUS"
else
    {
        echo "STATE=VERIFY_FAILED"
        echo "ODMF_OK=$ODMF_OK"
        echo "DISPLAY_OK=$DISPLAY_OK"
        echo "SELINUX_OK=$SELINUX_OK"
        echo "DETAIL=CHECK_SURFACEGUARD_POST_FS_AND_VERIFICATION_FILES"
        echo "TIME=$(date '+%Y-%m-%d %H:%M:%S %z')"
    } > "$STATUS"
fi
exit 0
