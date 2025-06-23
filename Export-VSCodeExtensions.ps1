# ----------------- config -----------------
param([string]$OutDir = '.\vscode-offline\vsix')
$platform = 'linux-x64'          # '' = universal; linux-x64 / alpine-arm64 …
# ------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# If some module in your profile still calls Write-Warning
$WarningPreference = 'SilentlyContinue'   # hide any residual yellow lines

# Ensure TLS 1.2 is enabled (older .NET defaults to 1.0 / 1.1)
if (-not ([Net.ServicePointManager]::SecurityProtocol -band
          [Net.SecurityProtocolType]::Tls12)) {
    [Net.ServicePointManager]::SecurityProtocol +=
        [Net.SecurityProtocolType]::Tls12
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 1) list installed extensions
$extList = & code --list-extensions --show-versions |
           ForEach-Object {
               if ($_ -match '^(.+?)@(.+)$') {
                   [pscustomobject]@{ Id = $matches[1]; Version = $matches[2] }
               }
           }

# 2) build Marketplace REST URL
function Get-VsixUrl([string]$Id,[string]$Ver,[string]$Plat='') {
    $parts = $Id.Split('.',2)
    $url   = "https://marketplace.visualstudio.com/_apis/public/gallery/" +
             "publishers/$($parts[0])/vsextensions/$($parts[1])/$Ver/vspackage"
    if ($Plat) { $url += "?targetPlatform=$Plat" }
    return $url
}

# 3) download with fallback (all messages via Write-Host)
foreach ($ext in $extList) {
    $file = Join-Path $OutDir "$($ext.Id)-$($ext.Version).vsix"
    if (Test-Path $file) {
        Write-Host "skip $($ext.Id) $($ext.Version)"
        continue
    }

    $url   = Get-VsixUrl $ext.Id $ext.Version $platform
    $done  = $false

    try {
        Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
        Write-Host "ok   $($ext.Id) $($ext.Version)"
        $done = $true
    }
    catch {
        $needFallback =
            ($platform -ne '') -and
            (($_.Exception.Message -match 'no support for targetPlatform') `
              -or ($_.Exception.Response.StatusCode.value__ -eq 404))

        if ($needFallback) {
            try {
                $url = Get-VsixUrl $ext.Id $ext.Version          # universal build
                Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
                Write-Host "ok*  $($ext.Id) $($ext.Version) (universal)"
                $done = $true
            }
            catch {
                Write-Host "fail $($ext.Id) $($ext.Version)  $_"
            }
        }
        else {
            Write-Host "fail $($ext.Id) $($ext.Version)  $_"
        }
    }

    if (-not $done) { Remove-Item -ErrorAction Ignore $file }   # clean partial
}

Write-Host ""
Write-Host "All extensions cached under '$OutDir'."
