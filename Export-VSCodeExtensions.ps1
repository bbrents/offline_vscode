<#
    Offline VS Code extension downloader with automatic fallback to universal builds.

    USAGE EXAMPLES
    --------------
    # Grab platform-specific builds when they exist and fall back to the universal VSIX
    # (default behaviour – platform = "linux-x64")
    .\Get-VSCodeExtensionsOffline.ps1

    # Always download the universal builds (no targetPlatform query)
    .\Get-VSCodeExtensionsOffline.ps1 -Platform ''

    # Cache extensions for Alpine ARM64, falling back to universal if required
    .\Get-VSCodeExtensionsOffline.ps1 -Platform 'alpine-arm64' -OutDir .\my-cache
#>

param(
    [string]$OutDir    = '.\vscode-offline\vsix',
    [string]$Platform  = 'linux-x64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Hide sporadic warnings from imported profiles
$WarningPreference     = 'SilentlyContinue'

# Ensure TLS 1.2 for Invoke-WebRequest on older PowerShell / .NET builds
if (-not ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12)) {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Get-VsixUrl {
    <#  Compose the Marketplace REST URL for a given extension version.
        When $Plat is the empty string we omit the targetPlatform query, producing
        the universal VSIX download link. #>
    param(
        [string]$Id,
        [string]$Ver,
        [string]$Plat
    )
    $parts = $Id.Split('.', 2)
    $url   = "https://marketplace.visualstudio.com/_apis/public/gallery/" +
             "publishers/$($parts[0])/vsextensions/$($parts[1])/$Ver/vspackage"
    if ($Plat) { $url += "?targetPlatform=$Plat" }
    return $url
}

function Try-Download {
    <# Attempt to download the VSIX for $Ext and $Plat to $File.
       Returns $true on success, $false on any failure. #>
    param(
        [pscustomobject]$Ext,
        [string]$Plat,
        [string]$File
    )
    $url = Get-VsixUrl $Ext.Id $Ext.Version $Plat

    try {
        Invoke-WebRequest -Uri $url -OutFile $File -UseBasicParsing -ErrorAction Stop
        if ($Plat) {
            Write-Host "ok   $($Ext.Id) $($Ext.Version)"
        } else {
            Write-Host "ok*  $($Ext.Id) $($Ext.Version) (universal)"
        }
        return $true
    }
    catch {
        # Fail silently; the caller decides whether to retry without platform.
        return $false
    }
}

# ---- MAIN ------------------------------------------------------------------

$extList = & code --list-extensions --show-versions | ForEach-Object {
    if ($_ -match '^(.+?)@(.+)$') {
        [pscustomobject]@{ Id = $matches[1]; Version = $matches[2] }
    }
}

foreach ($ext in $extList) {
    $file = Join-Path $OutDir "$($ext.Id)-$($ext.Version).vsix"

    if (Test-Path $file) {
        Write-Host "skip $($ext.Id) $($ext.Version)"
        continue
    }

    $downloaded = $false

    # 1️⃣  Try platform-specific build first (if caller asked for one)
    if ($Platform) {
        $downloaded = Try-Download $ext $Platform $file
    }

    # 2️⃣  Fall back to the universal build when the above fails
    if (-not $downloaded) {
        $downloaded = Try-Download $ext '' $file
    }

    # 3️⃣  Give up and tidy partial downloads
    if (-not $downloaded) {
        Write-Host "fail $($ext.Id) $($ext.Version)"
        Remove-Item -ErrorAction Ignore $file
    }
}

Write-Host "\nAll extensions cached under '$OutDir'."
