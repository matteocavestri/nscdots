#!/bin/sh

prompt_var() {
  VAR_NAME="$1"
  PROMPT_TEXT="$2"
  DEFAULT_VALUE="$3"
  echo "$PROMPT_TEXT [$DEFAULT_VALUE]:"
  read -r INPUT
  eval "$VAR_NAME=\"\${INPUT:-$DEFAULT_VALUE}\""
}

# Function to configure essential services
configure_services() {
  echo "Configuring essential services..."
  rc-update add hwdrivers sysinit
  rc-update add networking
  rc-update add hostname
  apk add zfs zfs-lts zfs-scripts
  rc-update add zfs-import sysinit
  rc-update add zfs-mount sysinit
}

# Function to configure initramfs for ZFS
configure_initramfs() {
  echo "Configuring initramfs for ZFS..."
  echo "/etc/hostid" >>/etc/mkinitfs/features.d/zfshost.files
  echo "/etc/zfs/zroot.key" >>/etc/mkinitfs/features.d/zfshost.files
  echo 'features="ata base keymap kms mmc scsi usb virtio nvme zfs zfshost"' >/etc/mkinitfs/mkinitfs.conf
  mkinitfs -c /etc/mkinitfs/mkinitfs.conf "$(ls /lib/modules)"
}

# Function to configure EFI bootloader
configure_bootloader() {
  echo "Configuring EFI bootloader..."
  mkfs.vfat -F32 "$BOOT_DEVICE"
  cat <<EOF >>/etc/fstab
$BOOT_DEVICE /boot/efi vfat defaults 0 0
EOF
  mkdir -p /boot/efi
  mount /boot/efi
  apk add curl
  mkdir -p /boot/efi/EFI/ZBM
  mkdir -p /boot/efi/EFI/BOOT
  curl -o /boot/efi/EFI/ZBM/VMLINUZ.EFI -L https://get.zfsbootmenu.org/efi
  cp /boot/efi/EFI/ZBM/VMLINUZ.EFI /boot/efi/EFI/ZBM/VMLINUZ-BACKUP.EFI
  curl -o /boot/efi/EFI/BOOT/BOOTX64.EFI -LJ https://get.zfsbootmenu.org/efi/recovery
  apk add refind@testing
  refind-install
  rm /boot/refind_linux.conf

  cat <<EOF >/boot/efi/EFI/ZBM/refind_linux.conf
"Boot default"  "quiet loglevel=0 zbm.skip"
"Boot to menu"  "quiet loglevel=0 zbm.show"
EOF
}

# Main execution block
echo "Starting in-chroot setup..."

prompt_var BOOT_DISK "Enter the boot disk (e.g., /dev/nvme0n1)" "/dev/nvme0n1"
BOOT_PART="1"
BOOT_DEVICE="${BOOT_DISK}p${BOOT_PART}"
# Set root password
echo "Please set the root password:"
passwd

# Execute functions
configure_services
configure_initramfs
configure_bootloader

# Final instructions
echo "In-chroot setup completed successfully."
echo "Before rebooting, exit the chroot and run the following commands:"
echo "  cut -f2 -d' ' /proc/mounts | grep ^/mnt | tac | while read i; do umount -l \$i; done"
echo "  zpool export zroot"
echo "Then, reboot the system."
