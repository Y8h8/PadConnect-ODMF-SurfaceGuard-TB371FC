# PadConnect Compatibility Guard（TB371FC）

这是在仓库原 `PadConnect ODMF SurfaceGuard v1.0` 基础上**新增**的整合版源码目录。

> 仓库根目录原有 `main` 内容无需修改；本目录仅作为新增内容存在。

整合版继续使用原模块 ID：

```text
padconnect_odmf_surfaceguard
```

包含：

- **ODMF SurfaceGuard**：修复 PadConnect 可以控制手机，但镜像一直加载/无画面。
- **StableDisplaySize Guard**：把错误的 StableDisplaySize `2400x3392` 修正为 TB371FC 的 `1840x2944`，用于修复或改善窗口偏右、横竖屏比例异常、横屏控制区域显示不完整和全屏裁切。

## 构建

Windows 下可直接运行：

```bat
build_module.bat
```

脚本会通过 ADB 自动从已连接的平板提取：

```text
/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar
```

保存为当前目录下的 `stock_odmf.jar`，校验原始 ODMF SHA-256 后构建整合模块。

要求：

- 平板已开启 USB 调试并授权当前电脑
- `adb` 可直接在命令行调用
- 已安装 Python 3

构建成功后生成：

```text
dist/PadConnect_ODMF_SurfaceGuard_Compatibility_TB371FC_Magisk_v1.1-test.zip
```

也可以手动提供自己提取的原始 ODMF：

```bat
python build_module.py D:\path\to\odmf.jar
```

## 从旧模块升级

如果设备已经安装：

- `PadConnect ODMF SurfaceGuard v1.0`
- `PadConnect StableDisplaySize Guard v0.3-test`
- 或之前以 StableDisplaySize ID 安装的 Compatibility Guard

可直接安装本整合版，不需要提前删除旧模块。

安装器会：

- 复用 `padconnect_odmf_surfaceguard` ID；
- 验证 ODMF 为原版或已知 PadConnect 修补版；
- StableDisplaySize 已为 `1840x2944` 时迁移旧模块保存的 ABX 回滚备份；
- 禁用旧 `padconnect_stable_display_size_guard_tb371fc`；
- 清理旧 SurfaceGuard 的 `disable/remove` 状态标记。

重启并确认 `STATE=ACTIVE_VERIFIED` 后，可删除旧 StableDisplaySize/Compatibility 模块。

## 验证

```bat
adb shell su -c "cat /data/adb/modules/padconnect_odmf_surfaceguard/verification-status.txt"
adb shell su -c "cat /data/adb/modules/padconnect_odmf_surfaceguard/verification.txt"
```

正常应包含：

```text
STATE=ACTIVE_VERIFIED
ODMF_ACTIVE_SHA=28f9b4cb8df1b5d2c6f7605470274e0dd356af9da622c3e819ffb96a784cc789
mStableDisplaySize=Point(1840, 2944)
SELINUX=Enforcing
```

## 适用环境

- Lenovo TB371FC / 小新 Pad Pro 12.7 2023
- Android 15
- ColorOS 15.0.1.801 Final 移植版（酷安 @兰微卡鱼）
- Build: `OPD2413_15.0.1.801(CN01)`
- Board: `spinel`
- SELinux: `Enforcing`

当前仍为测试版，仅针对上述环境验证。
