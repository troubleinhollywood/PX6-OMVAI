Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$WslRoot = if ($env:PX6_OMVAI_WSL_ROOT) { $env:PX6_OMVAI_WSL_ROOT } else { '~/PX6-OMVAI-linux' }

function Read-PasswordHash {
    $first = Read-Host 'Create admin password' -AsSecureString
    $second = Read-Host 'Confirm admin password' -AsSecureString
    $p1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($first))
    $p2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($second))
    try {
        if ($p1 -cne $p2) { throw 'Passwords do not match.' }
        if ($p1.Length -lt 12) { throw 'Password must contain at least 12 characters.' }
        $bytes = [Text.Encoding]::UTF8.GetBytes($p1)
        $base64 = [Convert]::ToBase64String($bytes)
        $command = "printf '%s' '$base64' | base64 -d | openssl passwd -6 -stdin"
        $hash = (& wsl.exe bash -lc $command).Trim()
        if ($LASTEXITCODE -ne 0 -or $hash -notmatch '^\$6\$') { throw 'SHA-512 password hashing failed in WSL. Ensure openssl is installed.' }
        return $hash
    }
    finally {
        $p1 = $null; $p2 = $null; $bytes = $null; $base64 = $null
        [GC]::Collect()
    }
}

function Read-SshChoice {
    $answer = (Read-Host 'Allow SSH access for admin? [Y/n]').Trim().ToLowerInvariant()
    if ($answer -eq '' -or $answer -eq 'y' -or $answer -eq 'yes') { return 'yes' }
    if ($answer -eq 'n' -or $answer -eq 'no') { return 'no' }
    throw 'Enter Y or N.'
}

function Invoke-Wsl([string]$Command) {
    & wsl.exe bash -lc "cd -- $WslRoot && $Command"
    if ($LASTEXITCODE -ne 0) { throw "WSL command failed: $Command" }
}

function Get-UsbDisks {
    @(Get-Disk | Where-Object { $_.BusType -eq 'USB' -and $_.OperationalStatus -ne 'Offline' } | Sort-Object Number)
}

function Select-UsbDisk {
    $disks = Get-UsbDisks
    if ($disks.Count -eq 0) { throw 'No online USB disk was detected.' }
    $disks | Format-Table Number,FriendlyName,SerialNumber,@{N='SizeGiB';E={[math]::Round($_.Size/1GB,2)}} -AutoSize
    $number = Read-Host 'Select USB device by disk number'
    if ($number -notmatch '^\d+$') { throw 'Disk number must be numeric.' }
    $disk = $disks | Where-Object Number -eq [int]$number
    if (-not $disk) { throw 'The selected disk is not an eligible USB disk.' }
    return $disk
}

function Write-AndVerifyUsb([string]$IsoPath,[Microsoft.Management.Infrastructure.CimInstance]$Disk) {
    $confirmation = Read-Host "Are you sure? This USB device will be erased. Type ERASE DISK $($Disk.Number)"
    if ($confirmation -cne "ERASE DISK $($Disk.Number)") { throw 'USB erase was not confirmed.' }
    $iso = Get-Item $IsoPath
    if ($Disk.Size -lt $iso.Length) { throw 'Selected USB disk is smaller than the ISO.' }
    $physical = "\\.\PhysicalDrive$($Disk.Number)"
    Set-Disk -Number $Disk.Number -IsOffline $true
    try {
        $source = [IO.File]::Open($iso.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        $target = [IO.File]::Open($physical,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::ReadWrite)
        try { $source.CopyTo($target,4MB); $target.Flush($true) } finally { $target.Dispose(); $source.Dispose() }
        $expected = (Get-FileHash -Algorithm SHA256 $iso.FullName).Hash
        $sha = [Security.Cryptography.SHA256]::Create()
        $stream = [IO.File]::Open($physical,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        try {
            $remaining = $iso.Length; $buffer = New-Object byte[] (4MB)
            while ($remaining -gt 0) {
                $want = [int][Math]::Min($buffer.Length,$remaining)
                $read = $stream.Read($buffer,0,$want)
                if ($read -le 0) { throw 'Unexpected end of USB device during verification.' }
                $sha.TransformBlock($buffer,0,$read,$null,0) | Out-Null
                $remaining -= $read
            }
            $sha.TransformFinalBlock([byte[]]::new(0),0,0) | Out-Null
            $actual = [BitConverter]::ToString($sha.Hash).Replace('-','')
        } finally { $stream.Dispose(); $sha.Dispose() }
        if ($actual -cne $expected) { throw "USB verification failed. Expected $expected, received $actual" }
        Write-Host "USB verification passed: $actual"
    }
    finally { Set-Disk -Number $Disk.Number -IsOffline $false }
}

$command = if ($args.Count) { $args[0].ToLowerInvariant() } else { 'personalized-usb' }
switch ($command) {
    'personalized-usb' {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run PowerShell as Administrator.' }
        $hash = Read-PasswordHash
        $ssh = Read-SshChoice
        $disk = Select-UsbDisk
        $escapedHash = $hash
        Invoke-Wsl "PX6_ADMIN_PASSWORD_HASH='$escapedHash' PX6_ENABLE_SSH='$ssh' sudo -E ./build.sh all"
        $isoLinux = (& wsl.exe bash -lc "cd -- $WslRoot && source config/build.conf && realpath `"`$OUTPUT_ISO`"").Trim()
        $isoWindows = (& wsl.exe wslpath -w $isoLinux).Trim()
        if (-not (Test-Path $isoWindows)) { throw "Built ISO was not found at $isoWindows" }
        Write-AndVerifyUsb $isoWindows $disk
        Write-Host 'Personalized PX6-OMVAI USB is complete.'
    }
    'test' { Invoke-Wsl './build.sh test-personalization' }
    default { throw "Unknown command: $command" }
}
