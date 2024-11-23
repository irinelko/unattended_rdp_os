#!/bin/bash

# Ensure the script runs with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo." 
   exit 1
fi

# Variables
GRML_DIR="/boot/grml"
ISO_PATH="$GRML_DIR/ubuntu-lts.iso"
PRESEED_PATH="/boot/grml/preseed.cfg"

# Step 1: Create necessary directories
echo "Creating $GRML_DIR directory if it doesn't exist..."
mkdir -p $GRML_DIR

# Step 2: Download the latest Ubuntu LTS ISO
echo "Downloading the latest Ubuntu LTS ISO..."
wget -O "$ISO_PATH" https://releases.ubuntu.com/$(wget -qO- https://releases.ubuntu.com/ | grep -oP '(?<=href=")[^"]+/' | grep -E '^2[0-9]+\.[0-9]+$' | sort -V | tail -1)/ubuntu-$(wget -qO- https://releases.ubuntu.com/ | grep -oP '(?<=href=")[^"]+/' | grep -E '^2[0-9]+\.[0-9]+$' | sort -V | tail -1)-desktop-amd64.iso

# Step 3: Create a preseed file for unattended installation
echo "Creating preseed file at $PRESEED_PATH..."
cat > "$PRESEED_PATH" <<EOF
# Localization
d-i debian-installer/language string en
d-i debian-installer/country string US
d-i debian-installer/locale string en_US.UTF-8
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/layoutcode string us

# Network Configuration
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string ubuntu
d-i netcfg/get_domain string localdomain

# Mirror Settings
d-i mirror/country string manual
d-i mirror/http/hostname string archive.ubuntu.com
d-i mirror/http/directory string /ubuntu
d-i mirror/http/proxy string

# Partitioning
d-i partman-auto/disk string /dev/sda
d-i partman-auto/method string regular
d-i partman-auto/expert_recipe string \
      root :: \
              5000 10000 1000000 ext4 \
                      $primary{ } $bootable{ } method{ format } format{ } \
                      use_filesystem{ } filesystem{ ext4 } \
                      mountpoint{ / } \
      .
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# User Setup
d-i passwd/root-login boolean false
d-i passwd/user-fullname string Ubuntu User
d-i passwd/username string ubuntu
d-i passwd/user-password password password
d-i passwd/user-password-again password password

# Bootloader
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true

# Package Selection
tasksel tasksel/first multiselect standard
d-i pkgsel/include string xrdp
d-i pkgsel/upgrade select safe-upgrade

# Finish Installation
d-i finish-install/reboot_in_progress note
EOF

# Step 4: Update GRUB with ISO and preseed configuration
echo "Updating GRUB configuration to include the Ubuntu LTS ISO..."
cat >> /etc/grub.d/40_custom <<EOF

menuentry "Install Ubuntu LTS Unattended" {
    set isofile="$ISO_PATH"
    loopback loop (hd0,1)$isofile
    linux (loop)/casper/vmlinuz boot=casper auto=true priority=critical file=$PRESEED_PATH
    initrd (loop)/casper/initrd
}
EOF

# Update GRUB
echo "Updating GRUB..."
update-grub

echo "Setup complete! Reboot and select 'Install Ubuntu LTS Unattended' from the GRUB menu."
