# PX6-OMVAI

Build tooling for a Debian 13.6 based unattended OpenMediaVault installer for the LenovoEMC/Iomega PX6-300d.

## PX6 serial console connection (UART)

The PX6-300d has an internal serial header identified as `SERIAL_B` in the independent hardware reference below. This reference photograph shows the motherboard connection.

[![PX6-300d SERIAL_B motherboard header with serial wiring (external reference photograph)](https://open-desk.org/posts/linux-on-lenovo-emc-px6-300d/px6_serial_connector.png)](https://open-desk.org/posts/linux-on-lenovo-emc-px6-300d/)

*Photograph and hardware reference: [Dustin Frisch, “Linux on Lenovo-EMC PX6-300d”](https://open-desk.org/posts/linux-on-lenovo-emc-px6-300d/). The image is displayed from its original site and is not copied into this repository. If the original site becomes unavailable, the image may stop displaying.*

A compatible USB-to-TTL UART serial adapter can connect a computer to the NAS console. **Confirm the pinout and logic voltage on your particular board before connecting anything.** In a typical three-wire TTL connection, the board TX connects to adapter RX, board RX to adapter TX, and GND to GND. **Do not connect the adapter's VCC/power lead.** Never connect an RS-232 voltage-level adapter directly to a TTL header.

The linked guide describes a serial console at **115200 baud, 8 data bits, no parity, 1 stop bit (115200 8N1)**. These details are a third-party reference, not yet a verified record of this repository's own PX6 conversion wiring.

### Example USB-to-UART TTL cable

![Example FTDI USB-to-TTL serial cable with header connector](https://commons.wikimedia.org/wiki/Special:FilePath/FTDI_Cable.jpg?width=960)

*Example cable photograph by [oomlout](https://commons.wikimedia.org/wiki/File:FTDI_Cable.jpg), licensed under [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/). Shown for illustration only; this is not a confirmed photograph of the exact adapter used for our PX6 conversion. No changes were made to the photograph.*

This pictured cable has a six-position connector, whereas the PX6 reference describes a four-pin header. **Do not plug the connector onto the board by matching its shape or wire colors.** Identify the adapter's TX, RX, and GND contacts from its documentation and verify the board pinout and signal levels before making a three-wire connection. Leave VCC disconnected.

## v0.2 roadmap

1. Set up the repository structure.
2. Create `build.sh` and `build.ps1`.
3. Download and extract the Debian 13.6 installer ISO automatically.
4. Modify the installer initrd.
5. Embed the preseed and PX6 support scripts.
6. Add serial-console support.
7. Rebuild the bootable ISO.
8. Test the ISO in a virtual machine.
9. Test on the PX6 with only the operating-system drive installed.
10. Confirm OpenMediaVault works, then import the existing RAID.

## Development rules

- Each feature is committed separately.
- Destructive PX6 testing is delayed until VM testing passes.
- Initial PX6 testing uses only the operating-system drive.
- Existing RAID members remain disconnected until OpenMediaVault is confirmed working.
- Build inputs and generated outputs are kept separate.
