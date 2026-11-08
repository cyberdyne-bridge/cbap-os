# NOTICE

## 生成方式

本仓的脚本与文档由作者主导设计，**借助 AI 辅助编写**（DeepSeek V4 / Qwen 系列）。
所有"已验证 / 未验证"的结论以 `tests/` 与真实构建记录为准，不以文档措辞为准。

## 第三方

| 组件 | 用途 | 许可 |
|---|---|---|
| Debian 13 (trixie) | 底座 rootfs（不随本仓分发） | 各自自由软件许可 |
| GRUB / xorriso / squashfs-tools / mtools / busybox | ISO 构建与 initrd | GPL / MIT 等，以各自为准 |
| Tk（Python 标准库） | `cbap-control` 界面 | PSF |
| CBAP / CPNC | 被安装的协议实现，按 tag 取用，不随本仓分发 | MIT（见主仓） |

本仓与 Debian、GRUB 项目等无隶属关系，未获其背书。
