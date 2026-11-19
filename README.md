# PX6-OMVAI

**Project status: COMPLETE — v1.0.0**

**Successful conversion of the LenovoEMC/Iomega PX6-300d to Debian 13 and OpenMediaVault using manual installation through UART.**

## Project outcome

The LenovoEMC PX6-300d is a headless NAS without conventional monitor, keyboard, or mouse connections for an interactive OS installation. The original project goal was to produce an unattended Debian installer because it was not initially clear how to interact with an installer on this hardware.

After extensive troubleshooting and repeated unsuccessful unattended installation attempts, the project changed approach. The motherboard's UART serial interface allowed the Debian installer to be operated through PuTTY. The **manual installation succeeded**, and the converted NAS has continued to operate successfully in everyday use.

**The project is finished.** The unattended installer was an unsuccessful experimental approach, **not an outstanding requirement or active roadmap item**.

## Successful installation method

1. Open the PX6 and remove the existing data/RAID drives to protect them during OS installation.
2. Keep the required SATA expansion/backplane hardware connected and attach a dedicated SATA SSD.
3. Connect a verified USB-to-TTL serial adapter to the motherboard UART header and open PuTTY at **115200 baud, 8N1**.
4. Prepare and connect an **external USB Debian installer**.
5. Configure the BIOS boot order for installation: **external installer USB first, SATA SSD second**; exclude the soldered internal LenovoEMC flash from normal boot priority.
6. Run the **interactive Debian installer over UART**, selecting the SATA SSD as the installation target and GRUB destination.
7. After installation, **remove the installer USB** and configure the BIOS to boot **directly from the SATA SSD**.
8. Set up OpenMediaVault and reconnect the existing storage drives without formatting or initializing existing RAID members.

The owner recalls the interactive Debian installation taking approximately **90 minutes**. This is a firsthand account, not a guaranteed installation time.

**[Read the detailed manual installation and evidence guide](docs/manual-px6-installation.md).** The guide distinguishes confirmed disk/GRUB observations from recollections and steps not independently retested. The exact OMV setup and RAID re-import commands are not documented as verified procedures.

## Critical precautions

- **Preserve the original internal LenovoEMC flash.** Do not erase, repartition, format, or install Debian/GRUB onto it. Its original Iomega boot and recovery files were observed during read-only inspection, but **recovery operation has not been tested**.
- **Disconnect RAID/data drives before OS installation.** Verify the SSD by model, capacity and serial number, not only by `/dev/sdX` name.
- Do not assume the experimental automated installer is safe or operational. Do not use it on a system containing irreplaceable data.
- The BIOS menu labels and exact installer prompts have not been independently captured. The successful system has **not** been rebooted or altered merely to verify documentation.

## Serial console (UART)

The PX6-300d has an internal serial header identified as `SERIAL_B` in this independent hardware reference:

[![PX6-300d SERIAL_B motherboard header (external reference photograph)](https://open-desk.org/posts/linux-on-lenovo-emc-px6-300d/px6_serial_connector.png)](https://open-desk.org/posts/linux-on-lenovo-emc-px6-300d/)

*Photo and reference: [Dustin Frisch, “Linux on Lenovo-EMC PX6-300d”](https://open-desk.org/posts/linux-on-lenovo-emc-px6-300d/). The image is hosted on its original website.*

Use a **USB-to-TTL UART** adapter only after verifying the motherboard pinout and electrical voltage. Connect board TX to adapter RX, board RX to adapter TX, and ground to ground. **Do not connect VCC.** Do not attach an RS-232 voltage-level adapter directly to a TTL header. Adapter wire colors are not universal.

The successful console settings were **115200 baud, 8 data bits, no parity, 1 stop bit (115200 8N1)**.

## Historical unattended installer files

The repository retains `build.sh`, `build.ps1`, `preseed/` and supporting scripts as **historical, experimental development artifacts**. Multiple unattended installation attempts failed, and these files were **not used to achieve the successful manual installation**.

The current build configuration targets Debian 13.6 amd64 netinst, but this is only an experimental build target, not a confirmed record of the original installation media. The unattended installer is **discontinued**. Its presence does not mean it is production-ready, tested end-to-end, or required to complete this project.

## Completion statement

**PX6-OMVAI v1.0.0 — COMPLETE**

- **Debian 13:** Installed and operational on a dedicated SATA SSD.
- **OpenMediaVault:** Operational on the converted PX6.
- **Boot configuration:** SATA SSD selected as primary boot device.
- **Original internal flash:** Preserved, with original boot/recovery files present; recovery not independently validated.
- **Unattended installation:** Unsuccessful and discontinued.
- **Final installation method:** Manual through the UART serial console.

This project demonstrates a successful real-world conversion of the headless LenovoEMC PX6-300d. The manual installation is the completed project outcome; documentation corrections may still be made without reopening development.
