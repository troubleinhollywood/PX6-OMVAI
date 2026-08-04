#!/bin/sh
#
#
# This script executes all gather scripts in /usr/local/gather/
# in order to collect the configuration file before upgrade
#
#
exec &> /dev/null

host=$(hostname)
timestamp=$(date +%Y%m%d%H%M%S)
timestamp=`echo $timestamp`

export SCRIPTS_DIR=/usr/local/gathertool

MINSKIPCMD[0]=$SCRIPTS_DIR/log
SKIPCMD[0]=$SCRIPTS_DIR/cores
SKIPCMD[1]=$SCRIPTS_DIR/preupgradeconfig

trap 'echo "gather error" ; rm -rf $tmp_dir ' EXIT

preUpgrade=false

mount_location=/mnt/system/preupgrade
tmp_dir=$mount_location/.tmp
working_dir=$tmp_dir/preupgrade-config-$timestamp/

if [ ! -d /mnt/system ]; then
	echo "/mnt/system/ is not up"
	exit 4
else 
	rm -rf $mount_location
fi
			

runcmd ()
{
    parent_pid=$$

    ( $1 $2 $3 $4; if [ $? -gt 0 ];then touch /tmp/$1_RET;fi ) &

    worker_pid=$!

    ( sleep 200 ; kill -9 $worker_pid > /tmp/$worker_pid) &
    killer_pid=$!
    wait $worker_pid
    
    #error happened in scripts
    if [ -e /tmp/$1_RET ];then
	kill -9 $killer_pid
        rm -rf $working_dir
	rm -rf /tmp/$1_RET
	rm -rf /tmp/$worker_pid
	exit 4
    fi

    # It's killed due to timeout
    if [ -e /tmp/$worker_pid ];then
	kill -9 $killer_pid
	rm -rf /tmp/$worker_pid
	rm -rf /tmp/$1_RET
    fi

    kill -9 $killer_pid
}


if [ ! -d $tmp_dir ]; then
	mkdir -p $tmp_dir
fi

if [ ! -d $working_dir ]; then
	mkdir -p $working_dir
fi

    ( 
	echo "<html>
	<head>
		<title>EMC Gather Tool $date</title>
	</head>
	<body>
	<h2>Gathered Machine State Information</h2>
	<h2>Hostname: $host</h2>"
    ) >> $working_dir/index.html
    
for i in $SCRIPTS_DIR/* ;do

	# Pass every script the working directory

	if echo "${SKIPCMD[@]}" | fgrep  "$i"; then
       	     echo "$i skipped"
	elif  echo "${MINSKIPCMD[@]}" | fgrep  "$i"; then
	     runcmd $i $working_dir 2
	else
             runcmd $i $working_dir 0 
	fi
	
	if [ "$i" != "$SCRIPTS_DIR/functions" ]; then
	    echo "		<a href=\"`basename $i`/index.html\">`basename $i`</a><br>" >> $working_dir/index.html
	fi

done
    set -e

    echo "	</body>" >> $working_dir/index.html
    echo "</html>" >> $working_dir/index.html

    #Zip up the results of the gather scripts
    cd $tmp_dir

    	mv preupgrade-config-$timestamp $mount_location

    rm -rf $working_dir
    cd $mount_location
    rm -rf $tmp_dir 

trap '' EXIT
