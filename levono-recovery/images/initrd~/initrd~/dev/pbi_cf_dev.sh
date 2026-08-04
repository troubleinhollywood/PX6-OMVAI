#!/bin/sh

#minors=16
#function make_minors {
    #let part=1
    #while (($part < $minors)); do
        #let minor=$part+$2
        #mknod $1$part b $major $minor
        #let part=$part+1
    #done
#}

module="pbi_cf"
device="cfa"
mode="664"

major=`cat /proc/devices | awk "\\$2==\"$module\" {print \\$1}"`

# if we didn't detect the driver then don't install the device nodes
if [ "x${major}x" = "xx" ]; then
	exit 0;
fi

# Remove stale nodes and replace them, then give gid and perms
rm -f /dev/${device}* /dev/${device}

#mknod /dev/${device} b $major 0
mknod /dev/${device}1 b $major 1
#make_minors /dev/${device} 0
chmod $mode  /dev/${device}*

