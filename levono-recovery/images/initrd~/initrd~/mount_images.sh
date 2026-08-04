#!/bin/sh

DEFAULT_SERAIL="12345678901234567890ABCD"
DEFAULT_SERAIL2="To Be Filled By O.E.M."
SYS_BLOCK_DIR=/sys/class/block
. /common.sh

make_nodes()
{
		mknod /dev/sda b 8 0
		mknod /dev/sda1 b 8 1
		
		mknod /dev/sdb b 8 16
		mknod /dev/sdb1 b 8 17

		mknod /dev/sdc b 8 32
		mknod /dev/sdc1 b 8 33

		mknod /dev/sdd b 8 48
		mknod /dev/sdd1 b 8 49

		mknod /dev/sde b 8 64
		mknod /dev/sde1 b 8 65

		mknod /dev/sdf b 8 80
		mknod /dev/sdf1 b 8 81

		mknod /dev/sdg b 8 96 
		mknod /dev/sdg1 b 8 97

		mknod /dev/sdh b 8 112 
		mknod /dev/sdh1 b 8 113

		mknod /dev/sdi b 8 128
		mknod /dev/sdi1 b 8 129

		mknod /dev/sdj b 8 144
		mknod /dev/sdj1 b 8 145

		mknod /dev/sdk b 8 160
		mknod /dev/sdk1 b 8 161

		mknod /dev/sdl b 8 176
		mknod /dev/sdl1 b 8 177

		mknod /dev/sdm b 8 192
		mknod /dev/sdm1 b 8 193

		mknod /dev/sdn b 8 208
		mknod /dev/sdn1 b 8 209

}

# Used to find the USB drive node which is used to do EMC-Imager.
update_usbdevice_node()
{
	make_nodes
	count=1
	for i in a b c d e f g h i j k l m n;
	do
		drive=sd$i
		isDrive=`cat /sys/class/block/$drive/removable`
		if [ "$isDrive" == "0" ]
		then
			echo "$drive is a hard drive"
		else
			device_link=`readlink $SYS_BLOCK_DIR/$drive`
			boot_id_index_px4px6=`echo $device_link | awk '{print index($0, "2-1:1.0")}'`
			echo "device_link is $device_link"
			echo "boot_id_index is $boot_id_index_px4px6"
			if [ "$boot_id_index_px4px6" != "0" ]
			then
				sleep 5
				continue
			fi
			break;
		fi
	done
	if [ -f $SYS_BLOCK_DIR/$drive/${drive}1/size ]
	then
		USB_DEVICE=/dev/${drive}1
	else
		# Handle no partition case
		USB_DEVICE=/dev/$drive
	fi

	echo "The usb device node should be $USB_DEVICE"
}

# Used to identify the flash device present inside the box
scan_for_bootdisk()
{
	echo "No hardcoded boot device, scanning."

	# loop indefinitely, until a device is found.
	while [ 1 ]
	do
		# enumerate SCSI devices
		scsi_drives=`(cd $SYS_BLOCK_DIR; ls -d sd* | grep -v [12345])`
		echo "scsi drives found: $scsi_drives"
		for d in $scsi_drives
		do
			echo "Examining $d"
			removable=`cat $SYS_BLOCK_DIR/$d/removable`
			if [ $removable == 0 ]
			then
				echo "  -$d is not removable"
				continue
			fi

			partone=$SYS_BLOCK_DIR/$d/${d}1
			# If NAND chip partition is removed, then we need to create one during flashing. 
			# So no need to check whether partition is there when doing flashing.
			if [ ! -f $RESET_BUTTON_FILE ] && [ ! $USB_RECOVERY_MODE == "0" ]
			then
				# The condition will be checked during normal booting operation
				echo "Checking if partition is present"
				if [ ! -d $partone ]
				then
					echo "  -$d dont have parition 1"
					continue
				fi
			fi
	
			device_link=`readlink $SYS_BLOCK_DIR/$d`
			boot_id_index_px4px6=`echo $device_link | awk '{print index($0, "2-1:1.0")}'`
			if [ $boot_id_index_px4px6 == 0 ]
			then
				echo "  -$d: boot_id_index was not found"
				continue
			fi

			SOHO_BOOTDISK_NODE=/dev/${d}1
			# If the parition is present, take the major and minor number from it.
			if [ -f "$partone/dev" ]
			then
				SOHO_BOOTDISK_MAJOR=`awk -F : '{print $1}' $partone/dev`
				SOHO_BOOTDISK_MINOR=`awk -F : '{print $2}' $partone/dev`
			fi
			echo "Using $SOHO_BOOTDISK_NODE ($SOHO_BOOTDISK_MAJOR:$SOHO_BOOTDISK_MINOR)."
			return
		done

		sleep 5
	done
}


