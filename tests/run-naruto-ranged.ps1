param([string]$LuauDirectory='C:\Users\dev\AppData\Local\Temp\anime-fight-luau-0.744')
$ErrorActionPreference='Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
 & (Join-Path $LuauDirectory 'luau-analyze.exe') src/shared/Abilities/NarutoRangedState.luau src/shared/Abilities/ChakraKnifeInstancePolicy.luau tests/NarutoRanged.spec.luau
 if ($LASTEXITCODE -ne 0) {throw 'Naruto ranged domain types failed'}
 & (Join-Path $LuauDirectory 'luau.exe') tests/NarutoRanged.spec.luau
 if ($LASTEXITCODE -ne 0) {throw 'Naruto ranged contract tests failed'}
 Write-Output 'PASS Naruto ranged domain/types. No runtime exposure, Studio or native execution.'
} finally {Pop-Location}
