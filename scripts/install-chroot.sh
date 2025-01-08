#!/bin/sh

# EDITED FILES:
#
# /etc/rc.conf
# /etc/localtime
# /etc/default/libc-locales
# /etc/zfsbootmenu/config.yaml
# /boot/efi/EFI/BOOT/refind_linux.conf
#
# These files are edited by the script, you can find
them in the appropriate directory in this repo

# Function to configure essential settings for Void Linux
configure_essential_settings_void() {
  echo "INFO: Configuring essential settings for Void Linux..."
  echo "Enter your timezone (e.g., Europe/Rome) [UTC]:"
  read -r TIMEZONE
  TIMEZONE="${TIMEZONE:-UTC}"
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime

  echo "Enter your keymap (e.g., us) [us]:"
  read -r KEYMAP
  KEYMAP="${KEYMAP:-us}"
  cat <<EOF >>/etc/rc.conf
KEYMAP="$KEYMAP"
HARDWARECLOCK="UTC"
EOF

  echo "Enter your encoding (e.g., en_US.UTF-8) [en_US.UTF-8]:"
  read -r ENCODING
  ENCODING="${ENCODING:-en_US.UTF-8}"
  cat <<EOF >>/etc/default/libc-locales
$ENCODING UTF-8
EOF
  xbps-reconfigure -f glibc-locales
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

# Function to configure EFI bootloader for Void Linux
configure_bootloader_void() {
  echo "INFO: Configuring EFI bootloader for Void Linux..."

  echo "INFO: Detecting partitions..."
  lsblk
  echo "Enter the boot partitions separated by space (e.g., /dev/sda1 /dev/sdb1):"
  read -r BOOT_PARTITIONS

  if [ -z "$BOOT_PARTITIONS" ]; then
    echo "ERROR: No boot partitions provided. Exiting."
    exit 1
  fi

  BOOT_PART_COUNT=$(echo "$BOOT_PARTITIONS" | wc -w)

  if [ "$BOOT_PART_COUNT" -eq 1 ]; then
    BOOT_DEVICE="$BOOT_PARTITIONS"
    mkfs.vfat -F32 "$BOOT_DEVICE"
    cat <<EOF >>/etc/fstab
$(blkid | grep "$BOOT_DEVICE" | cut -d ' ' -f 2) /boot/efi vfat defaults 0 0
EOF
    mkdir -p /boot/efi
    mount /boot/efi
  else
    echo "INFO: Creating RAID 1 for boot partitions..."
    mdadm --create --verbose --level 1 --metadata 1.0 \
      --homehost any --raid-devices "$BOOT_PART_COUNT" /dev/md/esp \
      $BOOT_PARTITIONS
    mdadm --assemble --scan
    mdadm --detail --scan >>/etc/mdadm.conf

    mkfs.vfat -F32 /dev/md/esp
    cat <<EOF >>/etc/fstab
/dev/md/esp /boot/efi vfat defaults 0 0
EOF
    mkdir -p /boot/efi
    mount /boot/efi
  fi

  xbps-install -Sy zfsbootmenu gummiboot-efistub curl
  mkdir -p /boot/efi/EFI/BOOT

  # Replace ZFSBootMenu configuration
  rm /etc/zfsbootmenu/config.yaml
  cat <<EOF >>/etc/zfsbootmenu/config.yaml
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

  cat <<EOF >>/boot/efi/EFI/BOOT/refind_linux.conf
"Boot default"  "quiet loglevel=0 zbm.skip"
"Boot to menu"  "quiet loglevel=0 zbm.show"
EOF
}

# Function to create an administrative user
create_admin_user() {
  echo "Enter the username for the administrator account:"
  read -r ADMIN_USER
  if [ -z "$ADMIN_USER" ]; then
    echo "ERROR: No username provided. Exiting."
    exit 1
  fi
  useradd -m -G wheel "$ADMIN_USER"
  echo "Set password for $ADMIN_USER:"
  passwd "$ADMIN_USER"
}

# Main execution block
clear

# Set root password
echo "INFO: Please set the root password:"
passwd

configure_essential_settings_void
configure_initramfs_void
configure_bootloader_void
create_admin_user

# Final instructions
echo "INFO: In-chroot setup completed successfully for Void Linux."
echo "Before rebooting, exit the chroot and run the following commands:"
echo "  umount -n -R /mnt"
echo "  zpool export zroot"
echo "Then, reboot the system."
