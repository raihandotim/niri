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
echo "Server = https://mirror.xeonbd.com/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

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

###Enable bluetooth
systemctl enable bluetooth

### INSTALL ALL PACKAGES
pacman -Sy --noconfirm \
  niri fish wmctrl waybar qt5-wayland qt6-wayland chromium \
  pipewire pipewire-pulse pipewire-alsa pipewire-jack \
  wireplumber pavucontrol xdg-desktop-portal xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk xdg-utils polkit-kde-agent fuzzel \
  mpv vlc libreoffice-fresh ttf-nerd-fonts-symbols firefox gimp \
  bluez blueman nwg-look ranger pcmanfm git noto-fonts \
  brightnessctl grim acpi kitty

### TIME
timedatectl set-ntp true
timedatectl set-timezone Asia/Dhaka

### INSTALL yay
cd /home/$USERNAME
sudo -u $USERNAME git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u $USERNAME makepkg -si --noconfirm

EOF

### --- COPY NIRI CONFIG ---
arch-chroot /mnt sudo -u "$USERNAME" bash <<EOF
cd /home/$USERNAME
git clone https://github.com/raihandotim/niri niri_repo
mkdir -p /home/$USERNAME/.config
cp -r niri_repo/* /home/$USERNAME/.config/
EOF

echo "Installation complete. You may reboot now."
