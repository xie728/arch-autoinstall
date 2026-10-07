# arch-autoinstall

One-click Arch Linux installer for VMware, with GNOME/XFCE/Niri desktop, Chinese locale, and VMware guest enhancements.
面向 VMware 虚拟机的 Arch Linux 一键安装脚本，可选 GNOME / XFCE / Niri 桌面、中文环境与 VMware 增强工具。

---

## Features / 功能特性

- Fully automated install: partition → base system → network → desktop → bootloader → auto shutdown
- 全自动安装：分区 → 基础系统 → 网络 → 桌面 → 引导 → 自动关机
- BIOS (MBR) and UEFI (GPT) auto-detected
- BIOS (MBR) 与 UEFI (GPT) 自动识别
- Defaults tuned for China (Aliyun mirror, Alibaba DNS, fcitx5 input method, CJK fonts)
- 默认国内优化（阿里云源、阿里 DNS、fcitx5 中文输入法、中文字体）
- Three desktop options: `gnome` (default), `xfce`, `nyxuri`
- 三种桌面可选：`gnome`（默认，官方仓库稳定）、`xfce`、`nyxuri`
- Safe fallback: if the desktop fails, boot drops to tty instead of a broken login loop
- 安全降级：桌面安装失败时自动跳过图形登录，进 tty 便于修复

---

## Files / 文件清单

| File / 文件 | Description / 说明 |
|---|---|
| `autoinstall.sh` | The one-click installer script / 一键安装脚本本体 |
| `make-autoinstall-iso.sh` | Build a fully auto-booting ISO on any Linux / 在任意 Linux 里构建零操作 ISO |
| `README.md` | This document / 本说明 |

