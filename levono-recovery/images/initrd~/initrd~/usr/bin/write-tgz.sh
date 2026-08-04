#!/bin/sh
#
# invokes the wrdeppimg utility to write an image to disk
#

if [ $# -lt 2 ]; then
	echo "ERROR- invalid arguments"
	exit;
fi

filename=$1
drivenum=$2

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
echo "Writing $filename to $driveletter"
if [ -e /usr/bin/gnu-tar ]; then
	/usr/bin/gnu-tar -xzOf $filename | /usr/bin/wrdeppimg $driveletter $filename &
else
	/usr/bin/tar -xzOf $filename | /usr/bin/wrdeppimg $driveletter $filename &
fi
