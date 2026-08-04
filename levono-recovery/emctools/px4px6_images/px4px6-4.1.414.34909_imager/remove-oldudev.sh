#!/bin/sh

UDEV_FOLDER="/mnt/etc/udev/rules.d"

if [ -d $UDEV_FOLDER ]; then
	rm -rf $UDEV_FOLDER
	echo "Older udev deleted."
fi

mkdir $UDEV_FOLDER
