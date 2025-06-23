<#
.SYNOPSIS
  Download the VS Code Server and (if present) the CLI helper that match
  the version of VS Code installed on this machine.

.PARAMETER Commit
  Optional specific commit hash.  If omitted we detect it by running
  `code --version`.

.PARAMETER Channel
  VS Code update channel:  "stable" (default) or "insider".

.PARAMETER Arch
  Target CPU/OS triplet, e.g. linux-x64, linux-arm64, alpine-x64 …
  Defaults to "linux-x64" because most remote servers run x64 Linux;
  change if your offline box is different.

.PARAMETER OutDir
  Where to drop the files.  Defaults to ".\vscode-offline".
#>

param(
  [string]$Commit,
  [ValidateSet('stable','insider')][string]$Channel = 'stable',
  [string]$Arch    = 'linux-x64',
  [string]$OutDir  = '.\vscode-offline'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
mkdir -Force $OutDir | Out-Null

# ── 1. Figure out the commit ID ────────────────────────────────────────────────
if (-not $Commit) {
    $v = & code --version
    if ($LASTEXITCODE) { throw "Could not run 'code': $LASTEXITCODE" }
    $Commit = $v[1]          # 2nd line is the 40-char hash
}

Write-Host "Using commit $Commit"

# ── 2. Build download URLs ────────────────────────────────────────────────────
$base = "https://update.code.visualstudio.com/commit:$Commit"
$serverUrl = "$base/server-$Arch/$Channel"
$cliUrl    = "$base/cli-alpine-x64/$Channel"   # CLI is always alpine-based

# ── 3. Download  (Invoke-WebRequest works on any platform) ────────────────────
$serverFile = Join-Path $OutDir "vscode-server-$Arch-$Commit.tar.gz"
if (-not (Test-Path $serverFile)) {
    Write-Host "↓ VS Code Server → $serverFile"
    Invoke-WebRequest -Uri $serverUrl -OutFile $serverFile
}

$cliFile    = Join-Path $OutDir "vscode-cli-alpine-x64-$Commit.tar.gz"
if (-not (Test-Path $cliFile)) {
    Write-Host "↓ VS Code CLI    → $cliFile"
    Invoke-WebRequest -Uri $cliUrl -OutFile $cliFile
}

Write-Host "`nDone.  Copy the two .tar.gz files under '$OutDir' to your offline server."
