# Builds dist\AlecTools.mzp from AlecTools\ + installer\. Run build.bat (or this file) on the dev PC.
$ErrorActionPreference = 'Stop'
$root  = Split-Path $PSScriptRoot -Parent
$dist  = Join-Path $root 'dist'
$stage = Join-Path $dist 'stage'

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory $stage | Out-Null

Copy-Item (Join-Path $root 'AlecTools') $stage -Recurse
Copy-Item (Join-Path $root 'installer\*') $stage

$hash = ''
$dirty = ''
try {
    $hash = (git -C $root rev-parse --short HEAD).Trim()
    if (git -C $root status --porcelain) { $dirty = '+dirty' }
} catch { $hash = 'nogit' }
$ver = (Get-Date -Format 'yyyy-MM-dd HH:mm') + ' ' + $hash + $dirty
Set-Content (Join-Path $stage 'AlecTools\version.txt') $ver -Encoding ascii

# mzp = zip with mzp.run at the archive root
$zip = Join-Path $dist 'AlecTools.zip'
$names = Get-ChildItem $stage | ForEach-Object Name
tar -a -c -f $zip -C $stage @names
if ($LASTEXITCODE -ne 0) { throw "tar failed" }
Move-Item $zip (Join-Path $dist 'AlecTools.mzp')
# copy in the repo root too: that one is committed, so it can be downloaded from GitHub
Copy-Item (Join-Path $dist 'AlecTools.mzp') (Join-Path $root 'AlecTools.mzp') -Force

Write-Host "Built dist\AlecTools.mzp and AlecTools.mzp  ($ver)"
