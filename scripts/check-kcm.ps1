param([string]$LuauDirectory,[string]$LuauLspDirectory,[string]$RojoPath)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
if(-not $LuauDirectory){$LuauDirectory=Join-Path $env:LOCALAPPDATA 'Temp/anime-fight-luau-0.744'}
if(-not $LuauLspDirectory){$LuauLspDirectory=Join-Path $env:LOCALAPPDATA 'Temp/anime-fight-luau-lsp-1.70.1'}
if(-not $RojoPath){$RojoPath=Join-Path $env:USERPROFILE '.aftman/bin/rojo.exe'}
foreach($binary in @((Join-Path $LuauDirectory 'luau.exe'),(Join-Path $LuauDirectory 'luau-analyze.exe'),(Join-Path $LuauDirectory 'luau-compile.exe'),(Join-Path $LuauLspDirectory 'luau-lsp.exe'),$RojoPath)){
 if(-not (Test-Path -LiteralPath $binary)){throw "Existing official CLI required: $binary"}
}
Push-Location $repo
try {
 $pure=@('src/shared/Abilities/NarutoKcmConfig.luau','src/shared/Abilities/NarutoKcmState.luau','src/shared/Abilities/NarutoKcmAdapter.luau','src/shared/Abilities/NarutoKcmGameplay.luau')
 $suites=@('NarutoKcm','NarutoKcmAdapter','NarutoKcmGameplay','SkillLearning','Gamakichi','Sage') | ForEach-Object {"tests/$_.spec.luau"}
 & (Join-Path $LuauDirectory 'luau-analyze.exe') @pure @suites
 if($LASTEXITCODE -ne 0){throw 'KCM domain types failed'}
 foreach($suite in $suites){ & (Join-Path $LuauDirectory 'luau.exe') $suite; if($LASTEXITCODE -ne 0){throw "Failed $suite"} }
 $runtime=@('src/server/Services/NarutoKcmService.luau','src/server/Services/NarutoAbilityService.luau','src/server/Services/AbilityService.luau','src/client/Controllers/AbilityController.luau','src/client/Controllers/AbilityHUDController.luau','src/shared/Abilities/SkillLearning.luau','src/shared/Config/AbilityConfig.luau','src/shared/Config/HeroConfig.luau','tests/kcm/Runner.server.luau')
 & (Join-Path $LuauDirectory 'luau-compile.exe') @pure @runtime @suites > $null
 if($LASTEXITCODE -ne 0){throw 'KCM compile failed'}
 New-Item -ItemType Directory -Force build | Out-Null
 $qa=Get-Content default.project.json -Raw | ConvertFrom-Json
 $qa.name='KCMFocusedQA'
 $qa.tree.ReplicatedStorage.Shared.'$path'=Join-Path $repo 'src/shared'
 $qa.tree.ServerScriptService.Server.'$path'=Join-Path $repo 'src/server'
 $qa.tree.StarterPlayer.StarterPlayerScripts.Client.'$path'=Join-Path $repo 'src/client'
 $qa.tree.ServerScriptService | Add-Member -NotePropertyName KcmTests -NotePropertyValue ([PSCustomObject]@{'$path'=(Join-Path $repo 'tests/kcm/Runner.server.luau')})
 [IO.File]::WriteAllText((Join-Path $repo 'build/kcm-qa.project.json'),($qa | ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
 & $RojoPath sourcemap build/kcm-qa.project.json -o build/kcm-qa-sourcemap.json
 if($LASTEXITCODE -ne 0){throw 'KCM sourcemap failed'}
 & $RojoPath build build/kcm-qa.project.json -o build/kcm-qa.rbxlx
 if($LASTEXITCODE -ne 0){throw 'KCM QA build failed'}
 Push-Location build
 try {
  $typed=@($pure+$runtime | ForEach-Object {"../$_"})
  & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap kcm-qa-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') @typed
  if($LASTEXITCODE -ne 0){throw 'KCM Roblox types failed'}
 } finally {Pop-Location}
 Write-Output 'PASS KCM focused headless checks. Integrator only: build/kcm-qa.rbxlx, Studio Server & Clients, 2 clients. Studio has NOT been run by this script.'
} finally {Pop-Location}
