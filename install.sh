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
while true; do
    read -s -p "Enter password for $USERNAME: " USERPASS
    echo
    read -s -p "Re-enter password: " USERPASS2
    echo
    [[ "$USERPASS" == "$USERPASS2" ]] && break
    echo "Passwords do not match, try again."
done

### --- HOSTNAME ---
HOSTNAME="archlinux"

### --- FORMAT DISKS ---
mkfs.fat -F32 $EFIPART
mkfs.ext4 $ROOTPART
mount $ROOTPART /mnt
mkdir -p /mnt/boot
mount $EFIPART /mnt/boot

### --- HTTPS MIRROR ---
echo "Server = https://mirror.xeonbd.com/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

### --- BASE INSTALL (pacstrap all packages including fish & niri) ---
pacstrap /mnt base base-devel linux linux-firmware linux-headers efibootmgr vim grub networkmanager git sudo fish niri swaybg waybar chromium mpv vlc libreoffice-fresh ttf-nerd-fonts-symbols firefox gimp ranger pcmanfm git noto-fonts brightnessctl grim acpi kitty pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber pavucontrol xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-utils polkit-kde-agent fuzzel qt5-wayland qt6-wayland

genfstab -U /mnt >> /mnt/etc/fstab

### --- CHROOT CONFIGURATION ---
arch-chroot /mnt bash <<EOF

# --- LOCALE & TIME ---
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
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

# --- ENABLE NETWORK MANAGER ---
systemctl enable NetworkManager

EOF

### --- COPY NIRI CONFIG TO USER HOME (after chroot) ---
mkdir -p /mnt/home/$USERNAME/.config
git clone https://github.com/raihandotim/niri /tmp/niri_repo
cp -r /tmp/niri_repo/* /mnt/home/$USERNAME/.config/
#chown -R $USERNAME:$USERNAME /mnt/home/$USERNAME/.config
rm -rf /tmp/niri_repo

echo "✅ Installation complete. Fish and Niri installed. GitHub Niri config copied to /home/$USERNAME/.config."
echo "You may reboot now."
