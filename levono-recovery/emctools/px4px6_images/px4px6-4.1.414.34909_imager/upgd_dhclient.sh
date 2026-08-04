#/bin/sh
rm -f /etc/dhcp/dhclient-enter-hooks.d/samba
cp -fr /etc/dhcp3/dhclient-enter-hooks.d/samba /etc/dhcp/dhclient-enter-hooks.d/samba
rm -rf /etc/dhcp3
ln -s /etc/dhcp /etc/dhcp3
