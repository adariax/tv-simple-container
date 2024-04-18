#!/bin/bash

V_PATH=.
ROOTFS_PATH=./shared/rootfs.tar

MOUNT_PATH=$V_PATH/mnt/$1

image=$V_PATH/$1.img

loop_device=''

if [[ -z $1 ]]; then
    echo "invalid (empty) name '$1' for container!!"
    exit 1
fi

if [[ -f $image_path ]]; then
    echo "the container with name '$1' already exists :("
    exit 1
fi


virt_storage_device () {
    # create virtual storage device using file as image
    # it will contain file system info and other data

    local size=1G

    # create a  zeroed image file -> loop device
    dd if=/dev/zero of=$image bs=$size count=1

    # setup loop mechanism to use file above as image for virtual storage device
    loop_device=$(losetup -f --show $image)

    # make filesystem (ext4) on virtual storage device 
    mkfs -t ext4 $loop_device

    # mount virtual storage device for specific point
    mkdir -p $MOUNT_PATH
    mount $loop_device $MOUNT_PATH

    # test
    touch $MOUNT_PATH/test_file

    # rootfs from tar to mountpoint
    tar -xf $ROOTFS_PATH -C $MOUNT_PATH
}


delete () {
    # unmount + remove loop_device
    umount $loop_device
    losetup -D $loop_device
    rm -rf $image $MOUNT_PATH
}

virt_storage_device $1  # name

setup_path="export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# run
user_cmd="${@:2}"  # other params (cmd)
full_cmd="$setup_path ; $user_cmd"
cgroups="cpu,memory"

cgcreate -g "$cgroups:$1"

# run program in new namespaces, isolation of network and PID namespace + fork
isolation_cmd="unshare -n -p -f"

# run
cgexec -g "$cgroups:$1" $isolation_cmd chroot $MOUNT_PATH /bin/bash -c "$full_cmd" || true

# rm after complete container
delete $1
