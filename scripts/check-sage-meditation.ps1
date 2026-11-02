param(
 [string]$LuauDirectory = 'C:\Users\dev\AppData\Local\Temp\anime-fight-luau-0.744',
 [string]$LuauLspDirectory = 'C:\Users\dev\AppData\Local\Temp\anime-fight-luau-lsp-1.70.1',
 [string]$RojoPath = 'C:\Users\dev\.aftman\tool-storage\rojo-rbx\rojo\7.7.1\rojo.exe'
)
$ErrorActionPreference='Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
 $pure=@('src/shared/Abilities/SageState.luau','src/shared/Abilities/MeditationState.luau','src/shared/Abilities/SkillLearning.luau','src/shared/Combat/HeroPoses.luau')
 $suites=@('tests/Sage.spec.luau','tests/Meditation.spec.luau','tests/SkillLearning.spec.luau')
 $runtime=@('src/server/Services/MeditationCloneService.luau','src/server/Services/NarutoAbilityService.luau','src/server/Services/AbilityService.luau','src/server/Services/DamageService.luau','src/server/Services/AbilityTargetService.luau','src/client/Controllers/AbilityController.luau','src/client/Controllers/HeroMotionController.luau')
 foreach ($file in ($pure+$suites+$runtime+@('src/shared/Config/AbilityConfig.luau','src/shared/Config/HeroConfig.luau','tests/meditation/Runner.server.luau'))) {
  & (Join-Path $LuauDirectory 'luau-compile.exe') --null $file
  if ($LASTEXITCODE -ne 0) { throw "Compile failed: $file" }
 }
 & (Join-Path $LuauDirectory 'luau-analyze.exe') @pure @suites
 if ($LASTEXITCODE -ne 0) { throw 'Pure type check failed' }
 foreach ($suite in $suites) {
  & (Join-Path $LuauDirectory 'luau.exe') $suite
  if ($LASTEXITCODE -ne 0) { throw "Suite failed: $suite" }
 }
 & $RojoPath build default.project.json -o build/sage-meditation-production.rbxlx
 if ($LASTEXITCODE -ne 0) { throw 'Production build failed' }
 & $RojoPath sourcemap default.project.json -o build/sourcemap.json
 if ($LASTEXITCODE -ne 0) { throw 'Production sourcemap failed' }
 & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap build/sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') @runtime
 if ($LASTEXITCODE -ne 0) { throw 'Runtime type check failed' }
 & $RojoPath build tests/meditation.project.json -o build/meditation-tests.rbxlx
 if ($LASTEXITCODE -ne 0) { throw 'Fixture build failed' }
 & $RojoPath sourcemap tests/meditation.project.json -o build/meditation-sourcemap.json
 if ($LASTEXITCODE -ne 0) { throw 'Fixture sourcemap failed' }
 Push-Location tests
 try {
  & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/meditation-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') meditation
  if ($LASTEXITCODE -ne 0) { throw 'Fixture type check failed' }
 } finally { Pop-Location }
 Write-Output 'PASS focused Sage/meditation checks. Studio fixture prepared; engine validation pending integrator.'
} finally { Pop-Location }
