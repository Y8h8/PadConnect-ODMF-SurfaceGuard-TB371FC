#!/system/bin/sh

MODDIR=${0%/*}
STATE=/data/system/display-manager-state.xml
BACKUP="$MODDIR/display-manager-state.original.abx"
HASHES="$MODDIR/state_hashes.txt"
UNINSTALL_LOG=/data/local/tmp/PadConnect_CompatibilityGuard_uninstall.txt

{
    echo "ODMF_OVERLAY_RESTORE=AUTOMATIC_AFTER_MODULE_REMOVAL_AND_REBOOT"
    echo "TIME=$(date '+%Y-%m-%d %H:%M:%S %z')"
} > "$UNINSTALL_LOG"

if [ ! -f "$STATE" ] || [ ! -f "$BACKUP" ] || [ ! -f "$HASHES" ]; then
    echo "DISPLAY_RESTORE_SKIPPED=MISSING_STATE_BACKUP_OR_HASHES" >> "$UNINSTALL_LOG"
    exit 0
fi

PATCHED_SHA=$(sed -n 's/^PATCHED_SHA=//p' "$HASHES" | head -n 1)
ORIGINAL_SHA=$(sed -n 's/^ORIGINAL_SHA=//p' "$HASHES" | head -n 1)
CURRENT_SHA=$(sha256sum "$STATE" 2>/dev/null | awk '{print $1}')
BACKUP_SHA=$(sha256sum "$BACKUP" 2>/dev/null | awk '{print $1}')

if [ -n "$PATCHED_SHA" ] && [ "$CURRENT_SHA" = "$PATCHED_SHA" ] && \
   [ -n "$ORIGINAL_SHA" ] && [ "$BACKUP_SHA" = "$ORIGINAL_SHA" ]; then
    cat "$BACKUP" > "$STATE" 2>/dev/null
    sync
    RESTORED_SHA=$(sha256sum "$STATE" 2>/dev/null | awk '{print $1}')
    if [ "$RESTORED_SHA" = "$BACKUP_SHA" ]; then
        echo "DISPLAY_RESTORE_SUCCESS=1" >> "$UNINSTALL_LOG"
        echo "REBOOT_REQUIRED=1" >> "$UNINSTALL_LOG"
        exit 0
    fi
fi

echo "DISPLAY_RESTORE_SKIPPED=CURRENT_STATE_CHANGED_OR_WRITE_FAILED" >> "$UNINSTALL_LOG"
exit 0
