# Personalized unattended USB

Run Windows PowerShell as Administrator from `E:\PX6-OMVAI`.

```powershell
.\build.ps1 personalized-usb
```

The command asks for the admin password twice, asks whether SSH should be enabled, lists eligible USB disks, and requires an exact destructive confirmation. The plaintext password is held only in process memory long enough to create a salted SHA-512 crypt hash. Only the hash and the SSH choice enter the Linux build tree and installer initrd.

The USB writer accepts only disks reported by Windows as `BusType USB`. It writes the rebuilt ISO to the selected physical disk and verifies SHA-256 over exactly the number of bytes in the ISO.

Static test

```powershell
.\build.ps1 test
```

Expected output

```text
[PX6-OMVAI] Generated personalized installer configuration
PASS: personalized installer configuration is valid
```