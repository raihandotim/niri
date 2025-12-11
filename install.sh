#!/bin/bash
set -e

echo "Available disks:"
lsblk
echo

### --- ASK FOR PARTITIONS ---
read -p "Enter EFI partition (ex: /dev/sda1): " EFIPART
read -p "Enter ROOT partition (ex: /dev/sda2): " ROOTPART

### --- ASK FOR USERNAME & PASSWORD ---
read -p "Enter new username: " USERNAME
echo "Enter password for $USERNAME:"
read -s USERPASS
echo
echo "Re-enter password:"
read -s USERPASS2
echo
if [[ "$USERPASS" != "$USERPASS2" ]]; then
    echo "Passwords do not match!"
    exit 1
fi

### --- FORMAT DISKS ---
mkfs.fat -F32 $EFIPART
mkfs.ext4 $ROOTPART
mount $ROOTPART /mnt
mkdir -p /mnt/boot
mount $EFIPART /mnt/boot

### --- FAST BANGLADESH MIRROR ---
echo "Server = http://mirror.xeonbd.com/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

### --- BASE INSTALL ---
pacstrap /mnt base base-devel linux linux-firmware linux-headers \
    efibootmgr vim grub networkmanager git sudo

genfstab -U /mnt >> /mnt/etc/fstab

### --- CHROOT CONFIGURATION ---
arch-chroot /mnt bash <<EOF

# --- LOCALE & TIME ---
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "archlinux" > /etc/hostname
timedatectl set-ntp true
timedatectl set-timezone Asia/Dhaka

# --- ROOT PASSWORD ---
echo "root:$USERPASS" | chpasswd

# --- ADD USER ---
useradd -m -G wheel $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# --- BOOTLOADER (UEFI) ---
grub-install --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# --- ENABLE SERVICES ---
systemctl enable NetworkManager
systemctl enable bluetooth

# --- PACMAN PACKAGE INSTALL ---
pacman -Sy --noconfirm \
  fish wmctrl waybar swaybg qt5-wayland qt6-wayland chromium \
  pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber \
  pavucontrol xdg-desktop-portal xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk xdg-utils polkit-kde-agent fuzzel \
  mpv vlc libreoffice-fresh ttf-nerd-fonts-symbols firefox gimp \
  bluez blueman ranger pcmanfm git noto-fonts brightnessctl grim \
  acpi kitty openbangla-keyboard sway swayidle swaylock

# --- INSTALL YAY ---
sudo -u $USERNAME git clone https://aur.archlinux.org/yay.git /home/$USERNAME/yay
cd /home/$USERNAME/yay
sudo -u $USERNAME makepkg -si --noconfirm

# --- INSTALL AUR PACKAGES ---
sudo -u $USERNAME yay -S --noconfirm niri nwg-look-git nomacs-aur

# --- SET FISH AS DEFAULT SHELL ---
chsh -s /usr/bin/fish $USERNAME

# --- OPENBANGLA KEYBOARD FOR WAYLAND ---
mkdir -p /home/$USERNAME/.config/environment.d
cat << OB > /home/$USERNAME/.config/environment.d/90-openbangla.conf
GTK_IM_MODULE=openbangla
QT_IM_MODULE=openbangla
XMODIFIERS=@im=openbangla
XKB_DEFAULT_LAYOUT=us,bd
XKB_DEFAULT_OPTIONS=grp:ctrl_space_toggle
OB
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

# --- AUTO-LOGIN ON TTY1 ---
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat << AL > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
AL
systemctl daemon-reexec
systemctl enable getty@tty1

# --- AUTO-START NIRI & WAYBAR ---
mkdir -p /home/$USERNAME/.config/systemd/user
cat << NS > /home/$USERNAME/.config/systemd/user/niri.service
[Unit]
Description=Start Niri Wayland Compositor
After=graphical.target

[Service]
ExecStart=/usr/bin/niri
Restart=always
Environment=WAYLAND_DISPLAY=wayland-0
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
NS
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/systemd

EOF

# --- COPY NIRI CONFIG FROM GITHUB ---
arch-chroot /mnt sudo -u "$USERNAME" bash <<EOF
cd /home/$USERNAME
git clone https://github.com/raihandotim/niri niri_repo
mkdir -p /home/$USERNAME/.config
cp -r niri_repo/* /home/$USERNAME/.config/
EOF

echo "✅ Installation complete. Reboot now to start Arch with Wayland, Niri, fish shell, and OpenBangla keyboard!"
