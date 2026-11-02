param(
 [string]$LuauDirectory='C:\Users\dev\AppData\Local\Temp\anime-fight-luau-0.744',
 [string]$LuauLspDirectory='C:\Users\dev\AppData\Local\Temp\anime-fight-luau-lsp-1.70.1'
)
$ErrorActionPreference='Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
 New-Item -ItemType Directory -Force build | Out-Null
 $pure=@('NarutoAdvanced','NarutoRankPolicy','NarutoCloneRanks','SkillLearning','NarutoLegend','CloneNavigation','CombatState')
 $modules=@('src/shared/Abilities/RasenganVariants.luau','src/shared/Abilities/SleepState.luau','src/shared/Abilities/NarutoAdvancedCatalog.luau','src/shared/Abilities/CloneCastPlan.luau','src/shared/Abilities/RasenganState.luau','src/shared/Abilities/NarutoRankPolicy.luau','src/shared/Abilities/SkillLearning.luau')
 & (Join-Path $LuauDirectory 'luau-analyze.exe') @modules @($pure | ForEach-Object {"tests/$_.spec.luau"})
 if ($LASTEXITCODE -ne 0) {throw 'Advanced domain types failed'}
 foreach ($suite in $pure) {
  & (Join-Path $LuauDirectory 'luau.exe') "tests/$suite.spec.luau"
  if ($LASTEXITCODE -ne 0) {throw "Failed $suite"}
 }
 rojo build tests/advanced.project.json -o build/advanced-tests.rbxlx
 if ($LASTEXITCODE -ne 0) {throw 'Advanced fixture build failed'}
 rojo sourcemap default.project.json -o build/sourcemap.json
 if ($LASTEXITCODE -ne 0) {throw 'Production sourcemap failed'}
 $runtime=@('NarutoAbilityService','NarutoSleepService','RasenshurikenMeleeService','FighterStateService','CombatService','DamageService','AbilityService','MinionAIService','GamakichiService','NarutoSummonService') | ForEach-Object {"src/server/Services/$_.luau"}
 $runtime+=@('src/client/Controllers/AbilityController.luau','src/client/Controllers/AbilityHUDController.luau','src/client/Controllers/AbilityVFXController.luau')
 & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap build/sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') @runtime
 if ($LASTEXITCODE -ne 0) {throw 'Advanced runtime types failed'}
 rojo sourcemap tests/advanced.project.json -o build/advanced-sourcemap.json
 if ($LASTEXITCODE -ne 0) {throw 'Fixture sourcemap failed'}
 Push-Location tests
 try {
  & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/advanced-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') advanced
  if ($LASTEXITCODE -ne 0) {throw 'Advanced fixture types failed'}
 } finally {Pop-Location}
 Write-Output 'PASS Advanced headless checks. Studio runtime and visual QA NOT RUN.'
} finally {Pop-Location}
