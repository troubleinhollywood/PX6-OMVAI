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

function Get-GitBashPath {
    $Candidates = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files\Git\usr\bin\bash.exe"
    )

    foreach ($Candidate in $Candidates) {
        if (Test-Path $Candidate) {
            return $Candidate
        }
    }

    throw "Git Bash was not found. Install Git for Windows."
}

function Invoke-BashScript {
    param(
        [Parameter(Mandatory)]
        [string] $RelativeScriptPath,

        [string[]] $Arguments = @()
    )

    $Bash = Get-GitBashPath
    $ScriptPath = Resolve-ProjectPath $RelativeScriptPath

    if (-not (Test-Path $ScriptPath)) {
        throw "Required script not found at $ScriptPath"
    }

    & $Bash $ScriptPath @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "$RelativeScriptPath failed with exit code $LASTEXITCODE"
    }
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
    Write-Host "  download"
    Write-Host "  verify"
    Write-Host "  extract"
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

    try {
        $null = Get-GitBashPath
    }
    catch {
        $Missing += "Git Bash"
    }

    if ($Missing.Count -gt 0) {
        throw "Missing dependencies: $($Missing -join ', ')"
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
        if (-not $Directory) {
            throw "A required build directory is missing from config/build.conf"
        }

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
        $RelativePath = $Config[$Key]

        if (-not $RelativePath) {
            throw "Missing configuration value: $Key"
        }

        $Path = Resolve-ProjectPath $RelativePath

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
    Write-Host "Debian ISO: $($Config['DEBIAN_ISO_NAME'])"
    Write-Host "Cache: $(Resolve-ProjectPath $Config['CACHE_DIR'])"
    Write-Host "Build: $(Resolve-ProjectPath $Config['BUILD_DIR'])"
    Write-Host "ISO work directory: $(Resolve-ProjectPath $Config['ISO_WORK_DIR'])"
    Write-Host "Initrd work directory: $(Resolve-ProjectPath $Config['INITRD_WORK_DIR'])"
    Write-Host "Output: $(Resolve-ProjectPath $Config['OUTPUT_DIR'])"
    Write-Host "Output ISO: $(Resolve-ProjectPath $Config['OUTPUT_ISO'])"
}

function Download-DebianIso {
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config
    )

    Prepare-BuildDirectories $Config
    Invoke-BashScript "scripts/download_iso.sh"
}

function Test-DebianIso {
    Invoke-BashScript "scripts/verify_iso.sh"
}

function Expand-DebianIso {
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config
    )

    Prepare-BuildDirectories $Config
    Test-DebianIso
    Invoke-BashScript "scripts/extract_iso.sh"
}

$Config = Read-BuildConfig $ConfigPath
$CommandName = if ($args.Count -gt 0) {
    $args[0].ToLowerInvariant()
}
else {
    "help"
}

switch ($CommandName) {
    "check" {
        Test-BuildDependencies
    }

    "prepare" {
        Prepare-BuildDirectories $Config
    }

    "download" {
        Download-DebianIso $Config
    }

    "verify" {
        Test-DebianIso
    }

    "extract" {
        Expand-DebianIso $Config
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
        Invoke-BashScript "scripts/download_iso.sh"
        Invoke-BashScript "scripts/verify_iso.sh"
        Invoke-BashScript "scripts/extract_iso.sh"
    }

    { $_ -in @("help", "-h", "--help") } {
        Show-Usage
    }

    default {
        Show-Usage
        throw "Unknown build command: $CommandName"
    }
}
