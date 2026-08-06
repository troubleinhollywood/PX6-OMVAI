Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$WslRoot = if ($env:PX6_OMVAI_WSL_ROOT) {
    $env:PX6_OMVAI_WSL_ROOT
}
else {
    '~/PX6-OMVAI-linux'
}

function Read-PasswordHash {
    $first = Read-Host 'Create admin password' -AsSecureString
    $second = Read-Host 'Confirm admin password' -AsSecureString

    $firstPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($first)
    $secondPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($second)

    try {
        $firstPlaintext = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            $firstPointer
        )

        $secondPlaintext = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            $secondPointer
        )

        if ($firstPlaintext -cne $secondPlaintext) {
            throw 'Passwords do not match.'
        }

        if ($firstPlaintext.Length -lt 12) {
            throw 'Password must contain at least 12 characters.'
        }

        $passwordBytes = [Text.Encoding]::UTF8.GetBytes($firstPlaintext)
        $passwordBase64 = [Convert]::ToBase64String($passwordBytes)

        $hashCommand = "printf '%s' '$passwordBase64' | base64 -d | openssl passwd -6 -stdin"

        $hash = (
            & wsl.exe bash -lc $hashCommand
        ).Trim()

        if ($LASTEXITCODE -ne 0) {
            throw 'SHA-512 password hashing failed in WSL.'
        }

        if ($hash -notmatch '^\$6\$[A-Za-z0-9./]{1,16}\$[A-Za-z0-9./]{40,}$') {
            throw 'WSL returned an invalid SHA-512 crypt password hash.'
        }

        return $hash
    }
    finally {
        if ($firstPointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($firstPointer)
        }

        if ($secondPointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secondPointer)
        }

        $firstPlaintext = $null
        $secondPlaintext = $null
        $passwordBytes = $null
        $passwordBase64 = $null
        $first = $null
        $second = $null

        [GC]::Collect()
    }
}

function Read-SshChoice {
    while ($true) {
        $answer = (
            Read-Host 'Allow SSH access for admin? [Y/n]'
        ).Trim().ToLowerInvariant()

        if (
            $answer -eq '' -or
            $answer -eq 'y' -or
            $answer -eq 'yes'
        ) {
            return 'yes'
        }

        if (
            $answer -eq 'n' -or
            $answer -eq 'no'
        ) {
            return 'no'
        }

        Write-Warning 'Enter Y or N.'
    }
}

function Invoke-Wsl {
    param(
        [Parameter(Mandatory)]
        [string] $Command
    )

    & wsl.exe bash -lc "cd -- $WslRoot && $Command"

    if ($LASTEXITCODE -ne 0) {
        throw "WSL command failed with exit code $LASTEXITCODE."
    }
}

function Resolve-WslBuildRoot {
    $resolvedRoot = (
        & wsl.exe bash -lc "cd -- $WslRoot && pwd"
    ).Trim()

    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($resolvedRoot)
    ) {
        throw 'Could not resolve the WSL build directory.'
    }

    return $resolvedRoot
}

function Invoke-PersonalizedWslBuild {
    param(
        [Parameter(Mandatory)]
        [string] $Hash,

        [Parameter(Mandatory)]
        [ValidateSet('yes', 'no')]
        [string] $Ssh
    )

    $resolvedRoot = Resolve-WslBuildRoot
    $buildScript = "$resolvedRoot/build.sh"

    & wsl.exe test -x $buildScript

    if ($LASTEXITCODE -ne 0) {
        throw "The WSL build script is missing or not executable at $buildScript."
    }

    $hashArgument = "PX6_ADMIN_PASSWORD_HASH=$Hash"
    $sshArgument = "PX6_ENABLE_SSH=$Ssh"

    & wsl.exe `
        --exec `
        sudo `
        env `
        $hashArgument `
        $sshArgument `
        $buildScript `
        all

    if ($LASTEXITCODE -ne 0) {
        throw "Personalized WSL build failed with exit code $LASTEXITCODE."
    }
}

function Resolve-BuiltIsoPath {
    $resolvedRoot = Resolve-WslBuildRoot

    $outputIso = (
        & wsl.exe `
            --exec `
            bash `
            -c `
            'source "$1/config/build.conf" && printf "%s" "$OUTPUT_ISO"' `
            _ `
            $resolvedRoot
    ).Trim()

    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($outputIso)
    ) {
        throw 'Could not read OUTPUT_ISO from the WSL build configuration.'
    }

    $isoLinux = (
        & wsl.exe `
            --exec `
            realpath `
            "$resolvedRoot/$outputIso"
    ).Trim()

    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($isoLinux)
    ) {
        throw 'Could not resolve the generated ISO path in WSL.'
    }

    & wsl.exe `
        --exec `
        test `
        -f `
        $isoLinux

    if ($LASTEXITCODE -ne 0) {
        throw "The generated ISO does not exist in WSL at $isoLinux."
    }

    $windowsOutputDirectory = Join-Path $Root 'output'
    $windowsIsoPath = Join-Path `
        $windowsOutputDirectory `
        ([IO.Path]::GetFileName($isoLinux))

    New-Item `
        -ItemType Directory `
        -Path $windowsOutputDirectory `
        -Force |
        Out-Null

    $windowsIsoLinuxPath = (
        & wsl.exe `
            --exec `
            wslpath `
            -u `
            $windowsIsoPath
    ).Trim()

    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($windowsIsoLinuxPath)
    ) {
        throw 'Could not convert the Windows output path for WSL.'
    }

    Write-Host "Copying completed ISO to $windowsIsoPath"

    & wsl.exe `
        --exec `
        cp `
        -- `
        $isoLinux `
        $windowsIsoLinuxPath

    if ($LASTEXITCODE -ne 0) {
        throw 'Could not copy the completed ISO from WSL to Windows.'
    }

    if (-not (Test-Path -LiteralPath $windowsIsoPath)) {
        throw "Copied ISO was not found at $windowsIsoPath."
    }

    $linuxHash = (
        & wsl.exe `
            --exec `
            sha256sum `
            $isoLinux
    ).Split()[0].ToUpperInvariant()

    $windowsHash = (
        Get-FileHash `
            -Algorithm SHA256 `
            -LiteralPath $windowsIsoPath
    ).Hash.ToUpperInvariant()

    if ($linuxHash -cne $windowsHash) {
        Remove-Item -LiteralPath $windowsIsoPath -Force

        throw (
            'The copied ISO failed SHA-256 verification. ' +
            "WSL hash $linuxHash, Windows hash $windowsHash."
        )
    }

    Write-Host "Copied ISO verification passed: $windowsHash"

    return $windowsIsoPath
}

$command = if ($args.Count -gt 0) {
    $args[0].ToLowerInvariant()
}
else {
    'personalized'
}

switch ($command) {
    'personalized' {
        $hash = Read-PasswordHash
        $ssh = Read-SshChoice

        Invoke-PersonalizedWslBuild `
            -Hash $hash `
            -Ssh $ssh

        $isoWindows = Resolve-BuiltIsoPath

        Write-Host ''
        Write-Host 'Personalized PX6-OMVAI ISO is ready.'
        Write-Host "ISO: $isoWindows"
        Write-Host ''
        Write-Host 'Write this ISO to a USB drive using Rufus in DD Image mode.'
    }

    'test' {
        Invoke-Wsl './build.sh test-personalization'
    }

    default {
        throw "Unknown command: $command"
    }
}
