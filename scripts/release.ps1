param([string]$RojoPath)
$ErrorActionPreference = 'Stop'
$releaseRoot = Split-Path $PSScriptRoot -Parent
if (-not $RojoPath) { $RojoPath = Join-Path $env:USERPROFILE '.aftman/tool-storage/rojo-rbx/rojo/7.7.1/rojo.exe' }
Push-Location $releaseRoot
try {
 New-Item -ItemType Directory -Force releases | Out-Null
 & $RojoPath build development.project.json -o releases/Naruto-Legend-Development.rbxlx
 if ($LASTEXITCODE -ne 0) { throw 'Development release build failed' }
 & $RojoPath build default.project.json -o releases/Naruto-Legend-Game.rbxlx
 if ($LASTEXITCODE -ne 0) { throw 'Game release build failed' }
 Get-FileHash releases/Naruto-Legend-Development.rbxlx, releases/Naruto-Legend-Game.rbxlx -Algorithm SHA256 | Select-Object Path,Hash
} finally { Pop-Location }
