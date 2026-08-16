#!/system/bin/sh

MODDIR=${0%/*}
TARGET=/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar
ORIGINAL_SHA=628595d2cd39df8a47abc43c74a55232e3a4a0d92a02700821a02bcc1deb5e3d
STATUS="$MODDIR/status.txt"

current_sha=$(sha256sum "$TARGET" 2>/dev/null | awk '{print $1}')
if [ "$current_sha" != "$ORIGINAL_SHA" ]; then
    touch "$MODDIR/disable"
    {
        echo "STATE=AUTO_DISABLED"
        echo "REASON=STOCK_ODMF_SHA_CHANGED"
        echo "EXPECTED_SHA=$ORIGINAL_SHA"
        echo "FOUND_SHA=$current_sha"
        echo "TIME=$(date '+%Y-%m-%d %H:%M:%S %z')"
    } > "$STATUS"
    exit 0
fi

{
    echo "STATE=ENABLED"
    echo "STOCK_ODMF_SHA=$current_sha"
    echo "TIME=$(date '+%Y-%m-%d %H:%M:%S %z')"
} > "$STATUS"
exit 0
