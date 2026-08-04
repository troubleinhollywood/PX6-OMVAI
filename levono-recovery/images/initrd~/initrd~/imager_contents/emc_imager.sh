#!/bin/sh

DISK_MOUNT=/sysroot/boot

# x86 hw id
HW_R4A="1"
HW_R12A="2"
HW_B6A="3"
HW_R4B="4"
HW_R12B="5"
HW_B2A="6"
HW_B4B="7"

##
## Prepare all the SATA disks attached
##
## Args:
##   none
##
prep_sata_disk()
{
	dev=`echo $1 | awk -F "/" '{print $3}'`
	node=$1"1"
	full_dev=$1
	echo "dev = $dev"
	echo "node = $node"
	echo "full_dev = $full_dev"

	if [ $hw == $HW_R12A ] ||  [ $hw == $HW_B6A ] || [ $hw == $HW_R4B ] || [ $hw == $HW_R12B ] || [ $hw == $HW_B2A ] || [ $hw == $HW_B4B ]
	then
			prep_device $dev $node $full_dev
	else
		a=`cat /sys/class/block/$dev/removable`
		if [ "$a" == "0" ]
		then
			prep_device $dev $node $full_dev
		else
			return -1
		fi
	fi
return 0
}

prep_device()
{
	dev=$1
	node=$2
	full_dev=$3
	echo "2. dev = $dev"
	echo "2. node = $node"
	echo "2. full_dev = $full_dev"

	echo "Preparing drive /dev/$dev\n"

	umount $node > /dev/null 2>&1
	sleep 1
	dd if=/dev/zero of=$full_dev bs=1M count=10 > /dev/null 2>&1
	create_partition $full_dev
	copy_image $node
	install_grub $full_dev
	unmount_disk $node
}


##
## Prepare block device nodes
##
## Args:
##  none
##
mk_dev_nodes()
{
	echo "Creating device nodes [$1]\n. Please wait"

	mknod /dev/sda b 8 0 > /dev/null 2>&1
	mknod /dev/sda1 b 8 1 > /dev/null 2>&1
   
	mknod /dev/sdb b 8 16 > /dev/null 2>&1
	mknod /dev/sdb1 b 8 17 > /dev/null 2>&1
   
	mknod /dev/sdc b 8 32 > /dev/null 2>&1
	mknod /dev/sdc1 b 8 33 > /dev/null 2>&1
   
	mknod /dev/sdd b 8 48 > /dev/null 2>&1
	mknod /dev/sdd1 b 8 49 > /dev/null 2>&1
   
	mknod /dev/sde b 8 64 > /dev/null 2>&1
	mknod /dev/sde1 b 8 65 > /dev/null 2>&1
   
	mknod /dev/md0 b 9 0 > /dev/null 2>&1
	
	mknod /dev/zero c 1 5
}


