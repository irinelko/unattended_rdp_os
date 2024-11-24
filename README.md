# Run
```
sudo wget --no-cache -qO- https://raw.githubusercontent.com/irinelko/unattended_rdp_os/refs/heads/main/unattended-ubuntu-install.sh | sudo bash
```

# Test
Run this command in your terminal to test the script on VM.
```
sudo wget --no-cache -qO- https://raw.githubusercontent.com/irinelko/unattended_rdp_os/refs/heads/main/test/vm_install.sh | sudo bash
```

# Summary of what the script does

1. Downloads the Latest Ubuntu LTS ISO:
The script identifies and downloads the most recent Long-Term Support (LTS) version of Ubuntu directly from the official Ubuntu releases website.
2. Prepares an Unattended Installation Configuration:
It creates a "preseed" file, which automates the Ubuntu installation process. This file includes all necessary settings, such as:
Language and keyboard preferences.
Network configuration.
Disk partitioning to erase and use the entire disk.
User account details (username, password, etc.).
Automatic package installation, including the XRDP service for remote desktop connections.
3. Keeps Sensitive Data Separate:
The script reads sensitive data, like the username and password, from a .env file to keep them out of the main script. This makes the script safer to share or store publicly.
4. Sets Up GRUB Bootloader:
It updates the GRUB bootloader to include a new menu option for booting directly into the downloaded Ubuntu ISO with the preseed configuration for unattended installation.
Configures GRUB to automatically select this menu option on the next system boot and proceed without user input after a 5-second timeout.
5. Automates Everything:
The entire process—from downloading the ISO, configuring the installation, and preparing the bootloader—is done automatically without manual intervention.
6. Final Steps:
The machine will boot into the installer, and the Ubuntu installation will proceed completely unattended.
This script is ideal for automating the installation of Ubuntu on a remote server or machine, ensuring it is ready for use with minimal interaction.
