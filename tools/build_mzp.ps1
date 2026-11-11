# Builds AlecTools.mzp in the repo root from AlecTools\ + installer\ (dist\ is a temp folder, removed at the end). Run build.bat (or this file) on the dev PC.
$ErrorActionPreference = 'Stop'
$root  = Split-Path $PSScriptRoot -Parent
$dist  = Join-Path $root 'dist'
$stage = Join-Path $dist 'stage'

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory $stage | Out-Null

Copy-Item (Join-Path $root 'AlecTools') $stage -Recurse
Copy-Item (Join-Path $root 'installer\*') $stage
# local leftovers stay out: Max Settings backups (the exported AlecSettings.zip goes, it carries the settings to the laptop) and Python caches
$leftovers = @(Get-ChildItem (Join-Path $stage 'AlecTools') -Recurse -Force | Where-Object { $_.Name -like 'AlecSettings-backup-*.zip' -or $_.Name -eq '__pycache__' })
$leftovers | Where-Object { Test-Path $_.FullName } | Remove-Item -Recurse -Force

$ver = Get-Date -Format 'yyyy-MM-dd HH:mm'
Set-Content (Join-Path $stage 'AlecTools\version.txt') $ver -Encoding ascii

# mzp = zip with mzp.run at the archive root
$zip = Join-Path $dist 'AlecTools.zip'
$names = Get-ChildItem $stage | ForEach-Object Name
tar -a -c -f $zip -C $stage @names
if ($LASTEXITCODE -ne 0) { throw "tar failed" }
Move-Item $zip (Join-Path $dist 'AlecTools.mzp')
# copy in the repo root too: that one is committed, so it can be downloaded from GitHub
Copy-Item (Join-Path $dist 'AlecTools.mzp') (Join-Path $root 'AlecTools.mzp') -Force
Remove-Item $dist -Recurse -Force

Write-Host "Built AlecTools.mzp in the repo root  ($ver)"
