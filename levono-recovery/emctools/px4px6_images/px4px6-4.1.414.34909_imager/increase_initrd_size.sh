#!/bin/sh

log_filename="/mnt/system/log/upgrade_initrd.log"

echo "********* STARTED TO UPDATE INITRD SIZE **********\n"  > $log_filename

uboot_curr_initrd_size="0x300000"
uboot_new_initrd_size="0x400000"
uboot_initrd_increase_size="0x100000"
TRUE=0
FALSE=1

bootcmd_initrd="ide read 0x900000 0x2000 0x1800"
bootcmd_new_initrd="ide read 0x900000 0x2000 0x2000"

get_boot_start_value(  ){

	boot_start_value=$(echo $1 | sed -n 's/.*(.Image),\(.*\)@\(.*\)(initrd),\(.*\)@\(.*\)(boot).*/\4/p')
	echo "$boot_start_value"
}
get_initrd_size( ){

	initrd_size=`fw_printenv initrd_size 2>>$log_filename | sed -n "s/^\(initrd_size=\)\(.*\)$/\2/p"`

	echo "$initrd_size"
}
get_bootcmd2_value( ){

	bootcmd2=`fw_printenv bootcmd2 2>>$log_filename | sed -n "s/^\(bootcmd2=\)\(.*\)$/\2/p"`

	echo "$bootcmd2"
}
get_bootcmd_value( ){

	bootcmd=`fw_printenv bootcmd 2>>$log_filename | sed -n "s/^\(bootcmd=\)\(.*\)$/\2/p"`

	echo "$bootcmd"
}
get_initrd_start( ){

	initrd_start=`fw_printenv initrd_start 2>>$log_filename | sed -n "s/^\(initrd_start=\)\(.*\)$/\2/p"`

	echo "$initrd_start"
}
validate_initrd_size( ){

	if [ $1 == $2 ]; then
		return $TRUE
	else
		return $FALSE
	fi
}
validate_bootcmd_values( ){

	if [ -z "$(echo $1 | sed -n "/$bootcmd_initrd/p")" ];then
		return $FALSE
	fi
	if [ -z "$(echo $2 | sed -n "/$bootcmd_initrd/p")" ];then
		return $FALSE
	fi
	return $TRUE

}
update_bootcmd_values( ){

	bootcmd2=$1
	bootcmd=$2

	new_bootcmd2=$(echo $bootcmd2 | sed -n "s/^\(.*\)\($bootcmd_initrd\)\(.*\)$/\1$bootcmd_new_initrd\3/p")
	new_bootcmd=$(echo $bootcmd | sed -n "s/^\(.*\)\($bootcmd_initrd\)\(.*\)$/\1$bootcmd_new_initrd\3/p")

	fw_setenv bootcmd "$new_bootcmd"
	fw_setenv bootcmd2 "$new_bootcmd2"

	echo "new bootcmd2 is <$new_bootcmd2> <$new_bootcmd>" >> $log_filename
	 		

}
validate_free_space( ){

	initrd_size=$1
	initrd_start=$2
	boot_start=$3

	size=$(($initrd_size+$initrd_start+$uboot_initrd_increase_size))
	boot_size=$(($boot_start))
	if [ $size -le $boot_size ]; then
		return $TRUE
	else
		return $FALSE
	fi
}
update_initrd_size( ){
	
		fw_setenv initrd_size $uboot_new_initrd_size 2>>$log_filename
		return $TRUE
}
check_is_nanddevice( ){

	FLASHROOT=`grep mtd5 /proc/mtd 2>/dev/null | awk -F : '{print $1}'`
	if [ -z "$FLASHROOT" ];then
		return $FALSE
	fi
        if [ $FLASHROOT == "mtd5" ] ; then
		return $TRUE
	else
		return $FALSE
	fi
}
check_uboot_cmd_works( ){
	 
	 printenv_out=`fw_printenv 2>>$log_filename`
	 if [ -z "$printenv_out" ] ; then
	 	return $FALSE
	 else
	 	echo "printenv command output is $printenv_out" >> $log_filename
	 	return  $TRUE
 	 fi
}
check_initrd_size_from_mtd( ){

	initrd_size=$1    

	mtd_initrd_size=`cat /proc/mtd | grep 'initrd' | cut -d " " -f 2 | cut -c 3-`
	validate_initrd_size "0x$mtd_initrd_size" "$initrd_size"
}
if ! check_uboot_cmd_works ; then
	echo "Error in fw_printenv command" >> $log_filename
	exit $FALSE;

fi
if ! check_is_nanddevice ; then

	echo "THIS IS SPI DEVICE\n" >> $log_filename
	bootcmd2=$(get_bootcmd2_value)
	bootcmd=$(get_bootcmd_value)
	if ! (validate_bootcmd_values "$bootcmd2" "$bootcmd" ) ; then
	     echo "NO NEED TO INCREASE THE INITRD SIZE ...\n" >> $log_filename
	     exit $TRUE 
	fi
	update_bootcmd_values "$bootcmd2" "$bootcmd"
	exit $TRUE ;
else

initrd_size=$(get_initrd_size)
initrd_start=$(get_initrd_start)


if [ -z "$initrd_size" ] ; then
	echo "initrd size [ $initrd_size ] is empty" >> $log_filename
	exit $FALSE;
fi
if ! (validate_initrd_size "$initrd_size" "$uboot_curr_initrd_size") ; then
	echo "Initrd size $initrd_size is not 3MB.No Need to increase the initrd size" >> $log_filename
	exit $TRUE;
fi
if ! (check_initrd_size_from_mtd "$initrd_size"  ) ; then
	echo "Initrd size did not match with Uboot(ENV) & Linux ( /proc/mtd )" >> $log_filename
	exit $FALSE;
fi
mtdparts=`fw_printenv mk_mtdparts 2>>$log_filename | sed -n "s/^\(mk_mtdparts=\)\(.*\)$/\2/p"`

boot_start=$(get_boot_start_value "$mtdparts")
if ! [ -z "$boot_start" ]; then


	echo "initrd size [ $initrd_size ] and initrd start [ $initrd_start ] boot start [ $boot_start ] and mtdparts is [ $mtdparts]  " >> $log_filename


	if validate_free_space $initrd_size $initrd_start $boot_start; then
		if update_initrd_size ; then
			echo "********* SUCCESSFULLY INCREASED THE INITRD SIZE **********\n"  >> $log_filename
			exit $TRUE
		fi
   
	else
		echo "Unable to increase initrd size because not having enough space between initrd and boot partitions" >> $log_filename 
	fi
else
	echo "mtdparts [ $mtdparts ] [ $boot_start ] is not valid format.Unable to upgrade" >> $log_filename
fi
exit $FALSE
fi
