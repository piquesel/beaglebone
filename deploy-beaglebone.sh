#!/bin/sh

set -x

OVH_SERVER="91.121.146.6"
OVH_HOME="/home/desktop"
BBB_IMAGES="$OVH_HOME/bbb/build/tmp/deploy/images/beaglebone"
MACHINE="beaglebone"
BBB_TMP="$MACHINE-tmp"

rm -rf $BBB_TMP
mkdir -p $BBB_TMP 

# Downloading all files and images from OVH server
# MLO
echo "scp desktop@$OVH_SERVER:$BBB_IMAGES/MLO-${MACHINE} ./$BBB_TMP/MLO"
scp desktop@$OVH_SERVER:$BBB_IMAGES/MLO-${MACHINE} ./$BBB_TMP/MLO

# u-boot
scp desktop@$OVH_SERVER:$BBB_IMAGES/u-boot-${MACHINE}.img ./$BBB_TMP/u-boot.img

# zImage
scp desktop@$OVH_SERVER:$BBB_IMAGES/zImage ./$BBB_TMP/

if [ "x${1}" = "x" ]; then
	echo "Usage: ${0} <block device>"
	exit 0
fi

if [ -b "/dev/${1}1" ]; then
	DEV=/dev/${1}1
else
	echo "Block device not found: /dev/${1}1"
#	exit 1
fi

exit 1

echo "Formatting FAT partition on $DEV"
sudo mkfs.vfat ${DEV}

echo "Mounting $DEV"
sudo mount ${DEV} /media/card

echo "Copying MLO"
sudo cp $BBB_TMP/MLO /media/card/

echo "Copying u-boot"
sudo cp $BBB_TMP/u-boot.img /media/card

echo "Copying zImage"
sudo cp $BBB_TMP/zImage /media/card

echo "Unmounting ${DEV}"
sudo umount ${DEV}

echo "Done"
