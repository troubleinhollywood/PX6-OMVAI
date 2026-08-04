#!/bin/sh
#
# erases a portion of a disk by overwriting with a specific value
#

if [ $# -lt 4 ]; then
	echo "ERROR- invalid arguments"
	echo "error" > /sysroot/erase-status
	exit;
fi

drivenum=$1
byte_value=$2
block_start=$3
block_size=$4

case $drivenum in
	0) driveletter="/dev/sda";;
	1) driveletter="/dev/sdb";;
	2) driveletter="/dev/sdc";;
	3) driveletter="/dev/sdd";;
	4) driveletter="/dev/sde";;
	5) driveletter="/dev/sdf";;
	6) driveletter="/dev/sdg";;
	7) driveletter="/dev/sdh";;
	8) driveletter="/dev/sdi";;
	9) driveletter="/dev/sdj";;
	10) driveletter="/dev/sdk";;
	11) driveletter="/dev/sdl";;
	12) driveletter="/dev/sdm";;
	13) driveletter="/dev/sdn";;
esac 

# write the image
echo "Writing $byte_value to $driveletter starting at sector $block_start and writing $block_size sectors"

echo "writing" > /sysroot/erase-status
dd if=/dev/zero of=$driveletter seek=$block_start count=$block_size bs=512
echo "done" > /sysroot/erase-status
