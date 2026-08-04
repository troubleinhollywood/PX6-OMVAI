# Build work remaining

1. Download Debian 13 AMD64 netinst.
2. Unpack the Debian Installer initrd.
3. Add `/preseed.cfg`.
4. Add executable scripts under `/usr/local/sbin/`.
5. Verify every selector dependency exists in Debian Installer.
6. Repack the initrd and ISO.
7. Run the complete test plan.
