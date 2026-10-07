#!/bin/bash
# =============================================================
#  Arch Linux 一键自动安装脚本
#  (GNOME/XFCE/Niri 桌面 + 网络自启 + VMware增强 + 中文字体)
#
#  ⚠️ 危险警告：本脚本会【格式化并清空】 $DISK 整块磁盘，
#     请确认目标磁盘上没有需要保留的数据！
#
#  可选桌面：DESKTOP=gnome   （默认，GNOME官方仓库稳定）
#           DESKTOP=xfce   （备选，经典XFCE桌面）
#           DESKTOP=nyxuri （实验性，Niri Material You）
# =============================================================
set -euo pipefail

# ------------------ 可修改配置区（按需修改） ------------------
DISK="${DISK:-/dev/sda}"
MACHINE_NAME="${MACHINE_NAME:-arch}"
USERNAME="${USERNAME:-arch}"
PASSWORD="${PASSWORD:-123456}"
ROOT_PASSWORD="${ROOT_PASSWORD:-123456}"
TIMEZONE="${TIMEZONE:-Asia/Shanghai}"
DESKTOP="${DESKTOP:-gnome}"              # gnome | xfce | nyxuri
MIRROR_URL="${MIRROR_URL:-https://mirrors.aliyun.com/archlinux/\$repo/os/\$arch}"
NYXURI_BOOTSTRAP="${NYXURI_BOOTSTRAP:-https://gh-proxy.org/https://raw.githubusercontent.com/ech678/Nyxuri/main/install.sh}"
# -------------------------------------------------------------

LOG=/tmp/autoinstall.log
exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo " Arch Linux 一键安装开始  时间: $(date '+%F %T')"
echo " 目标磁盘: $DISK    主机名: $MACHINE_NAME    用户: $USERNAME"
echo " 桌面方案: $DESKTOP"
echo "============================================================"

if [ ! -d /run/archiso ] && [ ! -f /etc/arch-release ]; then
    echo "❌ 错误：此脚本只能在 Arch Live(archiso) 安装环境中运行！"
    exit 1
fi
if mountpoint -q /mnt; then
    echo "❌ 错误：/mnt 已被挂载，请先执行 umount -R /mnt"
    exit 1
fi
if [ ! -b "$DISK" ]; then
    echo "❌ 错误：磁盘 $DISK 不存在（可用 lsblk 查看实际磁盘名）"
    exit 1
fi

echo "==> [1/7] 等待网络就绪 ..."
for nic in /sys/class/net/*; do
    n="${nic##*/}"
    case "$n" in lo|*) ip link set "$n" up >/dev/null 2>&1 || true ;; esac
done
if command -v dhcpcd >/dev/null 2>&1; then
    dhcpcd -b >/dev/null 2>&1 || true
    systemctl start dhcpcd >/dev/null 2>&1 || true
fi
if command -v nmcli >/dev/null 2>&1; then
    nmcli device connect ens33 >/dev/null 2>&1 || true
    nmcli device connect eth0  >/dev/null 2>&1 || true
fi
network_ok=0
for _ in $(seq 1 60); do
    if ping -c1 -W2 223.5.5.5 >/dev/null 2>&1; then network_ok=1; break; fi
    sleep 2
done
if [ "$network_ok" -ne 1 ]; then
    echo "❌ 错误：网络不通，请检查虚拟机网络设置为 NAT 后重试"
    exit 1
fi
echo "==> 网络已就绪"

echo "==> [2/7] 配置国内镜像源 & 同步时间"
printf 'Server = %s\n' "$MIRROR_URL" > /etc/pacman.d/mirrorlist
timedatectl set-ntp true || true

echo "==> [3/7] 分区 $DISK（整盘清空）"
if [ -d /sys/firmware/efi ]; then
    FIRMWARE=UEFI
    echo "    检测到 UEFI 固件，使用 GPT 分区"
    sgdisk --zap-all "$DISK"
    sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:EFI "$DISK"
    sgdisk --new=2:0:0    --typecode=2:8304 --change-name=2:ROOT "$DISK"
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
else
    FIRMWARE=BIOS
    echo "    检测到 BIOS 固件，使用 MBR 分区"
    parted -s "$DISK" mklabel msdos
    parted -s "$DISK" mkpart primary ext4 1MiB 100%
    parted -s "$DISK" set 1 boot on
    EFI_PART=""
    ROOT_PART="${DISK}1"
fi
partprobe "$DISK" || true
sleep 3

echo "==> [4/7] 格式化分区"
if [ "$FIRMWARE" = "UEFI" ]; then
    mkfs.fat -F32 "$EFI_PART"
fi
mkfs.ext4 -F -L ARCHROOT "$ROOT_PART"

