#!/bin/sh

# avahi-autoipd user and group should be created inorder to work avahi-autopid daemon for getting link-local ip 

	avahi_group=`cat /etc/group | grep "avahi-autoipd"`
	if [ "${avahi_group}" != "" ]; then
		echo "group exist"
	else
		echo "adding group"
		echo 'avahi-autoipd:x:103:' >> /etc/group
	fi

	avahi_user=`cat /etc/passwd | grep "avahi-autoipd"`
	if [ "${avahi_user}" != "" ]; then
		echo "user exist"
	else
		echo "adding user"
		/usr/sbin/adduser --system --uid 101 --group --home "/var/lib/avahi-autoipd" avahi-autoipd
	fi
