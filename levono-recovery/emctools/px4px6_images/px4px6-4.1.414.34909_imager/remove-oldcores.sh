#!/bin/sh

CORE_FOLDER="/mnt/system/cores"

if [ -d $CORE_FOLDER ]; then
	rm -rf $CORE_FOLDER
	echo "Older cores deleted."
fi

mkdir $CORE_FOLDER
