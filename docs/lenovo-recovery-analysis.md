# Lenovo PX6 recovery analysis

## Confirmed boot chain

The official Lenovo recovery media uses GRUB and boots:

- `/images/vmlinuz`
- `/images/initrd`

The normal recovery entry passes:

    bootmode=recovery console=ttyS0,115200 rw

This confirms that the PX6 recovery console uses `ttyS0` at 115200 baud.

The recovery startup sequence is:

    GRUB
      -> linuxrc
      -> mount_images.sh
      -> common.sh
      -> emc_imager.sh

## Initrd startup

The recovery `linuxrc` script:

1. Mounts the filesystems listed in the initrd configuration.
2. Creates loop device nodes.
3. Checks for a debug shell kernel argument.
4. Runs `mount_images.sh`.
5. Constructs the runtime root filesystem.
6. Pivots into the assembled root filesystem.
7. Invokes the LifeLine bootstrap process.

## Device discovery

`mount_images.sh` distinguishes the USB recovery media from the PX6 internal
boot device using:

- `/sys/class/block/<device>/removable`
- the device sysfs path
- the USB path identifier `2-1:1.0`

The Lenovo recovery logic eventually converts a partition path such as
`/dev/sda1` into the corresponding whole disk `/dev/sda` before calling the
imager.

## Destructive behavior

The Lenovo `emc_imager.sh` script can:

- unmount the selected disk partition
- overwrite the first 10 MiB of the disk
- create an MBR partition table
- create a primary partition
- format that partition
- copy LifeLine images
- copy GRUB files
- install GRUB to the whole disk
- remove partitions
- zero mdadm superblocks
- destroy existing RAID metadata

These operations are useful for understanding the original recovery process,
but the destructive selection behavior will not be reused directly.

## PX6-OMVAI v0.2 safety model

PX6-OMVAI separates disk discovery from every destructive operation.

`scripts/select_target.sh` must return one unambiguous whole-disk path before
any installer stage is allowed to partition or format a disk.

The selector rejects:

- removable devices
- USB transport devices
- mounted disks
- disks with mounted child partitions
- disks with `linux_raid_member` signatures
- disks marked as RAID members
- disks outside the configured size range
- systems containing multiple safe-looking installation candidates

When no target or multiple targets remain, the installer refuses to continue.