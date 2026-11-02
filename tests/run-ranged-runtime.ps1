param(
 [string]$LuauDirectory='C:\Users\dev\AppData\Local\Temp\anime-fight-luau-0.744',
 [string]$LuauLspDirectory='C:\Users\dev\AppData\Local\Temp\anime-fight-luau-lsp-1.70.1'
)
$ErrorActionPreference='Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
 New-Item -ItemType Directory -Force build | Out-Null
 $suites=@('NarutoRanged','NarutoRangedInput','NarutoKcmAdapter','NarutoKcmGameplay','NarutoKcm','HUDLayout')
 & (Join-Path $LuauDirectory 'luau-analyze.exe') src/shared/Abilities/NarutoRangedState.luau src/shared/Abilities/NarutoKcmAdapter.luau @($suites | ForEach-Object {"tests/$_.spec.luau"})
 if ($LASTEXITCODE -ne 0) {throw 'Ranged focused domain types failed'}
 foreach ($suite in $suites) {
  & (Join-Path $LuauDirectory 'luau.exe') "tests/$suite.spec.luau"
  if ($LASTEXITCODE -ne 0) {throw "Failed $suite"}
 }
 rojo build tests/ranged-runtime.project.json -o build/ranged-runtime-tests.rbxlx
 if ($LASTEXITCODE -ne 0) {throw 'Ranged fixture build failed'}
 rojo sourcemap default.project.json -o build/sourcemap.json
 if ($LASTEXITCODE -ne 0) {throw 'Production sourcemap failed'}
 $files=@('NarutoRangedService','NarutoKcmService','NarutoAbilityService','AbilityService') | ForEach-Object {"src/server/Services/$_.luau"}
 $files+=@('NarutoRangedVFXController','AbilityVFXController','AbilityController','AbilityHUDController','HeroMotionController') | ForEach-Object {"src/client/Controllers/$_.luau"}
 & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap build/sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') @files
 if ($LASTEXITCODE -ne 0) {throw 'Ranged runtime types failed'}
 rojo sourcemap tests/ranged-runtime.project.json -o build/ranged-runtime-sourcemap.json
 if ($LASTEXITCODE -ne 0) {throw 'Fixture sourcemap failed'}
 Push-Location tests
 try {
  & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/ranged-runtime-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') ranged-runtime
  if ($LASTEXITCODE -ne 0) {throw 'Ranged fixture types failed'}
 } finally {Pop-Location}
 Write-Output 'PASS Ranged focused headless checks. Studio/network/visual/performance QA NOT RUN.'
} finally {Pop-Location}
