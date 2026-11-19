# PX6-OMVAI

Debian 13 and OpenMediaVault installation research and experimental installer tooling for the LenovoEMC/Iomega PX6-300d.

## Start here — working manual installation

**[Read the PX6 manual Debian installation and boot configuration guide](docs/manual-px6-installation.md).**

The owner's successful conversion used an **external USB Debian installer**, **interactive installation over motherboard UART**, and a **dedicated SATA SSD** for Debian and GRUB. The PX6 BIOS was configured to boot from the external installer USB first and SSD second during installation. Afterward, the installer USB was removed and the SSD was selected as the primary boot device.

The soldered internal LenovoEMC flash was deliberately retained, not used as the Debian installation destination. The owner recalls excluding it from normal BIOS boot priority. Read-only inspection found the original Iomega `SOHO` and recovery boot entries still present. **Recovery functionality has not been tested.**

**Safety:** Disconnect existing RAID/data disks during OS installation. Verify the destination disk by model and capacity, not only `/dev/sdX`. **Never overwrite or reformat the internal recovery flash.** Do not format or initialize existing RAID members.

## Experimental automated installer (not the proven installation method)

The repository also contains an in-development unattended installer build workflow, including `build.sh`, `build.ps1`, and `preseed/` templates. **This automated workflow was not the method used for the successful PX6 installation and has not been established as working end-to-end on PX6 hardware.** Treat generated images and automated partitioning as experimental. Do not deploy them to a NAS containing irreplaceable data.

The build configuration currently targets Debian 13.6 amd64 netinst. This is a **build target**, not a verified record of the original manually installed Debian media. Build scripts and templates are retained for further testing; this documentation update does not validate or change their behavior.

## Serial console (UART)

The PX6-300d has an internal serial header identified as `SERIAL_B` in the independent hardware reference below.

[![PX6-300d SERIAL_B motherboard header (external reference photograph)](https://open-desk.org/posts/linux-on-lenovo-emc-px6-300d/px6_serial_connector.png)](https://open-desk.org/posts/linux-on-lenovo-emc-px6-300d/)

*External hardware reference: [Dustin Frisch, “Linux on Lenovo-EMC PX6-300d”](https://open-desk.org/posts/linux-on-lenovo-emc-px6-300d/). The photo is hosted by the original site.*

Use a **USB-to-TTL UART** adapter with a verified board pinout and voltage. Connect TX to RX, RX to TX, and GND to GND. **Do not connect VCC.** Do not use an RS-232 voltage-level adapter directly on a TTL header.

The owner's successful serial-console configuration was **115200 baud, 8N1** through PuTTY. Adapter wire colors are not standardized. See the [manual installation guide](docs/manual-px6-installation.md) for the hardware arrangement and remaining uncertainties.

## Development roadmap

1. Document the working manual PX6 conversion and evidence.
2. Verify BIOS screenshots, installer steps, and recovery procedures on noncritical hardware.
3. Audit and test the automated installer scripts and preseed templates.
4. Validate any generated installer image in a VM before PX6 hardware testing.
5. Test on a disposable OS SSD with all existing RAID members disconnected.
6. Document and separately validate OpenMediaVault setup and nondestructive RAID re-import.

## Development rules

- Preserve original internal flash and existing data disks.
- Never represent an untested build or recovery procedure as verified.
- Keep build inputs and generated outputs separate.
- Validate automated installation in a VM and on disposable hardware before use on a production PX6.
- Do not change existing RAID members during OS installation.
