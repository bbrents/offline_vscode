# ----------------- config -----------------
param([string]$OutDir = '.\vscode-offline\vsix')
$platform = ''            # '' = universal, or e.g. 'linux-x64'
# ------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory $OutDir -Force | Out-Null

# enable TLS 1.2 on old PowerShell / .NET versions
if (-not ([Net.ServicePointManager]::SecurityProtocol -band
          [Net.SecurityProtocolType]::Tls12)) {
    [Net.ServicePointManager]::SecurityProtocol +=
        [Net.SecurityProtocolType]::Tls12
}

# 1) list installed extensions
$extList = & code --list-extensions --show-versions |
           ForEach-Object {
               if ($_ -match '^(.+?)@(.+)$') {
                   [pscustomobject]@{ Id = $matches[1]; Version = $matches[2] }
               }
           }

# 2) REST URL builder
function Get-VsixUrl($Id,$Ver,$Plat='') {
    $p = $Id.Split('.',2)
    $u = "https://marketplace.visualstudio.com/_apis/public/gallery/" +
         "publishers/$($p[0])/vsextensions/$($p[1])/$Ver/vspackage"
    if ($Plat) { $u += "?targetPlatform=$Plat" }
    return $u
}

# 3) download
foreach ($ext in $extList) {
    $file = Join-Path $OutDir "$($ext.Id)-$($ext.Version).vsix"
    if (-not (Test-Path $file)) {
        Write-Host "-> $($ext.Id)@$($ext.Version)"
        Invoke-WebRequest -Uri (Get-VsixUrl $ext.Id $ext.Version $platform) `
                          -OutFile $file
    }
}

Write-Host "`nAll extensions cached under '$OutDir'."
