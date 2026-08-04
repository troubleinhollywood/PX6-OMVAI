#!/bin/sh

if [ ! -f /etc/sshd_config ]; then
	cp -f /etc/ssh/sshd_config /etc/sshd_config
fi

if [ -f /etc/sshd_config ] ; then
        sed -i -e 's:Protocol 2:#Protocol 2:g' /etc/sshd_config
        sed -i -e 's:HostKey /etc/ssh/ssh_host_rsa_key:#HostKey /etc/ssh/ssh_host_rsa_key:g' /etc/sshd_config
        sed -i -e 's:HostKey /etc/ssh/ssh_host_dsa_key:#HostKey /etc/ssh/ssh_host_dsa_key:g' /etc/sshd_config
        sed -i -e 's:HostKey /etc/ssh/ssh_host_ecdsa_key:#HostKey /etc/ssh/ssh_host_ecdsa_key:g' /etc/sshd_config
        sed -i -e 's:UsePrivilegeSeparation yes:#UsePrivilegeSeparation yes:g' /etc/sshd_config
        sed -i -e 's:KeyRegenerationInterval 3600:#KeyRegenerationInterval 3600:g' /etc/sshd_config
        sed -i -e 's:ServerKeyBits 768:#ServerKeyBits 768:g' /etc/sshd_config
        sed -i -e 's:RSAAuthentication yes:#RSAAuthentication yes:g' /etc/sshd_config
        sed -i -e 's:RhostsRSAAuthentication no:#RhostsRSAAuthentication no:g' /etc/sshd_config
        sed -i -e 's:IgnoreRhosts yes:#IgnoreRhosts yes:g' /etc/sshd_config
        sed -i -e 's:PrintLastLog yes:#PrintLastLog yes:g' /etc/sshd_config
        sed -i -e 's:Subsystem sftp /usr/lib/openssh/sftp-server:Subsystem sftp /usr/sbin/sftp-server:g' /etc/sshd_config
        sed -i -e '/Ciphers aes128-ctr,aes192-ctr,aes256-ctr,arcfour256,arcfour128/d' /etc/sshd_config
fi

