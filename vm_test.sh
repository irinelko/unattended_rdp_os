#!/bin/bash

# Ensure the script runs with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo." 
   exit 1
fi

# Step 1: Install necessary virtualization tools if not already installed
echo "Checking and installing necessary virtualization tools..."

# Install virt-manager, libvirt, and qemu-kvm if not installed
if ! command -v virt-manager &> /dev/null; then
    echo "virt-manager not found, installing..."
    apt update && apt install -y virt-manager libvirt-bin qemu-kvm
fi

if ! command -v libvirtd &> /dev/null; then
    echo "libvirtd not found, installing..."
    apt update && apt install -y libvirt-bin
fi

if ! command -v qemu-kvm &> /dev/null; then
    echo "qemu-kvm not found, installing..."
    apt update && apt install -y qemu-kvm
fi

# Step 2: Add user to the libvirt and kvm groups if not already done
USER=$(whoami)
if ! groups $USER | grep -q "\blibvirt\b"; then
    echo "Adding $USER to the libvirt group..."
    usermod -aG libvirt $USER
fi

if ! groups $USER | grep -q "\bkvm\b"; then
    echo "Adding $USER to the kvm group..."
    usermod -aG kvm $USER
fi

# Step 3: Restart the libvirt service to apply group changes
echo "Restarting libvirt service..."
systemctl restart libvirtd

# Step 4: Variables for VM creation
ISO_URL="https://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/debian-12.0.0-amd64-netinst.iso"
ISO_PATH="/var/lib/libvirt/images/debian-12.0.0-amd64-netinst.iso"
VM_NAME="Debian-VM"
VM_DISK_PATH="/var/lib/libvirt/images/debian-12.0.0.qcow2"
VM_MEMORY="4096"  # Memory in MB
VM_CPU="2"        # Number of CPUs
VM_STORAGE_SIZE="20G"  # Storage size in GB

# Step 5: Download the Debian ISO
echo "Downloading the Debian ISO..."
wget -O "$ISO_PATH" "$ISO_URL"

# Step 6: Create Virtual Machine using libvirt
echo "Creating Virtual Machine '$VM_NAME' with the Debian ISO..."

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
  --os-variant debian12.0 \
  --graphics spice \
  --console pty,target_type=serial \
  --noautoconsole \
  --boot cdrom \
  --wait -1

# Step 7: Set up cloud-init
echo "Setting up cloud-init..."

# Cloud-init script
cat > "$VM_NAME-cloud-init.cfg" <<EOF
#cloud-config
users:
  - name: debian
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(echo "password" | openssl passwd -1 -stdin) # Replace with a hashed password
ssh_pwauth: True
runcmd:
  - echo "Unattended installation started..."
EOF

# Step 8: Attach cloud-init config to the VM
virt-install \
  --name "$VM_NAME" \
  --ram "$VM_MEMORY" \
  --vcpus "$VM_CPU" \
  --disk path="$VM_DISK_PATH",size="$VM_STORAGE_SIZE" \
  --cdrom "$ISO_PATH" \
  --network network=default \
  --os-type linux \
  --os-variant debian12.0 \
  --graphics spice \
  --console pty,target_type=serial \
  --cloud-init "$VM_NAME-cloud-init.cfg" \
  --noautoconsole \
  --boot cdrom \
  --wait -1

# Step 9: Monitor installation progress
echo "The virtual machine is installing Debian. Monitor the console for progress."
virsh console "$VM_NAME"

# Final message
echo "Debian installation in the virtual machine should complete shortly. If you wish to access the VM, use the virt-manager interface."
sudo apt install -y virt-manager
virt-manager
