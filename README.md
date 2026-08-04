# PX6-OMVAI

Build tooling for a Debian 13.6 based unattended OpenMediaVault installer for the LenovoEMC/Iomega PX6-300d.

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
