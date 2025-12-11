#!/bin/bash
set -e

echo "Available disks:"
lsblk
echo

### --- ASK FOR PARTITIONS ---
read -p "Enter EFI partition (ex: /dev/sda1): " EFIPART
read -p "Enter ROOT partition (ex: /dev/sda2): " ROOTPART

### --- ASK USERNAME & PASSWORD ---
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
    efibootmgr vim grub networkmanager git

genfstab -U /mnt >> /mnt/etc/fstab

### --- CHROOT CONFIGURATION ---
arch-chroot /mnt bash <<EOF

### LOCALE
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

### HOSTNAME
echo "archlinux" > /etc/hostname

### ROOT PASSWORD
echo "root:$USERPASS" | chpasswd

### ADD USER
useradd -m -G wheel $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd

### SUDO PERMISSION
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

### BOOTLOADER (UEFI)
grub-install --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

### ENABLE NETWORK MANAGER
systemctl enable NetworkManager
systemctl enable bluetooth

### --- OPENBANGLA KEYBOARD (WAYLAND ONLY) ---
pacman -Sy --noconfirm openbangla-keyboard

mkdir -p /etc/environment.d
cat << 'WAYLANDENV' > /etc/environment.d/90-openbangla.conf
GTK_IM_MODULE=openbangla
QT_IM_MODULE=openbangla
XMODIFIERS=@im=openbangla

# Keyboard layouts (US + Bangla)
XKB_DEFAULT_LAYOUT=us,bd

# Ctrl + Space to switch layout
XKB_DEFAULT_OPTIONS=grp:ctrl_space_toggle
WAYLANDENV

### --- INSTALL PACKAGES INTERACTIVELY ---
echo "Pacman will now install the following packages interactively:"
echo "niri fish wmctrl waybar swaybg qt5-wayland qt6-wayland chromium"
echo "pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber"
echo "pavucontrol xdg-desktop-portal xdg-desktop-portal-gnome"
echo "xdg-desktop-portal-gtk xdg-utils polkit-kde-agent fuzzel"
echo "mpv vlc libreoffice-fresh ttf-nerd-fonts-symbols firefox gimp"
echo "bluez blueman nwg-look ranger pcmanfm git noto-fonts"
echo "brightnessctl grim acpi kitty"
echo
echo "Pacman may ask for optional dependency selection."
read -p "Press Enter to continue..."

pacman -Sy niri fish wmctrl waybar swaybg qt5-wayland qt6-wayland chromium \
  pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber \
  pavucontrol xdg-desktop-portal xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk xdg-utils polkit-kde-agent fuzzel \
  mpv vlc libreoffice-fresh ttf-nerd-fonts-symbols firefox gimp \
  bluez blueman nwg-look ranger pcmanfm git noto-fonts \
  brightnessctl grim acpi kitty

### TIME
timedatectl set-ntp true
timedatectl set-timezone Asia/Dhaka

### --- INSTALL yay (AUR helper) ---
cd /home/$USERNAME
sudo -u $USERNAME git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u $USERNAME makepkg -si --noconfirm

### --- SET FISH AS DEFAULT SHELL ---
chsh -s /usr/bin/fish $USERNAME

### --- AUTO-LOGIN ON TTY1 ---
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat << AUTOLOGIN > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
AUTOLOGIN

systemctl daemon-reexec
systemctl enable getty@tty1

### --- AUTO-START NIRI ---
mkdir -p /home/$USERNAME/.config/systemd/user
cat << NIRISERVICE > /home/$USERNAME/.config/systemd/user/niri.service
[Unit]
Description=Start Niri Wayland Compositor

[Service]
ExecStart=/usr/bin/niri
Restart=always
Environment=WAYLAND_DISPLAY=wayland-0
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
NIRISERVICE

chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/systemd

systemctl --user enable niri.service

EOF

### --- COPY NIRI CONFIG ---
arch-chroot /mnt sudo -u "$USERNAME" bash <<EOF
cd /home/$USERNAME
git clone https://github.com/raihandotim/niri niri_repo
mkdir -p /home/$USERNAME/.config
cp -r niri_repo/* /home/$USERNAME/.config/
EOF

echo "Installation complete. You may reboot now."
