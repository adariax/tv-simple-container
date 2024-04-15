#!/bin/bash

V_PATH=.
ROOTFS_PATH=./shared/rootfs.tar

virt_storage_device () {
    # create virtual storage device using file as image
    # it will contain file system info and other data.
    local image=$V_PATH/$1.img
    local mount_path=$V_PATH/mnt/$1
    
    local size=1G

    # create a  zeroed image file -> loop device
    dd if=/dev/zero of=$image bs=$size count=1

    # setup loop mechanism to use file above as image for virtual storage device
    loop_device=$(losetup -f --show $image)

    # make filesystem (ext4) on virtual storage device 
    mkfs -t ext4 $loop_device

    # mount virtual storage device for specific point
    mkdir -p $mount_path
    mount $loop_device $mount_path

    # test
    touch $mount_path/test_file

    # rootfs from tar to mountpoint
    tar -xf $ROOTFS_PATH -C $mount_path
}

virt_storage_device $1
