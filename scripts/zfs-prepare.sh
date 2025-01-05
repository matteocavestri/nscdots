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

# Function to prepare disks for Alpine Linux
prepare_disks_alpine() {
  echo "INFO: Preparing disks for Alpine Linux..."
  modprobe zfs
  zgenhostid -f 0x00bab10c
  zpool labelclear -f "$POOL_DISK"
  wipefs -a "$POOL_DISK"
  wipefs -a "$BOOT_DISK"
  sgdisk --zap-all "$POOL_DISK"
  sgdisk --zap-all "$BOOT_DISK"
  sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:ef00" "$BOOT_DISK"
  sgdisk -n "${POOL_PART}:0:-10m" -t "${POOL_PART}:bf00" "$POOL_DISK"
  mdev -s
}

# Function to prepare disks for Void Linux
prepare_disks_void() {
  echo "INFO: Preparing disks for Void Linux..."
  zgenhostid -f 0x00bab10c
  zpool labelclear -f "$POOL_DISK"
  wipefs -a "$POOL_DISK"
  wipefs -a "$BOOT_DISK"
  sgdisk --zap-all "$POOL_DISK"
  sgdisk --zap-all "$BOOT_DISK"
  sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:ef00" "$BOOT_DISK"
  sgdisk -n "${POOL_PART}:0:-10m" -t "${POOL_PART}:bf00" "$POOL_DISK"
}

# Function to configure ZFS pool and datasets
configure_zfs() {
  echo "INFO: Setting up ZFS pool and datasets..."
  echo "$DISK_KEY" >/etc/zfs/zroot.key
  chmod 000 /etc/zfs/zroot.key

  zpool create -f -o ashift=12 \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -O encryption=aes-256-gcm \
    -O keylocation=file:///etc/zfs/zroot.key \
    -O keyformat=passphrase \
    -o autotrim=on \
    -m none zroot "$POOL_DEVICE"

  zfs create -o mountpoint=none zroot/ROOT
  zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/${ID}
  zfs create -o mountpoint=/home zroot/home
  zpool set bootfs=zroot/ROOT/${ID} zroot
  zpool export zroot
}

# Function to import ZFS pool and prepare environment for Alpine Linux
import_zfs_and_prepare_alpine() {
  echo "INFO: Importing ZFS pool and preparing environment for Alpine Linux..."
  zpool import -N -R /mnt zroot
  zfs load-key -L prompt zroot
  zfs mount zroot/ROOT/${ID}
  zfs mount zroot/home
}

# Function to import ZFS pool and prepare environment for Void Linux
import_zfs_and_prepare_void() {
  echo "INFO: Importing ZFS pool and preparing environment for Void Linux..."
  zpool import -N -R /mnt zroot
  zfs load-key -L prompt zroot
  zfs mount zroot/ROOT/${ID}
  zfs mount zroot/home
  udevadm trigger
}

# Function to install Alpine Linux base system
install_alpine_base() {
  echo "INFO: Installing Alpine Linux base system..."
  apk --arch x86_64 -X http://dl-cdn.alpinelinux.org/alpine/latest-stable/main \
    -U --allow-untrusted --root /mnt --initdb add alpine-base

  cp /etc/hostid /mnt/etc
  cp /etc/resolv.conf /mnt/etc
  cp /etc/apk/repositories /mnt/etc/apk
  mkdir /mnt/etc/zfs
  cp /etc/zfs/zroot.key /mnt/etc/zfs

  mount --rbind /dev /mnt/dev
  mount --rbind /sys /mnt/sys
  mount --rbind /proc /mnt/proc
  echo "INFO: To proceed, run the following command:"
  echo "  chroot /mnt"
}

# Function to install Void Linux base system
install_void_base() {
  echo "INFO: Installing Void Linux base system..."
  XBPS_ARCH=x86_64 xbps-install \
    -Sy -R https://mirrors.servercentral.com/voidlinux/current \
    -r /mnt base-system wget

  cp /etc/hostid /mnt/etc
  mkdir /mnt/etc/zfs
  cp /etc/zfs/zroot.key /mnt/etc/zfs
  echo "INFO: To proceed, run the following command:"
  echo "  xchroot /mnt"
}

# Main execution block
clear
echo "Select the target Linux distribution:"
echo "1) Alpine Linux"
echo "2) Void Linux"
echo "Enter your choice (1/2):"
read -r INPUT_DISTRO
DISTRO_CHOICE="${INPUT_DISTRO:-}"

if [ "$DISTRO_CHOICE" -eq 1 ]; then
  ID="alpine"
elif [ "$DISTRO_CHOICE" -eq 2 ]; then
  ID="void"
else
  echo "ERROR: Invalid choice. Exiting."
  exit 1
fi

# Prompt user for required variables
prompt_var BOOT_DISK "Enter the boot disk (e.g., /dev/nvme0n1)" "/dev/nvme0n1"
prompt_var DISK_KEY "Enter the encryption passphrase for the ZFS pool" "SomeKeyphrase"

# Derived variables
BOOT_PART="1"
BOOT_DEVICE="${BOOT_DISK}p${BOOT_PART}"
POOL_DISK="$BOOT_DISK"
POOL_PART="2"
POOL_DEVICE="${POOL_DISK}p${POOL_PART}"

# Execute distribution-specific disk preparation
if [ "$ID" = "alpine" ]; then
  prepare_disks_alpine
elif [ "$ID" = "void" ]; then
  prepare_disks_void
fi

# Execute common functions
configure_zfs

# Execute distribution-specific functions
if [ "$ID" = "alpine" ]; then
  import_zfs_and_prepare_alpine
  install_alpine_base
elif [ "$ID" = "void" ]; then
  import_zfs_and_prepare_void
  install_void_base
fi

# Final instructions
echo "INFO: Pre-chroot setup completed successfully."
