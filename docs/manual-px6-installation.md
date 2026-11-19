# Manual Debian installation on the LenovoEMC PX6-300d

> **Status:** Reconstruction of one owner's successful installation, based on firsthand recollection and read-only inspection of a running PX6 on 19 November 2026. This is **not** a fully validated, repeatable procedure for every PX6. BIOS menu labels, exact installer choices, and recovery operation have not been independently verified. Read all warnings before attempting.

## Protect the original system

**Do not erase, repartition, format, or install GRUB onto the soldered internal LenovoEMC flash.** It contains the original Iomega/LenovoEMC boot files and may be needed for recovery. The original recovery procedure has **not** been tested after conversion, so its availability is not guaranteed.

**Disconnect existing data/RAID drives before installation.** Label them and record their original slot positions. Do not initialize, format, assemble destructively, or rebuild an existing RAID array during operating-system installation. Confirm disk identity by **model, capacity, serial number, and topology**, not by `/dev/sdX` names, which can change.

Keep backups of irreplaceable data. Modifying firmware boot settings or selecting the wrong installation target can render a system unbootable or destroy data.

## Hardware and console

The owner opened the PX6, removed the existing data drives, retained the expansion/backplane board providing the SATA bay connections, and connected a dedicated SATA SSD. The BIOS did not present the SATA destination as available until the SSD was physically connected through the required SATA hardware.

A USB-to-TTL UART adapter was connected to the motherboard serial header, with the console opened in PuTTY at **115200 baud, 8 data bits, no parity, 1 stop bit (8N1)**. The owner's wiring recollection was white TX, green RX, black GND, with the red VCC wire **not connected**. **Wire colors are adapter-specific, not a pinout.** Verify both adapter and motherboard pin assignments and TTL voltage before connecting. Cross TX/RX appropriately; connect ground; do not connect VCC or use a full-voltage RS-232 adapter.

The owner recalls adjusting PuTTY's terminal emulation and possibly using a USB keyboard during early setup. Which adjustment fixed keyboard interaction remains unverified.

## Boot configuration during installation

The owner prepared an **external USB drive containing the Debian installer** and connected it alongside the SATA SSD.

In the PX6 BIOS, the owner recalls setting:

1. **First boot device — external Debian installer USB**
2. **Second boot device — SATA SSD**
3. **Internal LenovoEMC flash — excluded/disabled from the normal boot priority**

The exact BIOS menu names and saved firmware settings were not captured. This order is the owner's firsthand recollection, **not a setting verified from a current BIOS screenshot**. Identify the devices by their displayed model/capacity before selecting them. Do not confuse the external installer USB with the soldered internal flash, which may also appear as a USB device.

## Install Debian manually

The successful conversion used the **interactive Debian installer over the serial console**, not the repository's experimental automated preseed. The owner had attempted unattended installation but completed the successful installation manually.

During installation:

- Select the **dedicated SATA SSD** as the Debian target. Double-check identity before confirming any partition or filesystem changes.
- **Never select the internal LenovoEMC flash or a data/RAID member** as the installation target.
- Install the BIOS/legacy version of GRUB onto the **SSD disk**, not the internal flash. In the inspected working system, Debian records the SSD as its `grub-pc/install_devices` target.
- Use the serial console to answer the installer's questions. The owner recalls slow screen refreshes and apparently stalled stages; allow time before assuming a hang. The installation took approximately **90 minutes in this particular experience**, not a guaranteed duration.

The exact Debian installer screens, partitioning decisions, package selections, and original installation media version were not recorded, so this guide does not invent them. Do not follow the experimental preseed files as if they were proven to reproduce this successful manual installation.

## First normal boot

After Debian finished, the owner **removed the external installer USB** and changed the BIOS boot priority to select the **SATA SSD as the primary boot device**, rather than the internal flash. The system then started Debian from the SSD.

This boot order is supported by the owner's recollection. We have **not** re-entered BIOS or rebooted the working NAS solely to verify the saved settings.

OpenMediaVault was subsequently installed and the existing data disks were reconnected. The precise OMV installation commands, version, and RAID re-import sequence have **not yet been reconstructed or verified**. Do not treat this document as a validated RAID import guide.

## Evidence collected from the working system

Read-only inspection on 19 November 2026 found:

| Item | Observation |
| --- | --- |
| Hardware | Iomega PX6-300d family; legacy BIOS boot |
| Running OS | Debian 13 (trixie) |
| Running kernel | `7.2.12+deb13-amd64` |
| OS SSD | X12 SSD 256GB, observed as `/dev/sda`, MBR partition table |
| Root filesystem | SSD partition `/dev/sda1`, ext4, UUID `4d008b25-5d42-4e3a-98b7-d9b8c3769159` |
| Swap | SSD `/dev/sda5`, 8 GiB |
| Internal flash | USB DISK ~956 MiB, observed as `/dev/sdg`, ext2 partition `/dev/sdg1` |
| Debian GRUB target | `/dev/disk/by-id/ata-X12_SSD_256GB_KT202010764098HP` from `debconf-show grub-pc` |
| Debian GRUB menu | Searches the SSD root UUID, loads kernel/initrd from `/boot`, configures serial console at 115200 8N1 |
| Internal flash menu | Original `SOHO`, recovery and factory-reset entries remain |
| Flash kernel image | Iomega Linux `3.8.6` kernel in `/images/vmlinuz` |
| Debian GRUB packages | Package logs record installation on 7 August 2026 |
| Data array | Five ~1.8 TB disks, observed as `/dev/sdb`–`/dev/sdf`, combined as `/dev/md0` RAID5; **not an installation target** |

Both SSD and flash MBRs contained a `GRUB` string at byte offset 384, and their first 440 MBR bytes hashed identically. Their pre-partition areas and their **stored** `core.img` files differed. These observations do **not** prove the firmware boot order or which embedded GRUB core image is executed.

The internal flash's existing files do **not** establish that recovery is currently functional, and modification timestamps alone do **not** prove that the flash was changed during conversion.

### Safe, read-only checks on an already running PX6

```bash
cat /etc/os-release
cat /proc/cmdline
lsblk -o NAME,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINTS,MODEL
sudo debconf-show grub-pc
sudo fdisk -l /dev/sda /dev/sdg
```

**Important:** The device names above describe the inspected machine only. Verify actual devices before using even read-only disk commands on another machine. Do **not** paste GRUB syntax such as `set root` or `search --fs-uuid` into Bash; those are GRUB commands, not shell instructions.

## Still to verify before claiming a fully reproducible installation

- Exact BIOS setup screens, drive naming and persistent boot priority.
- Original Debian installer image/version and precise interactive installation choices.
- A documented, independently tested recovery method using the preserved internal flash.
- OpenMediaVault installation, configuration, and safe re-import of existing RAID data.
- Repeat installation on a separate PX6 or disposable test disk.

The experimental automated installer in this repository is a **separate development track** and should not be presented as the method that produced the currently running system.