echo "==> 挂载分区"
mount "$ROOT_PART" /mnt
if [ -n "$EFI_PART" ]; then
    mount --mkdir "$EFI_PART" /mnt/boot
fi

echo "==> [5/7] pacstrap 安装基础系统（视网速需数分钟，请耐心等待）"
sed -i 's/^#NoConfirm/NoConfirm/' /etc/pacman.conf || true
pacstrap -K /mnt base linux linux-firmware base-devel sudo networkmanager vim

echo "==> 生成 fstab"
genfstab -U /mnt >> /mnt/etc/fstab

rm -f /mnt/etc/resolv.conf
echo "nameserver 223.5.5.5" > /mnt/etc/resolv.conf

echo "==> [6/7] chroot 配置系统（时区/语言/用户/桌面/引导）"
arch-chroot /mnt /bin/bash <<CHROOT
set -e
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc || true
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/^#zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=zh_CN.UTF-8" > /etc/locale.conf
echo "$MACHINE_NAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $MACHINE_NAME.localdomain $MACHINE_NAME
HOSTS
echo "root:$ROOT_PASSWORD" | chpasswd
if ! id "$USERNAME" >/dev/null 2>&1; then
    useradd -m -G wheel "$USERNAME"
fi
echo "$USERNAME:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-autoinstall
chmod 440 /etc/sudoers.d/99-autoinstall
echo "==> 安装通用组件"
pacman -S --noconfirm python git curl open-vm-tools \
    noto-fonts-cjk noto-fonts-emoji \
    fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-gtk fcitx5-qt
systemctl enable NetworkManager vmtoolsd vmware-vmblock-fuse 2>/dev/null || true
cat > /etc/environment <<ENV
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
ENV
if [ "$DESKTOP" = "nyxuri" ]; then
    echo "==> 安装 Nyxuri (Niri Material You) 桌面"
    NYXURI_STATE=1
    if timeout 5400 sudo -H -u "$USERNAME" bash -c "cd /home/$USERNAME && curl -fsSL --connect-timeout 10 '$NYXURI_BOOTSTRAP' -o nyxuri-install.sh && bash nyxuri-install.sh install full </dev/null" >/tmp/nyxuri-install.log 2>&1; then
        echo "==> Nyxuri 安装成功"
    else
        echo "⚠️  Nyxuri 安装未完成或部分失败"
        if command -v niri >/dev/null 2>&1; then
            NYXURI_STATE=0
        else
            NYXURI_STATE=2
        fi
    fi
    if [ "\$NYXURI_STATE" -ne 2 ]; then
        echo "==> 配置 greetd 自动登录 (niri)"
        pacman -S --noconfirm greetd
        cat > /usr/local/bin/nyxuri-session <<SESSION
#!/bin/bash
if command -v niri-session >/dev/null 2>&1; then
    exec niri-session
else
    exec niri
fi
SESSION
        chmod +x /usr/local/bin/nyxuri-session
        mkdir -p /etc/greetd
        cat > /etc/greetd/config.toml <<TOML
[terminal]
vt = 1
[default_session]
user = "$USERNAME"
command = "/usr/local/bin/nyxuri-session"
TOML
        systemctl enable greetd
    fi
elif [ "$DESKTOP" = "xfce" ]; then
    echo "==> 安装 XFCE 桌面"
    pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
    systemctl enable lightdm
elif [ "$DESKTOP" = "gnome" ]; then
    echo "==> 安装 GNOME 桌面"
    pacman -S --noconfirm gnome gdm
    systemctl enable gdm
else
    echo "❌ 未知桌面方案: $DESKTOP"
    exit 1
fi
echo "==> 安装 GRUB 引导"
pacman -S --noconfirm grub efibootmgr
if [ -d /sys/firmware/efi ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
    grub-install --target=i386-pc "$DISK"
fi
grub-mkconfig -o /boot/grub/grub.cfg
echo "==> chroot 配置完成"
CHROOT

echo "==> [7/7] 保存日志并卸载"
cp "$LOG" /mnt/root/autoinstall.log 2>/dev/null || true
[ -f /mnt/tmp/nyxuri-install.log ] && cp /mnt/tmp/nyxuri-install.log /mnt/root/nyxuri-install.log 2>/dev/null || true
umount -R /mnt || true

echo ""
echo "============================================================"
echo " ✅  一键安装完成！"
echo "     主机名: $MACHINE_NAME"
echo "     用户:   $USERNAME / $PASSWORD"
echo "     root:   $ROOT_PASSWORD"
echo "     桌面:   $DESKTOP"
echo "     安装日志已保存到系统内 /root/autoinstall.log"
echo "     系统将在 10 秒后自动关机，请移除安装ISO后重新开机"
echo "============================================================"
sync
sleep 10
poweroff
