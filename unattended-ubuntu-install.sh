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
ENV_FILE="./.env"

# Step 1: Load environment variables
if [[ -f "$ENV_FILE" ]]; then
    echo "Loading environment variables from $ENV_FILE..."
    source "$ENV_FILE"
else
    echo "Error: .env file not found. Please create a .env file with the required variables."
    exit 1
fi

# Validate required variables
if [[ -z "$PRESEED_USERNAME" || -z "$PRESEED_PASSWORD" ]]; then
    echo "Error: PRESEED_USERNAME or PRESEED_PASSWORD is not set in the .env file."
    exit 1
fi

# Step 2: Create necessary directories
echo "Creating $GRML_DIR directory if it doesn't exist..."
mkdir -p $GRML_DIR

# Step 3: Download the latest Ubuntu LTS ISO
echo "Downloading the latest Ubuntu LTS ISO..."
wget -nc -O "$ISO_PATH" https://releases.ubuntu.com/noble/ubuntu-24.04.1-desktop-amd64.iso

# Step 4: Create a preseed file for unattended installation
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
d-i netcfg/get_hostname string $PRESEED_USERNAME
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
d-i passwd/user-fullname string $PRESEED_USERNAME
d-i passwd/username string $PRESEED_USERNAME
d-i passwd/user-password password $PRESEED_PASSWORD
d-i passwd/user-password-again password $PRESEED_PASSWORD

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

echo "Identifying boot partition and GRUB configuration directory..."
BOOT_PARTITION=$(df /boot | tail -1 | awk '{print $1}')
GRUB_CONFIG_DIR="/boot/grub"
ISO_GRUB_ENTRY_NAME="Install Ubuntu LTS Unattended"

# Validate required paths
if [[ ! -f "$ISO_PATH" ]]; then
    echo "Error: ISO file not found at $ISO_PATH. Exiting."
    exit 1
fi
if [[ ! -f "$PRESEED_PATH" ]]; then
    echo "Error: Preseed file not found at $PRESEED_PATH. Exiting."
    exit 1
fi

echo "Updating GRUB configuration to include the Ubuntu LTS ISO..."

GRUB_CUSTOM_FILE="$GRUB_CONFIG_DIR/custom.cfg"

cat > "$GRUB_CUSTOM_FILE" <<EOF
menuentry "$ISO_GRUB_ENTRY_NAME" {
    set isofile=$ISO_PATH
    loopback loop $isofile
    linux (loop)/casper/vmlinuz boot=casper auto=true priority=critical file=$PRESEED_PATH
    initrd (loop)/casper/initrd
}
EOF

echo "Custom GRUB entry added to $GRUB_CUSTOM_FILE."

echo "Updating GRUB to apply changes..."
update-grub || grub-mkconfig -o "$GRUB_CONFIG_DIR/grub.cfg"

echo "GRUB configuration updated successfully. Reboot and select '$ISO_GRUB_ENTRY_NAME' to start the unattended installation."

# Step 6: Configure GRUB to boot automatically into "Install Ubuntu LTS Unattended"
echo "Configuring GRUB to auto-select 'Install Ubuntu LTS Unattended'..."
DEFAULT_ENTRY="Install Ubuntu LTS Unattended"

# Find the GRUB menu entry index
ENTRY_INDEX=$(sudo grep -A100 submenu /boot/grub/grub.cfg | grep -n "$DEFAULT_ENTRY" | awk -F':' '{print $1-1}')

if [[ -z "$ENTRY_INDEX" ]]; then
    echo "Error: Could not determine the GRUB entry for '$DEFAULT_ENTRY'. Ensure the GRUB configuration is correct."
    exit 1
fi

# Set the GRUB default to this entry
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT='"$ENTRY_INDEX"'/' /etc/default/grub

# Set GRUB timeout for auto-selection
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub

# Update GRUB
update-grub

echo "Setup complete! The system will automatically boot into 'Install Ubuntu LTS Unattended' on the next restart."
sudo reboot
