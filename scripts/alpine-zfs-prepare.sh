#!/bin/sh
set -e

# Function to prompt for user input and set variables
prompt_var() {
  VAR_NAME="$1"
  PROMPT_TEXT="$2"
  DEFAULT_VALUE="$3"
  echo "$PROMPT_TEXT [$DEFAULT_VALUE]:"
  read -r INPUT
  eval "$VAR_NAME=\"\${INPUT:-$DEFAULT_VALUE}\""
}

# Function to configure Alpine repositories
configure_repositories() {
  echo "Configuring Alpine repositories..."
  cat <<EOF >/etc/apk/repositories
https://dl-cdn.alpinelinux.org/alpine/v3.21/main
https://dl-cdn.alpinelinux.org/alpine/v3.21/community
@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF
}

# Function to prepare disks
prepare_disks() {
  echo "Preparing disks..."
  modprobe zfs
  zpool labelclear -f "$POOL_DISK"
  wipefs -a "$POOL_DISK"
  wipefs -a "$BOOT_DISK"
  sgdisk --zap-all "$POOL_DISK"
  sgdisk --zap-all "$BOOT_DISK"
  sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:ef00" "$BOOT_DISK"
  sgdisk -n "${POOL_PART}:0:-10m" -t "${POOL_PART}:bf00" "$POOL_DISK"
  mdev -s
}

# Function to configure ZFS pool and datasets
configure_zfs() {
  echo "Setting up ZFS pool and datasets..."
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
    -o compatibility=openzfs-2.1-linux \
    -m none zroot "$POOL_DEVICE"

  zfs create -o mountpoint=none zroot/ROOT
  zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/alpine
  zfs create -o mountpoint=/home zroot/home
  zpool set bootfs=zroot/ROOT/alpine zroot
  zpool export zroot
}

# Function to import ZFS pool and prepare environment
import_zfs_and_prepare() {
  echo "Importing ZFS pool and preparing environment..."
  zpool import -N -R /mnt zroot
  zfs load-key -L prompt zroot
  zfs mount zroot/ROOT/alpine
  zfs mount zroot/home
}

# Function to install Alpine Linux base system
install_alpine_base() {
  echo "Installing Alpine Linux base system..."
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
}

# Main execution block
echo "Starting pre-chroot setup..."

# Prompt user for required variables
prompt_var BOOT_DISK "Enter the boot disk (e.g., /dev/nvme0n1)" "/dev/nvme0n1"
prompt_var DISK_KEY "Enter the encryption passphrase for the ZFS pool" "SomeKeyphrase"

# Derived variables
BOOT_PART="1"
BOOT_DEVICE="${BOOT_DISK}p${BOOT_PART}"
POOL_DISK="$BOOT_DISK"
POOL_PART="2"
POOL_DEVICE="${POOL_DISK}p${POOL_PART}"

# Execute functions
configure_repositories
apk update
apk add zfs zfs-scripts sgdisk wipefs
prepare_disks
configure_zfs
import_zfs_and_prepare
install_alpine_base

# Final instructions
echo "Pre-chroot setup completed successfully."
echo "To proceed, run the following command:"
echo "  chroot /mnt /bin/sh"
echo "Then, execute the second script to complete the setup."