do_network_imaging()
{
	echo "Going in to Network Imaging Mode"
	lcdimg /usr/reimage.bmp

	# we need 75% of ram to fit DEPP images
	mount -t tmpfs -o remount,size=75% none /sysroot

	make_nodes

 	enable_network eth0

	serialNum=0
	if [ -f /sys/class/dmi/id/product_serial ]
	then
		serialNum=`cat /sys/class/dmi/id/product_serial`
	fi

	# if serail number from DMI table is default then return mac address
	if [ "$serialNum" == $DEFAULT_SERAIL ] || [ "$serialNum" == $DEFAULT_SERAIL2 ]
	then
		mac=`ifconfig|grep eth0|awk {'print $5'}`
		echo "mac address is $mac"
		serialNum=`echo $mac|awk -F : {'print $1$2$3$4$5$6'}`
	fi
	# parameter should be the same as in the firmware.xml
	deppResult=0
	/usr/bin/recovery px4px6 "$serialNum"
	deppResult=$?

	if [ "$deppResult" == "0" ]
	then
		echo "The DEPP image copy was successful."
	else
		echo "The DEPP image copy was not successful."
		echo "Reboot the system."
		/usr/bin/status_led_DEEP.sh err
	fi

	mkdir /sysroot/bin
	cp -r -d /bin/* /sysroot/bin/
	mkdir /sysroot/sbin
	cp -r -d /sbin/* /sysroot/sbin/
	cp -r -d /imager_contents/etc /sysroot/
	rm -f /sysroot/etc/init.d/S*
	cp -r -d /imager_contents/nw/S* /sysroot/etc/init.d/
	mkdir -p /sysroot/dev
	cp -r -d /dev/* /sysroot/dev/
	mkdir -p /sysroot/sys
	mkdir -p /sysroot/proc
	mkdir -p /sysroot/usr
	mkdir -p /sysroot/usr/local
	mkdir -p /sysroot/usr/local/cfg/
	cp -r -d /imager_contents/initrd_bootstrap.sh /sysroot/usr/local/cfg/
	mkdir -p /sysroot/sysroot
}


# Create lcm character device so that info can be updated in LCD Display
mknod /dev/lcm c 10 128

echo "Checking to see the if the reset button is pressed or not"
RESET_BUTTON_FILE=/usr/bin/resetbuttonpressed
/usr/bin/resetbuttonmon

cat /proc/cmdline | grep bootmode
USB_RECOVERY_MODE=$?

if [ -f $RESET_BUTTON_FILE ] || [ $USB_RECOVERY_MODE == "0" ]
then
	rm -f $RESET_BUTTON_FILE
	lcdimg /usr/reimage.bmp
	echo " Checking if there is a usb drive attached"
	sleep 5

	update_usbdevice_node
	DRIVEFWSCR=/usb_drive/emctools/px4px6_images/preimage.sh
	mkdir -p /usb_drive
	mount $USB_DEVICE /usb_drive -t vfat -o async,rw,fmask=0000,dmask=0000,iocharset=utf8
	mount_ret=$?


	# default values parsed in at build time
	SOHO_BOOTDISK_NODE=
	SOHO_BOOTDISK_MAJOR=0
	SOHO_BOOTDISK_MINOR=0
	SOHO_APPS_IN_RAM=

	# if nothing is passed in, we scan for a boot disk
	if [ ! $SOHO_BOOTDISK_NODE ]
	then
		scan_for_bootdisk
	fi
	mknod $SOHO_BOOTDISK_NODE b $SOHO_BOOTDISK_MAJOR $SOHO_BOOTDISK_MINOR
	if [ $mount_ret -eq 0 ] && [ -f $DRIVEFWSCR ]
	then
		# mount the boot filesystem
		mkdir -p sysroot/boot
		mount $SOHO_BOOTDISK_NODE sysroot/boot -o noatime,sync

		run_preimage_script
		mkdir /sysroot/bin
		cp -r -d /bin/* /sysroot/bin/
		mkdir /sysroot/sbin
		cp -r -d /sbin/* /sysroot/sbin/
		cp -r -d /imager_contents/etc /sysroot/
		mkdir -p /sysroot/dev
		cp -r -d /dev/* /sysroot/dev/
		mkdir -p /sysroot/sys
		mkdir -p /sysroot/proc
		mkdir -p /sysroot/usr
		mkdir -p /sysroot/usr/local
		mkdir -p /sysroot/usr/local/cfg/
		cp -r -d /imager_contents/initrd_bootstrap.sh /sysroot/usr/local/cfg/
		mkdir -p /sysroot/sysroot
	else
		# remove the 1 from /dev/sd*1
		BOOT_DISK=${SOHO_BOOTDISK_NODE%1};
		echo "Going to flash the device $BOOT_DISK"
		/imager_contents/emc_imager.sh $BOOT_DISK 3
		echo "Imaging successfull. Going to shutdown"
		poweroff -f
		sleep 5
		#NOTE: The system will be shutdown after this step. Script won't proceed further.
	fi
else
	SOHO_BOOTDISK_NODE=
	SOHO_BOOTDISK_MAJOR=0
	SOHO_BOOTDISK_MINOR=0
	SOHO_APPS_IN_RAM=

# check for recovery boot
cat /proc/cmdline | grep recovery
RECOVER=$?

# check for depp boot
cat /proc/cmdline | grep depp
VAR=$?

# if nothing is passed in, we scan for a boot disk
if [ ! $SOHO_BOOTDISK_NODE ]
then
	scan_for_bootdisk
fi

# mount the boot filesystem
mkdir -p sysroot/boot
mknod $SOHO_BOOTDISK_NODE b $SOHO_BOOTDISK_MAJOR $SOHO_BOOTDISK_MINOR
mount $SOHO_BOOTDISK_NODE sysroot/boot -o noatime,sync

if [ $VAR == "0" ]; 
then
	echo " Going to do DEPP Imaging"
	do_network_imaging

else
if [ $RECOVER == "0" ]; 
then
	# recovery boot in progress, boot from recovery images
	APPS_IMAGE=sysroot/boot/recovery_images/apps
	CONFIG_IMAGE=sysroot/boot/recovery_images/config
	OEM_IMAGE=sysroot/boot/recovery_images/oem

	# mount apps
	echo "Copying apps image to RAM..."
	cp $APPS_IMAGE sysroot/.apps
	APPS_IMAGE=sysroot/.apps

	# copy image to RAM and mount rw
	echo "Copying config image to RAM..."
        dd if=$CONFIG_IMAGE of=sysroot/.config
	CONFIG_IMAGE=sysroot/.config

	do_normal_boot
else
	# normal boot
	umount /usb_drive
	APPS_IMAGE=sysroot/boot/images/apps
	CONFIG_IMAGE=sysroot/boot/images/config
	OEM_IMAGE=sysroot/boot/images/oem
	lcdimg -i /usr/progress25.bmp

	# mount apps
	if [ $SOHO_APPS_IN_RAM ];
	then
		echo "Copying apps image to RAM..."
		cp $APPS_IMAGE sysroot/.apps
		APPS_IMAGE=sysroot/.apps
	fi

	do_normal_boot
fi
fi
fi
