#!/usr/bin/env bash
# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

mount_disk() {

  if grep -qs "$emmc_mount_path/home" /proc/mounts; then
    echo "Umount $disk_type home"
    umount $emmc_mount_path/home
    cryptsetup luksClose /dev/mapper/dsi
  fi

  if grep -qs "$emmc_mount_path" /proc/mounts; then
    echo "Umount $disk_type rootfs"
    umount $emmc_mount_path
  fi

  if ! grep -qs "$emmc_mount_path" /proc/mounts; then
    echo "Mount $disk_type rootfs"
    mount /dev/$partition1 $emmc_mount_path
  fi

  # Mount eMMC encrypted partition
  if [ -f $emmc_mount_path/root/.to136 ]; then
    echo "Mount $disk_type home"
    /home/debian/dsi-storage/decrypt-dsi-storage /dev/$partition2 dsi
    mount -t ext4 /dev/mapper/dsi $emmc_mount_path/home
  fi
}

umount_disk() {

  if grep -qs "$emmc_mount_path/home" /proc/mounts; then
    echo "Umount $disk_type home"
    umount $emmc_mount_path/home
    cryptsetup luksClose /dev/mapper/dsi
  fi

  if grep -qs "$emmc_mount_path" /proc/mounts; then
    echo "Umount $disk_type rootfs"
    umount $emmc_mount_path
  fi
}

emmc_mount_path="/media/emmc_rootfs"

disk_type=eMMC
disk=$(lsblk | grep mmcblk2p1 | awk '{print $1}' | cut -c 7-14)

if [ "$disk" == "" ]; then
  disk=sda
  disk_type=USB-mSATA
fi

partition1="$disk"1
partition2="$disk"2

case "$1" in 
  mount)   mount_disk ;;
  umount)  umount_disk ;;
  *) echo "usage: $0 mount|umount" >&2
    exit 1
    ;;
esac
