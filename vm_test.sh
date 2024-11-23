#!/bin/bash

# Ensure the script runs with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo." 
   exit 1
fi

# Variables
ISO_URL="https://zorin.com/os/download/ (find correct URL)"
ISO_PATH="/var/lib/libvirt/images/zorin-os.iso"
VM_NAME="ZorinOS-VM"
VM_DISK_PATH="/var/lib/libvirt/images/zorin-os.qcow2"
VM_MEMORY="4096"  # Memory in MB
VM_CPU="2"        # Number of CPUs
VM_STORAGE_SIZE="20G"  # Storage size in GB

# Step 1: Download the Zorin OS ISO
echo "Downloading the Zorin OS ISO..."
wget -O "$ISO_PATH" "$ISO_URL"

# Step 2: Create a Virtual Machine using libvirt
echo "Creating Virtual Machine '$VM_NAME' with the Zorin OS ISO..."

# Create virtual disk for the VM
qemu-img create -f qcow2 "$VM_DISK_PATH" "$VM_STORAGE_SIZE"

# Create the VM with appropriate resources
virt-install \
  --name "$VM_NAME" \
  --ram "$VM_MEMORY" \
  --vcpus "$VM_CPU" \
  --disk path="$VM_DISK_PATH",size="$VM_STORAGE_SIZE" \
  --cdrom "$ISO_PATH" \
  --network network=default \
  --os-type linux \
  --os-variant generic \
  --graphics spice \
  --console pty,target_type=serial \
  --noautoconsole \
  --boot cdrom \
  --wait -1

# Step 3: Set up cloud-init or other automation scripts
echo "Setting up cloud-init (if applicable)..."
# If Zorin OS supports cloud-init, you can pass the configuration here.
# Otherwise, you may need to use a custom script to set the user credentials and other settings.
# Cloud-init script (for Ubuntu-based OS, may be applicable to Zorin OS)
cat > "$VM_NAME-cloud-init.cfg" <<EOF
#cloud-config
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(echo "password" | openssl passwd -1 -stdin) # Replace with a hashed password
ssh_pwauth: True
runcmd:
  - echo "Unattended installation started..."
EOF

# Step 4: Attach cloud-init config to the VM (if cloud-init is supported)
# This step may vary depending on how Zorin OS handles automation.
virt-install \
  --name "$VM_NAME" \
  --ram "$VM_MEMORY" \
  --vcpus "$VM_CPU" \
  --disk path="$VM_DISK_PATH",size="$VM_STORAGE_SIZE" \
  --cdrom "$ISO_PATH" \
  --network network=default \
  --os-type linux \
  --os-variant generic \
  --graphics spice \
  --console pty,target_type=serial \
  --cloud-init "$VM_NAME-cloud-init.cfg" \
  --noautoconsole \
  --boot cdrom \
  --wait -1

# Step 5: Monitor installation progress
echo "The virtual machine is installing Zorin OS. Monitor the console for progress."
virsh console "$VM_NAME"

# Final message
echo "Zorin OS installation in the virtual machine should complete shortly. If you wish to access the VM, use the virt-manager interface."
