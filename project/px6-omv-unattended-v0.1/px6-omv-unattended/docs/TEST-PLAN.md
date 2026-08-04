# Test plan

1. One 20 GiB disk — must stop.
2. One 40 GiB disk — may select it.
3. Two 40 GiB disks — must stop.
4. mdraid member present — must stop.
5. LVM PV present — must stop.
6. Network unavailable — must not claim completion.
7. Successful install — reboot, DHCP, SSH, and OMV web UI.

For the PX6, remove every RAID and data disk. Use only one disposable target disk. Keep the working Toshiba OMV disk unchanged until the new installation has booted twice.