> The ISO itself (~1.8 GB) exceeds GitHub's 100 MB file limit and is not committed to the repo.
> **Option 1**: Download the prebuilt auto-install ISO from the [Releases page](https://github.com/xie728/arch-autoinstall/releases).
> **Option 2**: Build it yourself with `make-autoinstall-iso.sh` (see below).
> **Option 3**: Just run `autoinstall.sh` directly from the official Arch ISO (see Method A below).
>
> ISO 文件（约 1.8 GB）超过 GitHub 100MB 单文件限制，不放进仓库。
> **方式一**：从 [Releases 页面](https://github.com/xie728/arch-autoinstall/releases) 下载已构建好的零操作 ISO。
> **方式二**：用 `make-autoinstall-iso.sh` 自己构建（见下文）。
> **方式三**：直接在官方 Arch ISO 的 Live 环境里跑 `autoinstall.sh`（见下文方式 A）。

---

## Default configuration / 默认配置

| Item / 项 | Value / 值 |
|---|---|
| Target disk / 目标磁盘 | `/dev/sda` (**whole disk will be erased!** / **整盘清空！**) |
| Hostname / 主机名 | `arch` |
| User / 用户名 | `arch` |
| User password / 用户密码 | `123456` |
| Root password / root 密码 | `123456` |
| Timezone / 时区 | `Asia/Shanghai` |
| Desktop / 桌面 | `gnome` (override: `DESKTOP=xfce` or `DESKTOP=nyxuri`) |
| Mirror / 软件源 | Aliyun (`mirrors.aliyun.com`) |

All of the above can be edited at the top of `autoinstall.sh`.
以上全部可在 `autoinstall.sh` 顶部修改。

---

## Prerequisites / 前置要求

1. A virtual machine (VMware Workstation / Fusion) with:
   - Disk ≥ 20 GB
   - Network adapter set to **NAT**
   - Firmware: UEFI or BIOS (both auto-detected)
2. Boot the official Arch Linux ISO (https://archlinux.org/download/)
3. Working network in the Live environment (NAT provides DHCP automatically)

1. 一台虚拟机（VMware Workstation / Fusion）：
   - 硬盘 ≥ 20 GB
   - 网络适配器设为 **NAT**
   - 固件 UEFI 或 BIOS 均可（自动识别）
2. 从官方 Arch Linux ISO 启动（https://archlinux.org/download/）
3. Live 环境能联网（NAT 默认 DHCP）

---

## Quick start — Method A: one command (recommended) / 快速开始——方式 A：一条命令（推荐）

Boot the Arch ISO and drop to the Live shell (`root@archiso ~ #`), then run:
启动 Arch ISO 进入 Live shell（`root@archiso ~ #`），执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/xie728/arch-autoinstall/main/autoinstall.sh)
```

Or, if you already put the script on the ISO / USB:
或者，如果已把脚本放进 ISO / U 盘：

```bash
bash /run/archiso/bootmnt/autoinstall.sh
```

Sit back. The script will:
你什么都不用按，脚本会：

1. Wait for network / 等待网络
2. Partition `/dev/sda` / 给 `/dev/sda` 分区
3. Install base system / 安装基础系统
4. Install Chinese locale + fcitx5 + VMware tools / 装中文环境与 VMware 工具
5. Install the chosen desktop / 安装所选桌面
6. Install GRUB bootloader / 装 GRUB 引导
7. **Power off automatically when done** / 装完自动关机

Remove the ISO, boot the VM, and log in.
移除 ISO，开机即可使用。

---

## Quick start — Method B: fully auto-booting ISO (zero input) / 方式 B：开机零操作 ISO

On any Linux machine (or inside the Arch Live environment), run:
在任意 Linux 机器（或 Arch Live 环境里）执行：

```bash
# install build tools first / 先装构建工具
sudo pacman -S --needed squashfs-tools libisoburn libarchive
# or Debian/Ubuntu: sudo apt install squashfs-tools xorriso libarchive-tools

bash make-autoinstall-iso.sh archlinux-2026.09.01-x86_64.iso
```

This produces `archlinux-autoinstall-auto.iso`. Mount it as the VM CD, boot, and **walk away** — installation runs by itself and powers off when done.
产出 `archlinux-autoinstall-auto.iso`，挂到虚拟机光驱，开机即全自动安装，装完自动关机。

---

## After install / 安装完成后

- Login: `arch` / `123456`
- The `arch` user has passwordless sudo (needed for AUR helpers; remove `/etc/sudoers.d/99-autoinstall` later if you want)
- 登录：`arch` / `123456`
- 用户 `arch` 带免密 sudo（供 AUR 工具用；想取消就删掉 `/etc/sudoers.d/99-autoinstall`）

**Change your passwords first / 建议先改密码：**
```bash
passwd          # change user password / 改用户密码
sudo passwd     # change root password / 改 root 密码
```

---

## Troubleshooting / 故障排查

| Symptom / 现象 | Fix / 处理 |
|---|---|
| No network during install / 安装时无网络 | Set VM network to NAT, retry / 虚拟机网络设为 NAT 后重试 |
| Stops at `Proceed with installation? [Y/n]` | Confirm you're running the latest `autoinstall.sh` (auto-confirm is built in) / 确认用的是最新脚本（已内置自动确认） |
| Boots to tty instead of desktop / 开机进 tty 而不是桌面 | The desktop install failed. Log in, check `/root/autoinstall.log` and `/root/nyxuri-install.log`, then reinstall the desktop manually / 桌面安装失败了，登录后看 `/root/autoinstall.log` 和 `/root/nyxuri-install.log`，手动补装桌面 |
| `error: target not found: open-vm-tools-desktop` | That package no longer exists. Use `open-vm-tools` only (already fixed in this script) / 该包已废弃，本脚本已改用 `open-vm-tools` |
| Boot menu shows no Arch entry / 引导项里没有 Arch | Make sure the VM firmware matches the partition table (UEFI+GPT or BIOS+MBR), and remove the ISO before first boot / 确认固件与分区表一致（UEFI+GPT 或 BIOS+MBR），首次开机前移除 ISO |

---

## Choosing a different desktop / 换桌面

```bash
DESKTOP=gnome bash autoinstall.sh   # GNOME / 官方推荐（默认）
DESKTOP=xfce bash autoinstall.sh     # light, classic / 经典轻量
DESKTOP=nyxuri bash autoinstall.sh  # Niri + Material You / 实验性
```

---

## Disclaimer / 免责声明

This script **erases the entire target disk**. Use it only on virtual machines you can afford to lose. The authors are not responsible for data loss.
本脚本会**清空整块目标磁盘**，请只在可丢弃数据的虚拟机上使用。因误操作造成的数据损失，作者概不负责。

## License / 许可证

MIT
