#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) != "0" ]]; then
    echo 'Script must be run as root or with sudo!'
    exit 1
fi

# === 1. Setup mesa COPR ===
echo -n "Adding mesa COPR repo (exotic-soc)... "
rpm-ostree override remove mesa* --install --idempotent \
    https://copr.fedorainfracloud.org/coprs/g/exotic-soc/bc250-mesa/repo/fedora-$(rpm -E %fedora)/g-exotic-soc-bc250-mesa-fedora-$(rpm -E %fedora).repo

# Tell the user they MUST reboot
echo "Mesa override added. Please reboot to apply Mesa changes."

# === 2. Set RADV_DEBUG globally ===
echo -n "Setting RADV_DEBUG=nocompute system-wide... "
if ! grep -q "RADV_DEBUG=nocompute" /etc/environment; then
    echo "RADV_DEBUG=nocompute" >> /etc/environment
fi

# === 3. Install build tools and governor ===
echo "Installing packages for GPU governor build..."
rpm-ostree install libdrm-devel cmake make gcc-c++ git

echo "You must reboot before continuing to complete package layering!"
read -p "Reboot now? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    systemctl reboot
    exit 0
else
    echo "Please reboot and rerun this script to finish building the governor."
    exit 0
fi

# === AFTER reboot, re-run this part manually ===
# git clone https://gitlab.com/mothenjoyer69/oberon-governor.git
# cd oberon-governor
# cmake .
# make
# sudo make install
# sudo cp ./oberon-governor.service /etc/systemd/system/
# sudo systemctl daemon-reexec
# sudo systemctl enable --now oberon-governor.service

# === 4. Modprobe settings ===
# These steps can be run now or after reboot

echo "options amdgpu sg_display=0" | tee /etc/modprobe.d/options-amdgpu.conf
echo 'nct6683' | tee /etc/modules-load.d/99-sensors.conf
echo 'options nct6683 force=true' | tee /etc/modprobe.d/options-sensors.conf

echo "Regenerating initrd..."
dracut --regenerate-all --force

# === 5. GRUB cleanup ===
echo "Cleaning GRUB from 'nomodeset' and 'amdgpu.sg_display=0'..."
sed -i 's/nomodeset//g' /etc/default/grub
sed -i 's/amdgpu\.sg_display=0//g' /etc/default/grub
grub2-mkconfig -o /etc/grub2.cfg

echo "Setup done. You should reboot now."
