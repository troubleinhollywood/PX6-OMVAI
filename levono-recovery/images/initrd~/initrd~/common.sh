
###
# Search for and execute (if found) preimage script.
###
run_preimage_script()
{
	preimage_script=/usb_drive/emctools/px4px6_images/preimage.sh

	echo -n "Checking for pre-image script... "
	if [ -x $preimage_script ]
	then
		echo "found."
		$preimage_script
		return $?
	else
		echo "none."
		return 0
	fi
}

###
# Extract a platform imager upgrade file. Validate each invidual image
# via md5 checksum.
###
extract_validate_image()
{
	IMAGES="apps config initrd zImage"
	USB_IMAGER_IMAGE=/usb_drive/emctools/px4px6_images/*.tgz
	NoExtractionFile=/usb_drive/emctools/px4px6_images/noextraction
	tempFolder=/usb_drive/emctools/px4px6_images/temp

	if [ -f $USB_IMAGER_IMAGE ]
	then
		echo "Image tar file found: ${USB_IMAGER_IMAGE}"
	else
		echo "Image tar file not found: ${USB_IMAGER_IMAGE}"
		return 1
	fi

	tmp=`pwd`

	# extract
	if [ -f $NoExtractionFile ] && [ -d $tempFolder ] 
	then
		echo "No need to extract Image tar file."
		cd $tempFolder
	else
		echo "Extract Image tar file."
		mkdir -p $tempFolder
		cd $tempFolder
		tar -xzvf $USB_IMAGER_IMAGE
	fi

	# Validate the images
	for IMAGE in $IMAGES; do
		if [ -f $IMAGE ]
		then
			local_md5=`md5sum $IMAGE |awk -F ' ' '{print $1}'`
			md5_from_tar=`cat $IMAGE".md5"`
			if [ "$local_md5" == "$md5_from_tar" ]
			then
				echo "$IMAGE is valid"
			else
				echo "$IMAGE is not valid"
				cd $tmp
				rm -fr /usb_drive/emctools/px4px6_images/temp/
				return 3
			fi
		else
			echo "$IMAGE Not found in $USB_IMAGER_IMAGE tar file"
			cd $tmp
			rm -fr /usb_drive/emctools/px4px6_images/temp/
			return 2
		fi
	done

	cd $tmp
	return 0
}

setup_rootfs_to_shutdown()
{
	# set up the rootfs just enough to finish the boot
	# and shutdown
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

	# mount the boot filesystem
	mkdir -p sysroot/boot
	mkdir -p /sysroot/sysroot
	sleep 5
}


enable_network()
{
	echo "Enable Network" $1
	ethno=$1

	ifconfig $ethno up
 	if [ $? -eq 0 ]
 	then
 		sleep 5
		udhcpc -t 10 -n -s /etc/network/udhcpc.script -p /var/run/udhcpc.$ethno.pid -i $ethno
 		sleep 2
 	fi
 	ifconfig $ethno 

 	sleep 2
}
 
###
# Invoke the main USB imaging process.
###
do_usb_imaging()
{
	# invoke the actual imager script
	/imager_contents/emc_imager.sh usb_imaging $1 $2 $3 $4
	setup_rootfs_to_shutdown

	echo "Imaging Successful. Please remove the USB drive before the next power on"
}

###
# Normal, platform independent lifeline boot. Mount images
# and set up the rootfs.
###
do_normal_boot()
{
	echo "Found Valid EMC Image in disk..."
	MNTOPTS=loop
 	NFSDEBUGMOD=
 	NFS_SERVER=
 	NFS_ROOT=/home/soho/soho_root
	echo "Mounting apps image..."
	mkdir -p sysroot/mnt/apps

 	if [ "$NFSDEBUGMOD" = "" ] 
 	then	
		rm -rf /sysroot/boot/images/apps.rw
		
		mount -o loop,ro $APPS_IMAGE sysroot/mnt/apps
		
 	else 
	 	#for NFS debugging
 		enable_network eth0
 		echo "mount -t nfs -onolock $NFS_SERVER:$NFS_ROOT sysroot/mnt/apps"
 		mount -t nfs -onolock $NFS_SERVER:$NFS_ROOT sysroot/mnt/apps
 		sleep 2
 	fi

	# mount config
	echo "Mounting config image..."
	losetup /dev/loop1 $CONFIG_IMAGE

	# we temporarily symlink /lib and /usr/lib to the apps image, so we can run
	# the dynamically linked fsck executable from that location in initrd context
	echo "Check config filesystem"
	ln -s /sysroot/mnt/apps/lib /lib
	mkdir -p /usr
	ln -s /sysroot/mnt/apps/usr/lib /usr/lib
	e2fsck -y /dev/loop1 > etc/fsck
	rm -rf /lib /usr/lib /usr

	# mount the writeable image
	mkdir -p sysroot/mnt/etc
	mount /dev/loop1 sysroot/mnt/etc -o noatime,sync
	# mount a unionfs of the RO content and RW image
	mkdir -p sysroot/etc
	etc_filesystem=`cat /proc/filesystems | grep aufs`
	if [ -z $etc_filesystem ]; then
		echo "Mount config with unionfs"
		mount -t unionfs none /sysroot/etc -o noatime,sync,dirs=/sysroot/mnt/etc=rw:/sysroot/mnt/apps/etc=ro
	else
		echo "Mount config with aufs"
		mount -t aufs none /sysroot/etc -o noatime,sync,br=/sysroot/mnt/etc=rw:/sysroot/mnt/apps/etc=ro
	fi
	# remove old System.map files
	rm /sysroot/boot/System.map-*

	# copy the System.map file to /boot
	echo "Copying System.map..."
	SYSTEM_MAP_SRC_NAME="/sysroot/mnt/apps/var/System.map-*"
	SYSTEM_MAP_DEST_NAME="/sysroot/boot/"
	if [ -f $SYSTEM_MAP_SRC_NAME ]; then
		cp -f $SYSTEM_MAP_SRC_NAME $SYSTEM_MAP_DEST_NAME
	fi

	# mount the branding image if it exists
	if [ -f $OEM_IMAGE ]; then
		echo "Mounting OEM image..."
		mkdir -p sysroot/oem
		mount -o $MNTOPTS sysroot/boot/images/oem sysroot/oem
	fi
}

###
# Update an image in NAND flash. Locate the mtd partition by name,
# erase, and reflash.
###
update_flash_image()
{
	# search for the image dev by name
	mtdname=`grep $1 /proc/mtd | awk -F : '{ print $1 }'`
	if [ ! $mtdname ];
	then
		echo "No Image"
		return
	fi

	# get the major:minor for this mtd dev
	major=`cat /sys/class/mtd/$mtdname/dev | awk -F : '{ print $1 }'`
	minor=`cat /sys/class/mtd/$mtdname/dev | awk -F : '{ print $2 }'`

	# create the dev node, update the image
	mknod /dev/$mtdname c $major $minor
	flash_eraseall /dev/$mtdname
	nandwrite -p /dev/$mtdname $2
}

###
# Copy images from the USB drive to the image
# location on the device.
###
copy_image()
{
	IMAGES_DIR=/sysroot/boot/images
	SDKAPPS_DIR=/sysroot/boot/SDKApps
	SDKAPPS_SOURCE=/usb_drive/emctools/px4px6_images/SDKApps
	SDK_ETC_DIR=/sysroot/etc
	SDK_ETC_SOURCE=/usb_drive/emctools/px4px6_images/etc
	CONFIG_IMAGE=/sysroot/boot/images/config
	mkdir $IMAGES_DIR

	cp $APPS_UPGRADE_IMAGE $IMAGES_DIR
	cp $CONFIG_UPGRADE_IMAGE $IMAGES_DIR
	cp $OEM_UPGRADE_IMAGE $IMAGES_DIR
	echo "Copied apps config and oem image"

	if [ -f $KERNEL_IMAGE ]
	then
		cp $KERNEL_IMAGE $IMAGES_DIR
	fi

	if [ -f $RAMDISK_IMAGE ]
	then
		cp $RAMDISK_IMAGE $IMAGES_DIR
	fi

	if [ -d "$SDKAPPS_SOURCE" ] 
	then
		#Copy the SDK Apps
		mkdir -p $SDKAPPS_DIR
		echo "Copying SDK Apps to $SDKAPPS_DIR"
		cp -f $SDKAPPS_SOURCE/* $SDKAPPS_DIR 
	fi

	if [ -d "$SDK_ETC_SOURCE" ]
	then
		#Copy the SDK ETC
		losetup /dev/loop1 $CONFIG_IMAGE
		mkdir -p $SDK_ETC_DIR
		mount /dev/loop1 $SDK_ETC_DIR -o noatime,sync
		echo "Copying SDK Etc to $SDK_ETC_DIR"
		cp -f $SDK_ETC_SOURCE/* $SDK_ETC_DIR
		sleep 4
		umount $SDK_ETC_DIR
	fi
}


