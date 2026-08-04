#!/bin/sh
FLASHROOT=`grep mtd5 /proc/mtd | awk -F : '{print $1}'`
if [ $FLASHROOT == "mtd5" ]
then
	echo "FLASH based system ix2-ng detected Lets remount BFDLV"
	mount /mnt/boot -o remount,noatime,async
fi
