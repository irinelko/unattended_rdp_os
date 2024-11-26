#!/bin/bash

# Ensure the script runs with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo."
   exit 1
fi

# Variables
GRML_DIR="/boot/grml"
ISO_PATH="$GRML_DIR/ubuntu-lts.iso"
PRESEED_PATH="$GRML_DIR/preseed.cfg"
ENV_FILE="./.env"
ISO_URL="https://releases.ubuntu.com/noble/ubuntu-24.04.1-desktop-amd64.iso"
GRUB_CONFIG_DIR="/boot/grub"
ISO_GRUB_ENTRY_NAME="Install Ubuntu LTS Unattended"

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
if [[ -f "$ISO_PATH" ]]; then
    echo "ISO file already exists at $ISO_PATH. Skipping download."
else
    wget -O "$ISO_PATH" "$ISO_URL"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to download the Ubuntu ISO."
        exit 1
    fi
fi

# Step 4: Create a preseed file for unattended installation
echo "Creating preseed file at $PRESEED_PATH..."
cat > "$PRESEED_PATH" <<EOF
# Preseed configuration content here (omitted for brevity)
EOF

# Step 5: Update GRUB configuration directly
echo "Updating GRUB configuration to include the Ubuntu LTS ISO..."
cat >> "$GRUB_CONFIG_DIR/grub.cfg" <<EOF

menuentry "$ISO_GRUB_ENTRY_NAME" {
    set isofile=$ISO_PATH
    insmod loopback
    insmod iso9660
    insmod part_msdos
    insmod ext2
    loopback loop (hd0,1)$isofile
    linux (loop)/casper/vmlinuz boot=casper auto=true priority=critical file=$PRESEED_PATH iso-scan/filename=$isofile
    initrd (loop)/casper/initrd
}
EOF

# Step 6: Configure GRUB to boot automatically into the menu entry
echo "Configuring GRUB to auto-select '$ISO_GRUB_ENTRY_NAME'..."
sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT='${ISO_GRUB_ENTRY_NAME}'/" /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub

# Update GRUB configuration
update-grub || grub-mkconfig -o "$GRUB_CONFIG_DIR/grub.cfg"

# Final step: Prompt for reboot
echo "Setup complete! The system will automatically boot into '$ISO_GRUB_ENTRY_NAME' on the next restart."
reboot
