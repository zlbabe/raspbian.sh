#!/bin/bash

function usage() {
  echo -e "raspbian.sh [options]\n"
  echo -e "Options:\n"
  echo "-b	Path to an sdcard block device"
  echo "-c	Customize a raspbian image"
  echo "-d	Download the latest raspbian image"
  echo "-e	Extend the filesystem on an sdcard"
  echo "-i	Install raspbian image on an sdcard"
  echo "-p	Path to an existing raspbian image"
  echo -e "\nexamples:\n"
  echo "Extend the fs in an sdcard"
  echo -e "$ raspbian.sh -e -b /dev/mmcblk0\n"
  echo "Download the latest raspbian image and customize it"
  echo -e "$ raspbian.sh -c -d \n"
  echo "Customize a specific raspbian image"
  echo -e "$ raspbian.sh -c -p /path/to/raspbian.img\n"
  echo "Install raspbian on an sdcard"
  echo "$ raspbian.sh -p /path/to/raspbian.img -b /dev/mmcblk0"
}

if [ "$#" -eq 0 ]; then
    usage
    exit 1
fi

while getopts ":b:cdeip:" o; do
	case "${o}" in
		b)
			sdcard=${OPTARG}
			;;
		c)
			customize_image=true
			;;
		d)
			download=true
			;;
		e)
			extend=true
			;;
		i)
			install_image=true
			;;

		p)
			image=${OPTARG}
			;;
		*)
			usage
			exit 1
			;;
	esac
done

function install_prerequisites(){
	for pkg in binfmt-support qemu qemu-user-static unzip e2fsprogs parted; do
        	dpkg -l | grep $pkg > /dev/null
        	if [ $? -ne 0 ]; then
                	sudo apt install -y $pkg
        	fi
	done
}

function customize(){
	if [ ! -z $1 ]; then
		if [ -f $1 ]; then
			image_path=$1
		else
			echo "Unknow path $1"
			exit 1
		fi
	fi
	echo "Mounting the image ..."

	boot_partition=$(fdisk -lu $image_path | grep FAT32)
	boot_offset=$(echo $boot_partition | awk '{ print $2*512 }' )
	boot_sizelimit=$(echo $boot_partition | awk '{ print $4*512 }')

	root_partition=$(fdisk -lu $image_path | tail -n 1)
	root_offset=$(echo $root_partition | awk '{ print $2*512 }' )


	if [ ! -d /tmp/pi-install ] ;then
        	mkdir /tmp/pi-install
	fi

	if [ ! -d /tmp/pi-install/boot ]; then
        	mkdir /tmp/pi-install/boot
	fi

	mount | grep $image_path > /dev/null
	if [ $? -ne 0 ]; then
        	sudo mount $image_path -o loop,offset=$root_offset /tmp/pi-install
        	sudo mount $image_path -o loop,offset=$boot_offset,sizelimit=$boot_sizelimit /tmp/pi-install/boot
	fi

	qemu_path=$(which qemu-arm-static)

	sudo cp $qemu_path /tmp/pi-install/usr/bin/

	sudo mount --bind /dev     /tmp/pi-install/dev
	sudo mount --bind /dev/pts     /tmp/pi-install/dev/pts
	sudo mount --bind /proc   /tmp/pi-install/proc
	sudo mount --bind /sys   /tmp/pi-install/sys

	echo "Start chroot"

	sudo chroot /tmp/pi-install

	sudo rm /tmp/pi-install/usr/bin/qemu-arm-static

	sudo sync

	sudo umount /tmp/pi-install/dev/pts
	sudo umount /tmp/pi-install/dev
	sudo umount /tmp/pi-install/proc
	sudo umount /tmp/pi-install/sys
	sudo umount /tmp/pi-install/boot
	sudo umount /tmp/pi-install
	echo "Exit from chroot"
}

function extend_fs(){
	if [ -b $1 ]; then
		device=$1
        else
      		echo "$1 is not a block device"
      		exit 1
    	fi

	mount | grep $device > /dev/null
  	if [ $? -eq 0 ]; then
    		echo "Unmount SD card"
    		for mount_point in $(mount | grep $device | awk '{ print $1}'); do
      			sudo umount $mount_point > /dev/null
    		done
  	fi

  	total_units=$(sudo parted --script $device unit chs print  | grep "Disk /dev" | awk -F': ' '{ print $2 }')
  	partition_start=$(sudo parted --script $device unit chs print | tail -n 2 | egrep -v "^$" | awk '{ print $2 }')

  	sudo parted --script $device \
    	unit chs \
    	rm 2 \
    	mkpart primary $partition_start $total_units \
    	quit


  	echo "Check the filesystem of rootfs partition"
  	sudo e2fsck -f $device"p2" 

  	echo "Extend the filesystem of rootfs partition"
  	sudo resize2fs $device"p2"

  	sudo sync
}

function install() {
	sdcard=$1
	image=$2

	if [ ! -b $sdcard ]; then
		echo "$sdcard is not a block device"
		exit 1
	elif [ -! -f $image ]; then
		echo "$image is not a regular image file"
		exit 1
	fi
	
	echo "Installing ..."
	sudo dd if=$image of=$sdcard bs=4M conv=fsync status=progress
	sudo sync
	echo "Finished."
}

function download_raspbian() {

	if [ ! -d .cache ]; then
		mkdir .cache
	fi
	
	if [ ! -f .cache/raspbian.img ]; then
		echo "Downloading ..."
        	wget -O .cache/raspbian.zip -q --show-progress https://downloads.raspberrypi.org/raspbian_lite_latest
        	unzip .cache/raspbian.zip -d .cache/ > /dev/null
        	mv .cache/*.img .cache/raspbian.img
        	rm .cache/*.zip
		echo "The image is saved in ./cache/raspbian.img"
	else
		echo "Image found in cache (./cache/raspbian.img)"
	fi
}

if [ $extend ]; then
	if [ -z $sdcard ]; then
		echo "Path to sdcard is missing"
		exit 1
	else
		extend_fs $sdcard
	fi
fi

if [ $customize_image ]; then
	if [ -z $image ] && [ $download ]; then
		download_raspbian
		customize .cache/raspbian.img
	fi
	if [ ! -z $image ]; then
		customize $image
	fi
fi

if [ $install_image ]; then
	if [ -z $sdcard ]; then
		echo "Path to sdcard is missing"
		exit 1
	elif  [ -z $image ]; then
		echo "Path to raspbian image is missing"
		exit 1
	else
		install $sdcard $image
	fi
fi
