# PadConnect ODMF SurfaceGuard for TB371FC

用于修复联想小新 Pad Pro 12.7 骁龙版 2023（`TB371FC`）刷入由酷安用户
**兰微卡鱼**提取、移植适配的指定 ColorOS 15 包后，跨屏镜像
**可以控制，但画面一直加载**的问题。

> [!IMPORTANT]
> 本项目仅适配并验证了下表中的设备、系统和 ODMF 文件。其他版本会被
> 构建脚本和模块安装脚本拒绝，不能强行使用。

## 已验证环境

| 项目 | 值 |
| --- | --- |
| 设备 | 联想小新 Pad Pro 12.7 骁龙版 2023 |
| 型号 | `TB371FC` |
| 系统类型 | 第三方 ColorOS 移植适配包（非官方系统） |
| 移植包版本 | `ColorOS 15.0.1.801_Final_A15_TB371FC[9044bd]` |
| 提取、移植适配作者 | 酷安用户 **兰微卡鱼** |
| 原始发布平台 | 酷安 |
| Android | 15 |
| 原始 ODMF 路径 | `/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar` |
| 原始 ODMF SHA-256 | `628595d2cd39df8a47abc43c74a55232e3a4a0d92a02700821a02bcc1deb5e3d` |

## 系统来源与致谢

本项目适配的 `ColorOS 15.0.1.801_Final_A15_TB371FC[9044bd]` 并非联想、
OPPO、OPlus 或 ColorOS 官方为 `TB371FC` 发布的系统包，而是由酷安用户
**兰微卡鱼**提取并完成移植适配。在此感谢其移植与分享。

本项目作者没有参与该系统包的提取、移植、适配或发布，只针对使用该移植包时
出现的 PadConnect 兼容性问题提供独立修复。本项目与兰微卡鱼不存在合作、授权、
代理或背书关系，也不代表其对本项目进行认可或担保。

## 原因与修复

PadConnect 的控制和视频走不同通道，所以控制可以正常工作，但视频解码
输出缓冲区分配失败。该第三方移植包中的 ODMF 在 `AndroidVideoDecoder` 使用 Surface
解码时，依据 `sharedContext` 判断是否写入字节缓冲区颜色格式。当前设备的
实际路径中 Surface 已存在而 `sharedContext` 为空，导致 `0x13` 被错误传给
QTI Gralloc，随后出现：

```text
qdgralloc: GetGpuPixelFormat: No map for format: 0x13
GraphicBufferAllocator: Failed to allocate ... format 19
ACodec: dequeueBuffer failed: BAD_VALUE(-22)
```

本项目把这处判断字段从 `sharedContext` 改为实际的 `surface`。Surface 存在
时不再强制写入字节缓冲区格式，由 HEVC 解码器与 GraphicBuffer 正常协商。

修改范围只有 DEX 中一个字段引用：

```text
field@0x070c (sharedContext) -> field@0x0710 (surface)
```

没有修改 Gralloc、SurfaceFlinger、display allocator、composer 或 OMX 服务。

## 实测结果

修复后的 12 秒采样结果：

| 指标 | 结果 |
| --- | --- |
| 解码器 | `OMX.qcom.video.decoder.hevc` |
| 画面 | 正常显示并可控制 |
| 分辨率 | 1080 × 2376 |
| 解码/输出帧率 | 约 59–60 FPS |
| 丢包 | 0 |
| freezes | 0 |
| 原 Gralloc/`BAD_VALUE(-22)` 错误 | 未再出现 |

## 为什么仓库没有 odmf.jar

`odmf.jar` 是厂商固件文件，不属于本项目作者。本仓库不会上传原始或修改后的
厂商 JAR，也不会在 Releases 中提供包含该 JAR 的成品模块。每位用户需要从
自己有权使用的同版本设备或固件中提取原文件，然后在本地生成模块。

## 本地构建

### Windows 一键构建

准备：

- 已安装 ADB，并让 `adb.exe` 可在当前目录或 PATH 中运行；
- 已安装 Python 3；
- 平板已连接电脑并允许 USB 调试；
- 如果运行过 RAM 测试，先重启平板。

双击：

```text
build_module.bat
```

脚本会从平板读取原始 `odmf.jar`，核对 SHA，最后在 `dist` 目录生成：

```text
PadConnect_ODMF_SurfaceGuard_TB371FC_Magisk_v1.0.zip
```

### 手动构建

```bash
adb pull /system_ext/framework/oplusex/com.oplus.odmf/odmf.jar stock_odmf.jar
python build_module.py stock_odmf.jar
```

构建过程只使用 Python 标准库，不需要额外安装第三方包。

## 安装

1. 如果运行过任何 RAM 测试，先重启平板。
2. 不要解压 `dist` 目录中的模块 ZIP。
3. 打开 Magisk/面具 → **模块** → **从本地安装**。
4. 选择生成的 ZIP，安装完成后重启。
5. 打开 PadConnect，先短时间测试镜像，再逐渐延长使用时间。

安装脚本会再次核对平板原始 ODMF SHA。模块还会在每次开机挂载前检查原文件；
如果系统更新改变了 ODMF，模块会自动禁用。

## 停用与恢复

在 Magisk/面具中禁用或卸载模块，然后重启。模块不会写入实体系统分区。

如果界面无法操作但 ADB 和 root 仍可用：

```bash
adb shell su -c "touch /data/adb/modules/padconnect_odmf_surfaceguard/disable"
adb reboot
```

## 注意事项

- 只支持上方列出的系统版本和原始 SHA。
- 系统更新前建议先禁用或卸载模块。
- 不要叠加旧的 Gralloc、allocator、composer、OMX、H264、YV12 或 ODMF RAM 补丁。
- 修改系统组件存在风险，请提前保留可用的 ADB、Magisk 禁用模块或恢复手段。
- 本项目仅供学习、研究和兼容性测试，不对设备损坏、数据丢失、无法启动、保修
  影响或其他直接、间接损失承担责任；使用者须自行判断并承担风险。
- 本项目及其适配目标均非官方项目。本项目与联想、OPPO、OPlus、ColorOS、
  酷安及兰微卡鱼无隶属、合作、授权、代理或背书关系。
- 第三方移植包及其中的厂商文件、应用和商标权利归各自权利人所有；请仅在拥有
  合法使用权的设备或固件副本上构建和使用本模块。

## 许可证

本仓库中由作者编写的构建脚本、模块模板和文档使用 [MIT License](LICENSE)。
该许可证不覆盖任何第三方固件、应用、商标或厂商文件，详见 [NOTICE.md](NOTICE.md)。

## 问题
<img width="1280" height="800" alt="9d4a4d0ef4e376e8758235a1f32ec2ab_720" src="https://github.com/user-attachments/assets/beaa520b-e8c9-4116-8e69-5b713aa04acb" />

## 解决后
<img width="1280" height="800" alt="dca3460c5e3269d9c40a99d33e667a86_720" src="https://github.com/user-attachments/assets/78bd1691-8792-421f-be27-f1264131eb94" />
<img width="1280" height="800" alt="790b4ff2264a23ad5e5f480d15108c1c_720" src="https://github.com/user-attachments/assets/cb6fea9e-71fa-4b9a-92cb-8b08c3a44c30" />
