# PX6 OpenMediaVault Unattended Installer

## CRITICAL DATA-LOSS WARNING

This installer erases a disk without asking.

Remove every RAID, data, and backup drive before starting. Leave connected only the installer USB and the single drive intended for OpenMediaVault.

Do not run this installer while RAID member disks are installed. Automatic disk detection can fail and a data drive could be selected and erased.

This software is provided without warranty. The authors and contributors are not responsible for lost data, damaged filesystems, interrupted arrays, hardware problems, or other losses.

## Initial target

- LenovoEMC / Iomega PX6-300d
- AMD64
- Debian 13
- OpenMediaVault 8
- DHCP
- Exactly one eligible destination disk

## Safety policy

The destination must be a whole writable disk at least 25 GiB, must not be the installer media, and must not contain mdraid or LVM metadata. Installation stops unless exactly one eligible target remains.

## Status

Development scaffold only. Not yet tested on physical PX6-300d hardware.