##
## create partition on sata drive
##
## Args:
##  $1 Location of the drive
##
create_partition()
{
	echo "Creating system parition on $1"
	if [ $hw == $HW_B4B ]
	then
		parted -s $1 mktable msdos
		parted -s $1 mkpart primary 1049kB \"-1kB\"

	elif [ $hw == $HW_B2A ]
	then
		parted -s $1 mktable msdos
		parted -s $1 mkpart primary 1049kB \"-1kB\"
	elif [ $hw == $HW_B6A ]
        then
		parted -s $1 mktable msdos
		parted -s $1 mkpart primary 1049kB \"-1kB\"
	elif [ $hw == $HW_R4B ]
	then
		parted -s $1 mktable msdos
		parted -s $1 mkpart primary 1049kB \"-1kB\"
	elif [ $hw == $HW_R12B ]
	then
		parted -s $1 mktable msdos
		parted -s $1 mkpart primary 1049kB \"-1kB\"
	elif [ $hw == $HW_R12A ]
	then
		parted -s $1 mktable msdos
		parted -s $1 mkpart primary 1049kB \"-1kB\"
	fi
}

   
copy_image()
{
	echo "Creating filesystem on $1"

	/sbin/mke2fs $1 
	/sbin/e2fsck -y $1

	# create a temp directory /sysroot/boot and mount the hard drive
	mkdir -p /sysroot
	mkdir -p $DISK_MOUNT
	mount $1 $DISK_MOUNT

	echo "Copying images to $1"
	local tmp=`pwd`
	cd $EXTRACT_PATH

	# create the correct directory structure
	mkdir -p $DISK_MOUNT/images
	for image in apps config oem initrd apps.md5 config.md5 initrd.md5 oem.md5
	do 
		cp -f $EXTRACT_PATH/$image $DISK_MOUNT/images/$image
	done
	cp -f $EXTRACT_PATH/zImage $DISK_MOUNT/images/vmlinuz
	cp -f $EXTRACT_PATH/zImage.md5 $DISK_MOUNT/images/vmlinuz.md5

	mkdir -p $DISK_MOUNT/grub
	for image in menu.lst grub.cfg menu.lst.md5 grub.cfg.md5
	do 
		cp -f $EXTRACT_PATH/$image $DISK_MOUNT/grub/$image
	done
	mkdir -p $DISK_MOUNT/ginstall
	cp -f $EXTRACT_PATH/grub $DISK_MOUNT/ginstall/grub
	if [ -f $DISK_MOUNT/$SPECIAL_FILE ]
	then
		cp -f $DISK_MOUNT/$SPECIALFILE $DISK_MOUNT/ > /dev/null 2>&1
	fi

	# copy ./emctools/platform/SDKApps to /boot/SDKApps
	mkdir -p $DISK_MOUNT/SDKApps
	cp -f $IMAGEDIR/SDKApps/* $DISK_MOUNT/SDKApps/

	validate_images $DISK_MOUNT/images/ rm_md5
	status=$?
	if [ "$status" -ne "0" ]
	then
		echo "Failed at validate_images function: $status"
		return $status
	fi
	# remove the encrypted and unencrypted images
	cd $tmp
	
	echo "DONE"
}

unmount_disk()
{
	sync
	syncresult=$?
	echo "Unmount DOM drive mounting point"
	sleep 3
	umount $1
	ret=$?
	if [ "$ret" -eq "0" ]
	then
		echo "--- Successfully unmounted DOM drive ---"
	else
		echo "--- Failed to unmount DOM drive ---"
	fi
	mount
	rm -fr $DISK_MOUNT
}

install_grub()
{
	# Install the grub
	grub-install --root-directory=$DISK_MOUNT $1
	echo "GRUB install status: $?"
	cp $DISK_MOUNT/grub/grub.cfg $DISK_MOUNT/boot/grub/

	if ! grep "insmod linux" $DISK_MOUNT/boot/grub/grub.cfg ; then
		echo "grub.cfg file is correpted.Going to launch the SHELL"
		sh
	fi
}

extract_and_link_image() {

	mkdir -p $EXTRACT_PATH

	( cd $EXTRACT_PATH; tar -xvzf $USB_IMAGER_IMAGE )
	# If extraction results in an error
	if [ "$?" -ne "0" ]
	then
		echo "Error while extracting the $USB_IMAGER_IMAGE."
		rm -rf $EXTRACT_PATH
		return 1
	fi
	# Call the function to validate the md5sum for all images.
	validate_images $EXTRACT_PATH
	status=$?
	if [ "$status" -ne "0" ]
	then
		echo "Failed at validate_images function: $status"
		return $status
	fi

	mkdir -p /tmp
	echo "Mounting Apps Image"
	mount -o loop $APPS_IMAGE /tmp

	echo "Creating links to Apps libraries"
	mv /usr /usr_bkp
	mv /sbin /sbin_bkp

	# link to the ram dir present in Apps image. ram contains the libc and other necessary libraries
	ln -s /tmp/ram /ram

	# Replace the busybox's readlink and grep, since it didn't support option used by grub-install
	cp /tmp/bin/readlink /bin
	cp /tmp/bin/grep /bin

	# Remove the /lib and /lib64 if already present, since we will use the libs from apps image ( Impact of CL #2628 )
	rm -rf /lib
	rm -rf /lib64

	# Make appropriate links to load shared libraries dynamically.
	ln -s /tmp/lib /lib
	ln -s /tmp/usr /usr
	ln -s /tmp/sbin /sbin
	ln -s /lib /lib64
}

create_devnode() {

  MAJOR=8
  MINORBASE=0
  MINOR=0
  DEVCHAR=$1
  DEVCHARLEN=$2
  DEVNUM=$3
  DEVNUMLEN=$4 
	if [ $DEVCHARLEN -eq 2 ] 
	then
	    DC0=`echo $DEVCHAR | awk '{print substr($0,1,1)}' | /usr/bin/tr -d "\n"| /usr/bin/od -A n -t dC`
	    DC1=`echo $DEVCHAR | awk '{print substr($0,2,1)}' | /usr/bin/tr -d "\n"| /usr/bin/od -A n -t dC`
	    s1=`echo "$DC1 96" | awk '{print $1-$2}'`
	    s2=`echo "$DC0 96" | awk '{print $1-$2}'`
	    s3=`echo "26 $s2" | awk '{print $1*$2}'`
	    s4=`echo "$s3 1" | awk '{print $1-$2}'`
	    s5=`echo "$s1 $s4" | awk '{print $1+$2}'`
	    MINORBASE=`echo "$s5 16" | awk '{print $1*$2}'`
	elif [ $DEVCHARLEN -eq 1 ]; then
	    DC=`echo $DEVCHAR | /usr/bin/tr -d "\n"| /usr/bin/od -A n -t dC`
	    s1=`echo "$DC 97" | awk '{print $1-$2}'`
	    MINORBASE=`echo "16 $s1" | awk '{print $1*$2}'`
	fi

	if [[ $DEVNUMLEN -ne 0 ]] 
	then
	   MINOR=`echo "$MINORBASE $DEVNUM" | awk '{print $1+$2}'`
	else
	   MINOR=$MINORBASE
	fi
	#echo "NODE=$NODE minorbase=$MINORBASE minor=$MINOR"
	if [[ $DEVNUM -eq 0 ]]; then
	echo "mknod /dev/sd$DEVCHAR b $MAJOR $MINOR"
	mknod /dev/sd$DEVCHAR b $MAJOR $MINOR
	else
	echo "mknod /dev/sd$DEVCHAR$DEVNUM b $MAJOR $MINOR"
	mknod /dev/sd$DEVCHAR$DEVNUM b $MAJOR $MINOR
        fi
}

initialize_devParam() {
	DCHAR=""
	DNUM=""
	DCHARLEN=0
	DNUMLEN=0
}

get_devchar() {
   NODE=$1
	DCHAR=`echo $NODE | cut -c3- | /usr/bin/tr -cd "[:alpha:]"`
	DNUM=`echo $NODE | cut -c3- | /usr/bin/tr -cd "[:digit:]"`
        DCHARLEN=`echo $DCHAR | /tmp/etc/alternatives/awk '{print length}'`
        DNUMLEN=`echo $DNUM | /tmp/etc/alternatives/awk '{print length}'`
	if [ $DNUMLEN -eq 0 ]
	then
	     DNUM=0
	fi
}

erase_drive() {
 DRIVE=$1
	if [ -f /sys/class/block/$DRIVE/removable ]
        then 
             isDrive=`cat /sys/class/block/$DRIVE/removable`
             if [ "$isDrive" == "0" ]
             then
	       	   echo "$PARTITIONS" | grep "$DRIVE"
               	   if [ $? -eq 1 ]; then
                       echo "$DRIVE no partition but may contain md super block"
		       if [ -e /dev/$DRIVE ] ; then
			   echo "dev node already available"
		       else
			   echo "Creating... dev node /dev/$DRIVE"
			   initialize_devParam
		           get_devchar $DRIVE
			   create_devnode $DCHAR $DCHARLEN $DNUM $DNUMLEN
		       fi
                       echo "mdadm --zero-superblock /dev/$DRIVE"
                       mdadm --zero-superblock /dev/$DRIVE
	               echo "dd if=/dev/zero of=/dev/$PART count=10 bs=1M"
	               dd if=/dev/zero of=/dev/$DRIVE count=10 bs=1M
	           else
                       echo "$DRIVE has partitions"
                   fi
               fi
         fi
}

erase_partition() {
PART=$1
	echo "erase partition $PART"
	NODENAME=`echo $PART | /usr/bin/tr -cd "[:alpha:]"`
    	echo $NODENAME	
    	NODENUM=`echo $PART | /usr/bin/tr -cd "[:digit:]"`
    	echo $NODENUM
    	if [ -f /sys/class/block/$NODENAME/removable ]
       	then 
        	isDrive=`cat /sys/class/block/$NODENAME/removable`
             	if [ "$isDrive" == "0" ]
                then
		    if [ -e /dev/$PART ] ; then
		       echo "dev node already available"
		    else
		       echo "Creating... dev node /dev/$PART"
		       initialize_devParam
		       get_devchar $PART
		       create_devnode $DCHAR $DCHARLEN $DNUM $DNUMLEN
		    fi
	            echo "mdadm --zero-superblock /dev/$PART"
	            mdadm --zero-superblock /dev/$PART
	            echo "dd if=/dev/zero of=/dev/$PART count=10 bs=1M"
	            dd if=/dev/zero of=/dev/$PART count=10 bs=1M
                    echo "parted -s /dev/$NODENAME rm $NODENUM" 
                    parted -s /dev/$NODENAME rm $NODENUM
             	fi
    	fi
}

clean_harddisk() {
	
	lvchange -a n md0_vg

	PARTITIONS=`cat /proc/partitions | awk '{print $4}' | grep -w sd[a-z]*[1-9]* | grep [1-9]`
	DRIVES=`cat /proc/partitions | awk '{print $4}'| grep -w sd[a-z]*`
	echo $PARTITIONS
	echo $DRIVES
	DCHAR=""
	DNUM=""
	DCHARLEN=0
	DNUMLEN=0
	echo "--- destroy raid"
        #clean the drives which has no partition
	for DRIVEE in $DRIVES; do
		erase_drive $DRIVEE
	done
        #clean the drives which has partitions
	for PARTT in $PARTITIONS; do
	        erase_partition $PARTT
    	done 
}

umount_apps() {

	rm -f /lib /lib64 /usr /sbin
	mv /usr_bkp /usr
	mv /sbin_bkp /sbin
	umount /tmp
	if [ -b /dev/loop0 ]; then
		umount /dev/loop0
		losetup -d /dev/loop0
	fi
	rm -fr $EXTRACT_PATH
	umount /usb_drive
	echo "The last mount information"
	mount
}


validate_images() {
	
	if [ -z "$2" ] 
	then 
		IMAGES="apps config initrd zImage oem grub.cfg menu.lst"
	else
		IMAGES="apps config initrd vmlinuz oem ../grub/grub.cfg ../grub/menu.lst"
	fi
	
	sync
	IMAGES_PATH=$1
	local tmp=`pwd`
	cd $IMAGES_PATH
	for IMAGE in $IMAGES; do
		if [ -f $IMAGE ]
		then
			local_md5=`md5sum $IMAGE | awk -F ' ' '{print $1}'`
			md5_from_tar=`cat $IMAGE".md5"`
			if [ "$local_md5" == "$md5_from_tar" ]
			then
				echo "$IMAGE is valid"
				if [ "$2" == "rm_md5" ]
				then
					rm $IMAGE".md5"
				fi
			else
				echo "$IMAGE is not valid"
				cd $tmp
				rm -rf $IMAGES_PATH
				return 3
			fi
		else
                        echo "$IMAGE Not found in $USB_IMAGER_IMAGE tar file"
                        cd $tmp
                        rm -rf $IMAGES_PATH
                        return 2
		fi
	done

	cd $tmp
	return 0
}

####################################################
#
#  MAIN
#
####################################################

mk_dev_nodes
hw=$2
echo "hw is $hw"
echo "device is $1"

IMAGEDIR=/usb_drive/emctools/px4px6_images
USB_IMAGER_IMAGE=/usb_drive/emctools/px4px6_images/*.tgz
EXTRACT_PATH=/usb_drive/extract_path/
APPS_IMAGE=/usb_drive/extract_path/apps

# Used to safegaurd the content present in the HDD. We can format and flash the NAND, but should not remove anything from HDD's
PRESERVE_DATA=/usb_drive/emctools/px4px6_images/noreinstall

extract_and_link_image
status=$?
if [ "$status" -ne "0" ]
then
	return $status
fi

prep_sata_disk $1

# If the noreinstall file is not present, then clean the HDD.
if [ ! -f $PRESERVE_DATA ]
then
	clean_harddisk
else
	rm -rf $PRESERVE_DATA
fi

umount_apps
