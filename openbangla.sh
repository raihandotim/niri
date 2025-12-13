#!/bin/bash
# Automated fcitx5 + OpenBangla install for Arch Linux (without environment/autostart)
# Run this script as a regular user, not root

set -e

# Ask for username if running from Arch ISO
read -p "Enter your regular username: " USERNAME

echo "Updating system..."
sudo pacman -Syu --noconfirm

echo "Installing base packages for building AUR packages..."
sudo pacman -S --noconfirm base-devel git

# Install yay if not already installed
if ! command -v yay &> /dev/null
then
    echo "Installing yay..."
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    cd "$tmpdir/yay"
    makepkg -si --noconfirm
    cd ~
    rm -rf "$tmpdir"
else
    echo "yay is already installed."
fi

echo "Installing fcitx5 core packages..."
sudo pacman -S --noconfirm fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-mozc

echo "Installing OpenBangla Keyboard..."
sudo -u "$USERNAME" yay -S --noconfirm fcitx5-openbangla

echo "✅ Installation completed!"
echo "You can configure fcitx5 manually if needed."
