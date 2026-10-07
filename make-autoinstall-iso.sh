#!/bin/bash
# =============================================================
# 制作"开机全自动安装ISO"（零操作版）构建脚本
# 运行环境：任意 Linux（Arch Live 安装环境 / Debian / Ubuntu 均可）
#   需要：squashfs-tools + xorriso + libarchive(bsdtar)
#   Arch Live 环境若缺少可先装：pacman -S squashfs-tools libisoburn libarchive
#   Debian/Ubuntu：sudo apt install squashfs-tools xorriso libarchive-tools
#
# 用法：
#   bash make-autoinstall-iso.sh [原版ISO路径] [输出ISO路径]
#   例：bash make-autoinstall-iso.sh archlinux-2026.09.01-x86_64.iso
# 产出：archlinux-autoinstall-auto.iso
#   把它挂到虚拟机光驱启动 -> 全自动安装(GNOME桌面) -> 自动关机
# =============================================================
set -euo pipefail

SRC_ISO="${1:-archlinux-2026.09.01-x86_64.iso}"
OUT_ISO="${2:-archlinux-autoinstall-auto.iso}"
SCRIPT="$(cd "$(dirname "$0")" && pwd)/autoinstall.sh"

WORK="$(mktemp -d /tmp/iso-build.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
ISO_DIR="$WORK/iso"
ROOT_DIR="$WORK/root"

[ -f "$SRC_ISO" ] || { echo "❌ 找不到原版ISO: $SRC_ISO"; exit 1; }
[ -f "$SCRIPT" ] || { echo "❌ 找不到 autoinstall.sh（请与本脚本放同一目录）"; exit 1; }

echo "==> [1/5] 解包原版ISO: $SRC_ISO"
mkdir -p "$ISO_DIR"
if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$SRC_ISO" -C "$ISO_DIR"
elif command -v 7z >/dev/null 2>&1; then
    7z x -y "$SRC_ISO" -o"$ISO_DIR" >/dev/null
else
    xorriso -osirrox on -indev "$SRC_ISO" -extract / "$ISO_DIR"
fi

SFS="$(find "$ISO_DIR" -name airootfs.sfs | head -1)"
[ -n "$SFS" ] || { echo "❌ 未找到 airootfs.sfs"; exit 1; }
echo "    找到: $SFS"
# 关键：bsdtar/libarchive 通常不导出 ISO 隐藏的 [BOOT] 引导镜像，
# 缺了它后面 append_partition 打包必然失败，这里提前拦截并给出替代解包法
if [ ! -f "$ISO_DIR/[BOOT]/2-Boot-NoEmul.img" ] || [ ! -f "$ISO_DIR/boot/syslinux/isolinux.bin" ]; then
    echo "❌ 解包不完整：缺少 [BOOT]/2-Boot-NoEmul.img 或 boot/syslinux/isolinux.bin"
    echo "   当前解包器未导出隐藏引导文件，请改用 xorriso 解包："
    echo "   rm -rf \"$ISO_DIR\" && xorriso -osirrox on -indev \"$SRC_ISO\" -extract / \"$ISO_DIR\""
    exit 1
fi

echo "==> [2/5] 解包 airootfs.sfs"
mkdir -p "$ROOT_DIR"
unsquashfs -d "$ROOT_DIR" "$SFS" >/dev/null

echo "==> [3/5] 注入一键安装脚本 + 自动运行服务"
cp "$SCRIPT" "$ROOT_DIR/root/autoinstall.sh"
chmod +x "$ROOT_DIR/root/autoinstall.sh"
cat > "$ROOT_DIR/etc/systemd/system/autoinstall.service" <<'EOF'
[Unit]
Description=Arch Linux One-Click Auto Installer (GNOME)
After=network-online.target
Wants=network-online.target
ConditionPathExists=/root/autoinstall.sh

[Service]
Type=oneshot
ExecStart=/bin/bash /root/autoinstall.sh
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF
mkdir -p "$ROOT_DIR/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/autoinstall.service "$ROOT_DIR/etc/systemd/system/multi-user.target.wants/autoinstall.service"

echo "==> [4/5] 重新打包 airootfs.sfs（需几分钟）"
# 保持与原镜像一致的压缩格式（默认 zstd）
COMP="$(unsquashfs -s "$SFS" 2>/dev/null | grep -i compression | head -1 | awk '{print $NF}')"
case "$COMP" in
    zstd|gzip|xz|lzo|lz4) : ;;
    *) COMP="zstd" ;;
esac
SFS2="$WORK/airootfs.sfs"
mksquashfs "$ROOT_DIR" "$SFS2" -comp "$COMP" -noappend -quiet
cp -f "$SFS2" "$SFS"
# 更新 sha512 校验
SFS_DIR="$(dirname "$SFS")"
( cd "$SFS_DIR" && sha512sum airootfs.sfs > airootfs.sha512 )
rm -f "$SFS_DIR/airootfs.sfs.cms.sig"   # 旧签名已失效；无校验参数时不影响引导

echo "==> [5/5] 重新生成ISO（保留 BIOS/UEFI 双引导）"
cd "$ISO_DIR"
# 说明：引导查找介质依靠 /boot/<uuid>.uuid 标记文件（已保留），无需复刻 PVD 时间
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "ARCH_AUTOINSTALL" \
    -appid "Arch Linux Live/Rescue CD" \
    -publisher "Arch Linux" \
    -preparer "prepared by mkarchiso" \
    -eltorito-boot boot/syslinux/isolinux.bin \
    -eltorito-catalog boot/syslinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -isohybrid-mbr boot/syslinux/isohdpfx.bin \
    --mbr-force-bootable \
    -partition_offset 16 \
    -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "[BOOT]/2-Boot-NoEmul.img" \
    -isohybrid-gpt-basdat \
    -eltorito-alt-boot \
    -e --interval:appended_partition_2:all:: \
    -no-emul-boot \
    -output "$OLDPWD/$OUT_ISO" \
    .

echo ""
echo "✅ 制作完成: $(cd "$OLDPWD" && pwd)/$OUT_ISO"
echo "   把它挂到虚拟机光驱 -> 开机全自动安装 -> 装完自动关机"
echo "   （默认账号 arch/123456，root/123456，可在 autoinstall.sh 顶部修改）"
