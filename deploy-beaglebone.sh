#!/bin/sh

set -x

OVH_SERVER="91.121.146.6"
OVH_HOME="/home/desktop"
BBB_IMAGES="$OVH_HOME/bbb/build/tmp/deploy/images/beaglebone"
MACHINE="beaglebone"
BBB_TMP="$MACHINE-tmp"
DTB_FILE="am335x-boneblack-wireless.dtb"
TARGET_HOSTNAME=$MACHINE

function print_uenv() {
	cat > /tmp/uEnv.txt << EOF
# You can either hardcode your fdtfile or use some sort of test
# like I did here with findfdtfile.
# If you do not provide an uEnv.txt, then am335x-boneblack.dtb
# will be the default. (Hard coded in u-boot).
bootpart=0:2
bootdir=/boot
bootfile=zImage
console=ttyO0,115200n8
fdtaddr=0x88000000
fdtfile=bbb-4dcape70t.dtb
loadaddr=0x82000000
mmcroot=/dev/mmcblk0p2 ro
mmcrootfstype=ext4 rootwait
optargs=consoleblank=0
nohdmi=bbb-nohdmi.dtb
mmcargs=setenv bootargs console=${console} ${optargs} root=${mmcroot} rootfstype=${mmcrootfstype}
findfdtfile=if test -e mmc ${bootpart} ${bootdir}/nohdmi; then setenv fdtfile ${nohdmi}; fi;
loadfdt=run findfdtfile; load mmc ${bootpart} ${fdtaddr} ${bootdir}/${fdtfile}
loadimage=load mmc ${bootpart} ${loadaddr} ${bootdir}/${bootfile}
uenvcmd=if run loadfdt; then echo Loaded ${fdtfile}; if run loadimage; then run mmcargs; bootz ${loadaddr} - ${fdtaddr}; fi; fi;
EOF
}

function print_interfaces(){
	cat > /tmp/interfaces << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

#auto wlan0
iface wlan0 inet dhcp
        wireless_mode managed
        wpa-conf /etc/wpa_supplicant.conf
EOF
}

function print_wpa_supplicant(){
	cat > /tmp/wpa_supplicant.conf << EOF
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=root
update_config=1

network={
    key_mgmt=WPA-PSK
    ssid=""
    psk=""
    }
EOF
}


rm -rf $BBB_TMP
mkdir -p $BBB_TMP 

if [ $# -lt 2 ]
then
	echo "Usage: ${0} <block device> <image>"
	exit 0
fi

image=${2}

# Downloading all files and images from OVH server
# MLO
echo "scp desktop@$OVH_SERVER:$BBB_IMAGES/MLO-${MACHINE} ./$BBB_TMP/MLO"
scp desktop@$OVH_SERVER:$BBB_IMAGES/MLO-${MACHINE} ./$BBB_TMP/MLO

# u-boot
scp desktop@$OVH_SERVER:$BBB_IMAGES/u-boot-${MACHINE}.img ./$BBB_TMP/u-boot.img

# zImage
scp desktop@$OVH_SERVER:$BBB_IMAGES/zImage ./$BBB_TMP/

# rootfs
scp desktop@OVH_SERVER:$BBB_IMAGES/${image}-image-${MACHINE}.tar.xz ./$BBB_TMP/

# dtb file
scp desktop@OVH_SERVER:$BBB_IMAGES/${DTB_FILE} ./$BBB_TMP/bbb.dtb

# Create uEnv.txt file
print_uenv()

if [ -b "/dev/${1}1" ]; then
	DEV=/dev/${1}1
else
	echo "Block device not found: /dev/${1}1"
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

echo "Copying uEnv.txt"
sudo cp /tmp/uEnv.txt /media/card

echo "Unmounting ${DEV}"
sudo umount ${DEV}

echo "Boot... done!"

if [ -b "/dev/${1}2" ]; then
	DEV=/dev/${1}2
else
	echo "Block device not found: /dev/${1}2"
fi

echo "Formatting FAT partition on $DEV"
sudo mkfs.ext4 -q -L ROOT ${DEV}

echo "Mounting $DEV"
sudo mount ${DEV} /media/card

echo "Extracting ${rootfs} /media/card"
rootfs=$BBB_TMP/${image}-image-${MACHINE}.tar.xz
sudo tar -C /media/card -xJf ${rootfs}

echo "Generating a random-seed for urandom"
mkdir -p /media/card/var/lib/urandom
sudo dd if=/dev/urandom of=/media/card/var/lib/urandom/random-seed bs=512 count=1
sudo chmod 600 /media/card/var/lib/urandom/random-seed

echo "Writing hostname to /etc/hostname"
export TARGET_HOSTNAME
sudo -E bash -c 'echo ${TARGET_HOSTNAME} > /media/card/etc/hostname'

echo "Writing interfaces to /media/card/etc/network"
sudo cp /tmp/interfaces /media/card/etc/network/interfaces

echo "Writing wpa_supplicant.conf to /media/card/etc"
sudo cp /tmp/wpa_supplicant.conf /media/card/etc/wpa_supplicant.conf
