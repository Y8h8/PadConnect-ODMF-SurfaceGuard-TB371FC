PadConnect ODMF SurfaceGuard + Display Guard v1.1-test
=====================================================

模块 ID：padconnect_odmf_surfaceguard

本版本保留原 PadConnect ODMF SurfaceGuard v1.0 的模块 ID，
并将 StableDisplaySize Guard 合并到同一个模块中。

包含两项修复：

1. ODMF SurfaceGuard
   修复 PadConnect 可以控制手机，但镜像画面一直加载/无画面的问题。

2. StableDisplaySize Guard
   将错误遗留的稳定显示尺寸 2400x3392 修正为 TB371FC 的 1840x2944，
   用于修复/改善窗口偏右、横竖屏比例异常、横屏控制区域显示不完整和全屏裁切。

从旧模块升级
------------

如果当前设备已经安装：

- PadConnect ODMF SurfaceGuard v1.0
- PadConnect StableDisplaySize Guard v0.3-test
  或之前以 StableDisplaySize ID 安装的 Compatibility Guard

可直接安装本 v1.1-test，不要提前删除旧模块。

安装器会：

- 复用 padconnect_odmf_surfaceguard ID，作为原 SurfaceGuard 的升级版；
- 验证当前 ODMF 仅为原版或已知 PadConnect 修补版；
- 如果 StableDisplaySize 已是 1840x2944，迁移旧模块保存的原始 ABX 回滚备份；
- 将旧 padconnect_stable_display_size_guard_tb371fc 模块设置为下次启动禁用；
- 清理旧 SurfaceGuard v1.0 遗留的 disable/remove 状态标记。

重启并确认本模块 STATE=ACTIVE_VERIFIED 后，
旧的 PadConnect StableDisplaySize Guard / Compatibility Guard 模块即可从 Magisk 删除。

最终 Magisk 只需要保留：

PadConnect ODMF SurfaceGuard + Display Guard
ID: padconnect_odmf_surfaceguard

验证命令
--------

adb shell su -c "cat /data/adb/modules/padconnect_odmf_surfaceguard/migration.txt"
adb shell su -c "cat /data/adb/modules/padconnect_odmf_surfaceguard/surfaceguard-status.txt"
adb shell su -c "cat /data/adb/modules/padconnect_odmf_surfaceguard/post-fs-data-status.txt"
adb shell su -c "cat /data/adb/modules/padconnect_odmf_surfaceguard/verification-status.txt"
adb shell su -c "cat /data/adb/modules/padconnect_odmf_surfaceguard/verification.txt"

正常应看到：

STATE=ACTIVE_VERIFIED
ODMF_ACTIVE_SHA=@PATCHED_SHA@
mStableDisplaySize=Point(1840, 2944)
SELINUX=Enforcing

安全机制
--------

- ODMF 原始 SHA 不匹配时自动禁用。
- DisplayManager 修改前保存原始 ABX。
- 写入后执行 SHA 与 ABX round-trip 校验。
- 卸载时只有当前 display-manager-state 仍与模块记录的修正版 SHA 一致，
  才会恢复原始备份，避免覆盖用户或系统之后的其他修改。
- ODMF 使用 Magisk systemless overlay，不直接写 system_ext 分区。

适用环境
--------

Lenovo TB371FC / 小新 Pad Pro 12.7 2023
Android 15
ColorOS 15.0.1.801 Final 移植版（酷安@兰微卡鱼）
Board: spinel
SELinux: Enforcing

当前仍为测试版，只针对上述环境验证。
