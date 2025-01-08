#!/bin/sh

# Function to validate username
validate_username() {
  if echo "$1" | grep -qE '[/[:space:]]'; then
    echo "ERROR: Username cannot contain '/' or spaces. Exiting."
    exit 1
  fi
}

# Function to confirm user choices
confirm_choices() {
  echo "INFO: Review your selections:"
  echo "  Selected disks: $SELECTED_DISKS"
  echo "  RAID type: $RAID_TYPE"
  echo "  Encryption key: [hidden]"
  echo "  Admin username: $ADMIN_USERNAME"
  echo "Do you want to proceed? (yes/no):"
  read -r CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "INFO: Operation canceled by user."
    exit 0
  fi
}

# Function to list available disks and prompt user for selection
list_and_select_disks() {
  echo "INFO: Listing available disks..."
  lsblk -d -o NAME,SIZE,TYPE | grep disk
  echo "Enter the disks you want to use (e.g., sda sdb):"
  read -r SELECTED_DISKS

  if [ -z "$SELECTED_DISKS" ]; then
    echo "ERROR: No disks selected. Exiting."
    exit 1
  fi

  echo "INFO: You selected the following disks: $SELECTED_DISKS"
}

# Function to suggest RAID configuration based on selected disks
suggest_raid_configuration() {
  DISK_COUNT=$(echo "$SELECTED_DISKS" | wc -w)

  if [ "$DISK_COUNT" -eq 2 ]; then
    echo "INFO: You have selected two disks."
    FIRST_DISK=$(echo "$SELECTED_DISKS" | awk '{print $1}')
    SECOND_DISK=$(echo "$SELECTED_DISKS" | awk '{print $2}')
    FIRST_SIZE=$(lsblk -b -d -o NAME,SIZE | grep "$FIRST_DISK" | awk '{print $2}')
    SECOND_SIZE=$(lsblk -b -d -o NAME,SIZE | grep "$SECOND_DISK" | awk '{print $2}')
    if [ "$FIRST_SIZE" = "$SECOND_SIZE" ]; then
      echo "You can choose between Mirror (recommended) or Stripe."
      RAID_TYPE="mirror"
    else
      echo "You can choose between Mirror or Stripe (Stripe recommended for non-production use)."
      RAID_TYPE="stripe"
    fi
  elif [ "$DISK_COUNT" -eq 3 ]; then
    echo "INFO: You have selected three disks."
    echo "You can choose between RAIDZ1 (recommended) or Stripe."
    RAID_TYPE="raidz1"
  else
    echo "INFO: Custom configuration required for $DISK_COUNT disks."
    RAID_TYPE="custom"
  fi

  echo "Selected RAID type: $RAID_TYPE"
}

# Function to validate user input (e.g., check if a disk exists)
validate_disks() {
  for DISK in $SELECTED_DISKS; do
    if [ ! -b "/dev/$DISK" ]; then
      echo "ERROR: Disk /dev/$DISK does not exist. Exiting."
      exit 1
    fi
  done
}

# Function to clean disks
clean_disks() {
  echo "INFO: Cleaning disks..."
  for DISK in $SELECTED_DISKS; do
    zpool labelclear -f "/dev/$DISK"
    wipefs -a "/dev/$DISK"
    sgdisk --zap-all "/dev/$DISK"
  done
}

# Function to create partitions
create_partitions() {
  echo "INFO: Creating partitions..."
  for DISK in $SELECTED_DISKS; do
    sgdisk -n "1:1m:+512m" -t "1:ef00" "/dev/$DISK" # Boot partition
    sgdisk -n "2:0:-10m" -t "2:bf00" "/dev/$DISK"   # ZFS pool partition
  done
}

# Function to configure ZFS pool and datasets
configure_zfs() {
  echo "INFO: Setting up ZFS pool and datasets..."
  echo "$DISK_KEY" >/etc/zfs/zroot.key
  chmod 000 /etc/zfs/zroot.key

  POOL_DISKS=""
  for DISK in $SELECTED_DISKS; do
    POOL_DISKS="$POOL_DISKS /dev/${DISK}2"
  done

  zpool create -f -o ashift=12 \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -O encryption=aes-256-gcm \
    -O keylocation=file:///etc/zfs/zroot.key \
    -O keyformat=passphrase \
    -o autotrim=on \
    -m none zroot $RAID_TYPE "$POOL_DISKS"

  zfs create -o mountpoint=none zroot/ROOT
  zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/${ID}
  zfs create -o mountpoint=/root zroot/root
  zfs create -o mountpoint=/home/"${ADMIN_USERNAME}" zroot/home/"${ADMIN_USERNAME}"
  zpool set bootfs=zroot/ROOT/${ID} zroot
  zpool export zroot
}

# Function to import ZFS pool and mount datasets
import_zfs_and_mount() {
  echo "INFO: Importing ZFS pool and mounting datasets..."
  zpool import -N -R /mnt zroot
  zfs load-key -L prompt zroot
  zfs mount zroot/ROOT/${ID}
  zfs mount zroot/root
  zfs mount zroot/home/"${ADMIN_USERNAME}"
  udevadm trigger
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

# Gather inputs
list_and_select_disks
validate_disks
suggest_raid_configuration
echo "Enter the encryption passphrase for the ZFS pool [default: SomeKeyphrase]:"
read -r DISK_KEY
DISK_KEY=${DISK_KEY:-SomeKeyphrase}
echo "Enter the username for the admin account (recommended: admin):"
read -r ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
validate_username "$ADMIN_USERNAME"

# Confirm choices
confirm_choices

# Derived variables
ID="void"

# Execute tasks
clean_disks
create_partitions
configure_zfs
import_zfs_and_mount
install_void_base

# Final instructions
echo "INFO: Pre-chroot setup completed successfully."
