# CBAP OS · 可版本化的 CBAP 运行底座

> 把 CBAP 装进一个**能选版本、能热切换、能回滚**的操作系统，而不是焊死在镜像里。

[CPNC](https://github.com/cyberdyne-bridge/cyberdyne-bridge-agent-physical-protocol) 主仓是**协议**；
本仓是**部署面**：Debian 13 (trixie) 底座 + 一层 CBAP 运行时，源码一个字节都不复制进来。

```text
Debian 13 (trixie) + XFCE
  └── /opt/cbap-os/versions/cbap/<version>      CBAP 源码槽（不可变）
  └── /opt/cbap-os/versions/python/<version>    Python 运行时槽
  └── /opt/cbap-os/current/{cbap,python}        当前挂载点（bind mount，不是复制）
  └── /etc/cbap-os/selection.json               开机/当前选择
  └── cbap.service                              Kernel（等 socket 出现才启动）
```

**它解决的问题**：同一台机器上并存多个 CBAP 版本，开机选一个、登录后还能换、换挂了能回滚，
而旧槽永远不被修改。

---

## 状态：实验性（v0.1）

诚实交代，别把它当成品：

| 能力 | 状态 |
|---|---|
| 版本槽 + 挂载切换 + 回滚 | ✅ 有单元测试（11 条，`tests/`，不需要 root/systemd） |
| 安装到 rootfs（`install.sh`） | ✅ 已做端到端冒烟（`--no-systemd --no-users`） |
| 开机选择（GRUB 每槽一项） | ✅ 产出过可启动 ISO |
| 开机选择（tty1 菜单） | ⚠️ 代码在，但**未在 QEMU 镜像内验证成功**；ISO 默认 `cbap.nomenu` 走 GRUB |
| 登录后热切换 / 失败回滚 | ✅ 代码在，有测试；真实镜像上的回归依赖手工 |
| 完整镜像重建 | ⚠️ **2026-10-24 之后的改动没有重跑过 QEMU 构建** |
| 多 Python 二进制 | ⚠️ 机制已留，默认只带系统 Python 槽 |

## 三个"控制"别搞混

| 名字 | 管什么 | 在哪 |
|---|---|---|
| `cbap-control`（Tk） | **版本槽**：选哪个 CBAP / Python、host bridge 测试 | 本仓 `bin/cbap-control` |
| Operator Console（web） | **Kernel 状态**：设备、租约、审计、estop | [主仓 `console/`](https://github.com/cyberdyne-bridge/cyberdyne-bridge-agent-physical-protocol/tree/main/console) |
| `cbap-os`（CLI） | 槽位管理的命令行入口（`list/status/use/boot/rollback/doctor`） | 本仓 `bin/cbap-os` |

三者不重叠：`cbap-control` 不看 Kernel 状态，Console 不管版本槽。

---

## 快速开始

### 1. 装进一个 rootfs

```bash
# 从 release tag 拉源码槽（默认 v1.7.5）
sudo bash install.sh --root / --cbap-version v1.7.5

# 或者用本地 checkout（开发时）
sudo bash install.sh --root / --cbap-src ~/cyberdyne-bridge

# 只做测试，不碰 systemd 和用户
bash install.sh --root /tmp/rootfs --cbap-src /path/to/cbap --no-systemd --no-users
```

装完会有：

```text
/opt/cbap-os/versions/cbap/v1.7.5
/opt/cbap-os/current/cbap          -> 指向选中的槽
/usr/local/bin/{cbap,cbap-os,cbap-service,cbap-control,cbap-python}
/etc/cbap-os/{selection.json,runtime.env,host-test.json}
```

### 2. 加第二个版本（并存）

```bash
sudo bash install.sh --root / --cbap-version v1.7.4
sudo cbap-os list
```

### 3. 切 / 回滚

```bash
sudo cbap-os status
sudo cbap-os use --cbap v1.7.4 --python 3.12   # 停服务 → 切挂载 → 起服务；失败自动恢复旧槽
sudo cbap-os rollback
sudo cbap-os doctor
```

### 4. 开机选版本

- **ISO / GRUB**：每个槽一个 menuentry，内核参数带 `cbap.cbap=<ver> cbap.python=<ver>`；
- **装到磁盘**：tty1 菜单（10 秒超时，`cbap.nomenu` 可关）；
- **无头机**：直接给内核参数，例如 `cbap.cbap=v1.7.5 cbap.python=3.12`。

### 5. 构建 ISO

```bash
# 需要一个 Debian rootfs；输出到 out/
bash iso/build-iso.sh --rootfs /path/to/rootfs --cbap-version v1.7.5
# -> out/CBAP-OS.iso
```

依赖：`mtools grub-pc-bin grub-efi-amd64-bin xorriso squashfs-tools cpio busybox-static`。
构建过程**不需要 root**（复制 rootfs 后在 workspace 里装运行时层）。

---

## 布局

```text
bin/cbap-os            槽位管理 CLI（list/status/use/boot/boot-menu/rollback/doctor）
bin/cbap               用选中的 Python 跑选中的 CBAP（python3 -m kernel.legacy_runtime）
bin/cbap-service       systemd 入口，把 runtime.env 展开成 kernel 参数
bin/cbap-control       Tk 控制中心（槽位 + host bridge 测试）
systemd/               cbap-os-select / cbap-os-mount / cbap
etc/                   selection.json、runtime.env、host-test.json
iso/                   build-iso.sh（squashfs + grub-mkrescue）与 initrd init
install.sh             把运行时层装进 rootfs
tests/                 11 条主机级测试（不需要 root / systemd / 真 bind mount）
```

## 环境变量

```text
CBAP_HOME / CBAP_PYTHON        bin/cbap 用的槽内路径（默认 /opt/cbap-os/current/*）
CBAP_HAND_SOCKET               默认 /run/cyberdyne/cyberdyne.sock
CBAP_CBAP_SOCKET               默认 /run/cbap/cbap.sock
CBAP_DEVICE / CBAP_MAPPING     默认指向槽内 drivers/mc/*
CBAP_AUDIT                     默认 /var/lib/cbap/audit.jsonl
CBAP_ALLOWED_UIDS              逗号分隔的 agent uid 白名单（可选）
CBAP_OS_ROOT                   测试用：把 / 换成临时目录
```

## 安全注意

- `cbap.service` 用 `ExecCondition` 等 socket 出现；**没有 hand 就跳过**，不会让系统卡在 failed。
- Kernel 走 Unix socket（`0600` + `SO_PEERCRED`），token 文件 `0600`；操作员能力（estop / 释放租约）默认不给普通 agent。
- 审计目录 `/var/lib/cbap` 由 `cbap` 服务用户（uid 997）持有；ISO 的 live 会话会被 `chmod 0777` 以便写入 —— **这只适合一次性 live 环境，装到磁盘后请改回来**。
- `etc/host-test.json` 里**没有**固定 token：QEMU 测试时读宿主机 `<socket>.token` 再填。

## 跟主仓的关系

本仓**不复制**协议代码，只按 tag 取源码放进槽位。协议、Kernel、租约、安全、审计、conformance 全在主仓：

- 协议与实现：`cyberdyne-bridge/cyberdyne-bridge-agent-physical-protocol`
- 本仓只在 `install.sh` 的 `--cbap-tarball` 默认值里依赖它的 tag 命名（`vX.Y.Z`）

## 许可

MIT，见 [`LICENSE`](LICENSE)。AI 辅助编写说明见 [`NOTICE.md`](NOTICE.md)。
