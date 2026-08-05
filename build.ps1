Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $Root "config/build.conf"

function Read-BuildConfig {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path $Path)) {
        throw "Build configuration not found at $Path"
    }

    $Config = @{}

    foreach ($Line in Get-Content $Path) {
        $Trimmed = $Line.Trim()

        if (-not $Trimmed -or $Trimmed.StartsWith("#")) {
            continue
        }

        if ($Trimmed -notmatch '^([A-Z0-9_]+)="(.*)"$') {
            throw "Invalid build configuration line: $Line"
        }

        $Config[$Matches[1]] = $Matches[2]
    }

    return $Config
}

function Resolve-ProjectPath {
    param(
        [Parameter(Mandatory)]
        [string] $RelativePath
    )

    return Join-Path $Root $RelativePath
}

function Show-Usage {
    Write-Host "PX6-OMVAI build framework"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\build.ps1 <command>"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  check"
    Write-Host "  prepare"
    Write-Host "  clean"
    Write-Host "  status"
    Write-Host "  all"
    Write-Host "  help"
}

function Test-BuildDependencies {
    $Required = @(
        "git"
    )

    $Missing = @()

    foreach ($CommandName in $Required) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            $Missing += $CommandName
        }
    }

    if ($Missing.Count -gt 0) {
        Write-Error (
            "Missing dependencies: " +
            ($Missing -join ", ")
        )
    }

    Write-Host "[PX6-OMVAI] All required PowerShell-side dependencies are available"
}

function Prepare-BuildDirectories {
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config
    )

    $Directories = @(
        $Config["CACHE_DIR"],
        $Config["BUILD_DIR"],
        $Config["OUTPUT_DIR"],
        $Config["ISO_WORK_DIR"],
        $Config["INITRD_WORK_DIR"]
    )

    foreach ($Directory in $Directories) {
        $Path = Resolve-ProjectPath $Directory
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    Write-Host "[PX6-OMVAI] Prepared build directories"
}

function Clear-GeneratedFiles {
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config
    )

    foreach ($Key in @("BUILD_DIR", "OUTPUT_DIR")) {
        $Path = Resolve-ProjectPath $Config[$Key]

        if (Test-Path $Path) {
            Remove-Item $Path -Recurse -Force
        }

        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    Write-Host "[PX6-OMVAI] Removed generated build and output files"
}

function Show-BuildStatus {
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config
    )

    Write-Host "Project: $($Config['PROJECT_NAME'])"
    Write-Host "Version: $($Config['PROJECT_VERSION'])"
    Write-Host "Debian: $($Config['DEBIAN_VERSION']) $($Config['DEBIAN_ARCH'])"
    Write-Host "Cache: $(Resolve-ProjectPath $Config['CACHE_DIR'])"
    Write-Host "Build: $(Resolve-ProjectPath $Config['BUILD_DIR'])"
    Write-Host "Output: $(Resolve-ProjectPath $Config['OUTPUT_DIR'])"
    Write-Host "Output ISO: $(Resolve-ProjectPath $Config['OUTPUT_ISO'])"
}

$Config = Read-BuildConfig $ConfigPath
$CommandName = if ($args.Count -gt 0) { $args[0] } else { "help" }

switch ($CommandName) {
    "check" {
        Test-BuildDependencies
    }

    "prepare" {
        Prepare-BuildDirectories $Config
    }

    "clean" {
        Clear-GeneratedFiles $Config
    }

    "status" {
        Show-BuildStatus $Config
    }

    "all" {
        Test-BuildDependencies
        Prepare-BuildDirectories $Config
    }

    { $_ -in @("help", "-h", "--help") } {
        Show-Usage
    }

    default {
        Show-Usage
        throw "Unknown build command: $CommandName"
    }
}