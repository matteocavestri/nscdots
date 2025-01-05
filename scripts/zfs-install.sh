#!/bin/sh

# Function to prompt for user input and set variables
prompt_var() {
  VAR_NAME="$1"
  PROMPT_TEXT="$2"
  DEFAULT_VALUE="$3"
  echo "$PROMPT_TEXT [$DEFAULT_VALUE]:"
  read -r INPUT
  eval "$VAR_NAME=\"\${INPUT:-$DEFAULT_VALUE}\""
}

# Function to configure essential settings for Alpine Linux
configure_essential_settings_alpine() {
  echo "INFO: Configuring essential services for Alpine Linux..."
  rc-update add hwdrivers sysinit
  rc-update add networking
  rc-update add hostname
  apk add zfs zfs-lts zfs-scripts
  rc-update add zfs-import sysinit
  rc-update add zfs-mount sysinit
}

# Function to configure essential settings for Void Linux
configure_essential_settings_void() {
  echo "INFO: Configuring essential settings for Void Linux..."
  prompt_var TIMEZONE "Enter your timezone (e.g., Europe/Rome)" "UTC"
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime

  prompt_var KEYMAP "Enter your keymap (e.g., us)" "us"
  cat <<EOF >>/etc/rc.conf
KEYMAP="$KEYMAP"
HARDWARECLOCK="UTC"
EOF

  prompt_var ENCODING "Enter your encoding (e.g., en_US.UTF-8)" "en_US.UTF-8"
  cat <<EOF >>/etc/default/libc-locales
$ENCODING UTF-8
EOF
  xbps-reconfigure -f glibc-locales
}

# Function to configure initramfs for Alpine Linux
configure_initramfs_alpine() {
  echo "INFO: Configuring initramfs for Alpine Linux..."
  echo "/etc/hostid" >>/etc/mkinitfs/features.d/zfshost.files
  echo "/etc/zfs/zroot.key" >>/etc/mkinitfs/features.d/zfshost.files
  echo 'features="ata base keymap kms mmc scsi usb virtio nvme zfs zfshost"' >/etc/mkinitfs/mkinitfs.conf
  mkinitfs -c /etc/mkinitfs/mkinitfs.conf "$(ls /lib/modules)"
}

# Function to configure initramfs for Void Linux
configure_initramfs_void() {
  echo "INFO: Configuring initramfs for Void Linux..."
  cat <<EOF >/etc/dracut.conf.d/zol.conf
nofsck="yes"
add_dracutmodules+=" zfs "
omit_dracutmodules+=" btrfs "
install_items+=" /etc/zfs/zroot.key "
EOF
  xbps-install -Sy zfs
  zfs set org.zfsbootmenu:commandline="quiet" zroot/ROOT
  zfs set org.zfsbootmenu:keysource="zroot/ROOT/${ID}" zroot
}

# Function to configure EFI bootloader for Alpine Linux
configure_bootloader_alpine() {
  echo "INFO: Configuring EFI bootloader for Alpine Linux..."
  mkfs.vfat -F32 "$BOOT_DEVICE"
  cat <<EOF >>/etc/fstab
$BOOT_DEVICE /boot/efi vfat defaults 0 0
EOF
  mkdir -p /boot/efi
  mount /boot/efi
  apk add curl
  mkdir -p /boot/efi/EFI/zbm
  mkdir -p /boot/efi/EFI/BOOT
  curl -o /boot/efi/EFI/zbm/vmlinuz.EFI -L https://get.zfsbootmenu.org/efi
  curl -o /boot/efi/EFI/BOOT/BOOTX64.EFI -LJ https://get.zfsbootmenu.org/efi/recovery
  apk add refind@testing
  refind-install
  rm /boot/refind_linux.conf
  cat <<EOF >/boot/efi/EFI/BOOT/refind_linux.conf
"Boot default"  "quiet loglevel=0 zbm.skip"
"Boot to menu"  "quiet loglevel=0 zbm.show"
EOF
}

# Function to configure EFI bootloader for Void Linux
configure_bootloader_void() {
  echo "INFO: Configuring EFI bootloader for Void Linux..."
  mkfs.vfat -F32 "$BOOT_DEVICE"
  cat <<EOF >>/etc/fstab
$(blkid | grep "$BOOT_DEVICE" | cut -d ' ' -f 2) /boot/efi vfat defaults 0 0
EOF

  mkdir -p /boot/efi
  mount /boot/efi
  xbps-install -Sy zfsbootmenu gummiboot-efistub curl
  mkdir -p /boot/efi/EFI/BOOT

  # Replace ZFSBootMenu configuration
  rm /etc/zfsbootmenu/config.yaml
  cat <<EOF >/etc/zfsbootmenu/config.yaml
Global:
  ManageImages: true
  BootMountPoint: /boot/efi
Components:
  Enabled: false
EFI:
  ImageDir: /boot/efi/EFI/zbm
  Versions: false
  Enabled: true
Kernel:
  CommandLine: quiet loglevel=0
EOF
  generate-zbm

  curl -o /boot/efi/EFI/BOOT/BOOTX64.EFI -LJ https://get.zfsbootmenu.org/efi/recovery

  xbps-install -Sy refind
  refind-install
  rm /boot/refind_linux.conf

  cat <<EOF >/boot/efi/EFI/BOOT/refind_linux.conf
"Boot default"  "quiet loglevel=0 zbm.skip"
"Boot to menu"  "quiet loglevel=0 zbm.show"
EOF
}

# Main execution block
clear
echo "Select the target Linux distribution:"
echo "1) Alpine Linux"
echo "2) Void Linux"
echo "Enter your choice (1/2):"
read INPUT_DISTRO
DISTRO_CHOICE="${INPUT_DISTRO:-}"

if [ "$DISTRO_CHOICE" -eq 1 ]; then
  ID="alpine"
elif [ "$DISTRO_CHOICE" -eq 2 ]; then
  ID="void"
else
  echo "ERROR: Invalid choice. Exiting."
  exit 1
fi

prompt_var BOOT_DISK "Enter the boot disk (e.g., /dev/nvme0n1)" "/dev/nvme0n1"
BOOT_PART="1"
BOOT_DEVICE="${BOOT_DISK}p${BOOT_PART}"

# Set root password
echo "INFO: Please set the root password:"
passwd

if [ "$ID" = "alpine" ]; then
  configure_essential_settings_alpine
  configure_initramfs_alpine
  configure_bootloader_alpine
elif [ "$ID" = "void" ]; then
  configure_essential_settings_void
  configure_initramfs_void
  configure_bootloader_void
fi

# Final instructions
if [ "$ID" = "alpine" ]; then
  echo "INFO: In-chroot setup completed successfully for Alpine Linux."
  echo "Before rebooting, exit the chroot and run the following commands:"
  echo "  cut -f2 -d' ' /proc/mounts | grep ^/mnt | tac | while read i; do umount -l \$i; done"
  echo "  zpool export zroot"
  echo "Then, reboot the system."
elif [ "$ID" = "void" ]; then
  echo "INFO: In-chroot setup completed successfully for Void Linux."
  echo "Before rebooting, exit the chroot and run the following commands:"
  echo "  umount -n -R /mnt"
  echo "  zpool export zroot"
  echo "Then, reboot the system."
fi
