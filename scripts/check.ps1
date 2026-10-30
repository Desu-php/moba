param(
    [string]$RojoPath,
    [string]$LuauDirectory,
    [string]$LuauLspDirectory,
    [ValidateSet('Fast','Targeted','Full')][string]$Mode = 'Full'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$totalTimer = [Diagnostics.Stopwatch]::StartNew()
Push-Location $projectRoot
try {
    if (-not $RojoPath) {
        $command = Get-Command rojo -ErrorAction SilentlyContinue
        if ($command) { $RojoPath = $command.Source }
        else { $RojoPath = Join-Path $env:USERPROFILE '.aftman\tool-storage\rojo-rbx\rojo\7.7.1\rojo.exe' }
    }
    if (-not (Test-Path -LiteralPath $RojoPath)) { throw 'Rojo not found. Pass -RojoPath.' }
    New-Item -ItemType Directory -Force build | Out-Null
    if ($Mode -ne 'Full') {
        if (-not $LuauDirectory) { throw 'Fast/Targeted requires -LuauDirectory.' }
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $pure = @('tests/AbilityState.spec.luau','tests/NarutoLegend.spec.luau','tests/NarutoResources.spec.luau','tests/Jungle.spec.luau','tests/SkillLearning.spec.luau','tests/Gamakichi.spec.luau','tests/GamakichiSpells.spec.luau')
        $domain = @(Get-ChildItem src/shared/Abilities -Filter '*.luau' -File | ForEach-Object FullName)
        & (Join-Path $LuauDirectory 'luau-analyze.exe') @domain src/shared/Combat/HeroPoses.luau src/shared/Game/JungleRules.luau @pure
        if ($LASTEXITCODE -ne 0) { throw 'Targeted domain type check failed' }
        foreach ($suite in $pure) {
            & (Join-Path $LuauDirectory 'luau.exe') $suite
            if ($LASTEXITCODE -ne 0) { throw "Targeted suite failed: $suite" }
        }
        Write-Output ('TIMING pure/poses: {0:F2}s' -f $timer.Elapsed.TotalSeconds)
        if ($Mode -eq 'Fast') { return }
        if (-not $LuauLspDirectory) { throw 'Targeted requires -LuauLspDirectory.' }
        $timer.Restart()
        & $RojoPath build tests/hero-fast.project.json -o build/rasengan-fast.rbxlx
        if ($LASTEXITCODE -ne 0) { throw 'Rasengan fixture build failed' }
        & $RojoPath sourcemap default.project.json -o build/sourcemap.json
        if ($LASTEXITCODE -ne 0) { throw 'Production sourcemap failed' }
        & $RojoPath sourcemap tests/hero-fast.project.json -o build/hero-fast-sourcemap.json
        if ($LASTEXITCODE -ne 0) { throw 'Rasengan fixture sourcemap failed' }
        & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap build/sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') src
        if ($LASTEXITCODE -ne 0) { throw 'Targeted Roblox source types failed' }
        Push-Location tests
        try {
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/hero-fast-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') hero
            if ($LASTEXITCODE -ne 0) { throw 'Rasengan fixture types failed' }
        } finally { Pop-Location }
        Write-Output ('TIMING targeted build/types: {0:F2}s' -f $timer.Elapsed.TotalSeconds)
        Write-Output 'PASS Targeted; Studio: build/rasengan-fast.rbxlx, Server & Clients, 2 clients. Fixture skips preparation countdown only in test build.'
        return
    }
    & $RojoPath build default.project.json -o build/anime-battlegrounds.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Production Rojo build failed' }
    & $RojoPath build tests/studio.project.json -o build/combat-regression-stage3.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Studio test Rojo build failed' }
    & $RojoPath build tests/survival.project.json -o build/survival-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Survival test Rojo build failed' }
    & $RojoPath build tests/progression.project.json -o build/progression-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Progression test Rojo build failed' }
    & $RojoPath build tests/hero.project.json -o build/hero-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Hero test Rojo build failed' }
    & $RojoPath build tests/hero-fast.project.json -o build/rasengan-fast.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Rasengan test Rojo build failed' }
    & $RojoPath build tests/towers.project.json -o build/tower-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Tower test Rojo build failed' }
    & $RojoPath build tests/rounds.project.json -o build/round-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Round test Rojo build failed' }
    & $RojoPath build tests/jungle.project.json -o build/jungle-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Jungle test build failed' }
    & $RojoPath sourcemap tests/jungle.project.json -o build/jungle-sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Jungle sourcemap failed' }
    & $RojoPath build tests/learning.project.json -o build/learning-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Learning test build failed' }
    & $RojoPath build tests/gamakichi.project.json -o build/gamakichi-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Gamakichi test build failed' }
    & $RojoPath build tests/gamakichi-spells.project.json -o build/gamakichi-spells-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Gamakichi spells build failed' }
    & $RojoPath sourcemap tests/gamakichi-spells.project.json -o build/gamakichi-spells-sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Gamakichi spells sourcemap failed' }
    & $RojoPath sourcemap tests/gamakichi.project.json -o build/gamakichi-sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Gamakichi sourcemap failed' }
    & $RojoPath sourcemap tests/learning.project.json -o build/learning-sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Learning sourcemap failed' }
    & $RojoPath sourcemap tests/rounds.project.json -o build/round-sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Round sourcemap failed' }
    & $RojoPath sourcemap tests/towers.project.json -o build/tower-sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Tower sourcemap failed' }
    & $RojoPath sourcemap tests/hero.project.json -o build/hero-sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Hero sourcemap failed' }
    & $RojoPath sourcemap tests/progression.project.json -o build/progression-sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Progression sourcemap failed' }
    & $RojoPath sourcemap tests/survival.project.json -o build/survival-sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Survival sourcemap failed' }
    & $RojoPath sourcemap default.project.json -o build/sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Rojo sourcemap failed' }
    & $RojoPath sourcemap tests/studio.project.json -o build/test-sourcemap.json
    if ($LASTEXITCODE -ne 0) { throw 'Test Rojo sourcemap failed' }

    [xml]$place = Get-Content build/anime-battlegrounds.rbxlx -Raw
    foreach ($entry in @(@('Client', 'LocalScript'), @('Server', 'Script'))) {
        $folder = $place.SelectSingleNode("//Item[Properties/string[@name='Name']='$($entry[0])']")
        if (-not $folder -or $folder.class -ne 'Folder') { throw "Expected folder $($entry[0])" }
        $main = $folder.SelectSingleNode("Item[Properties/string[@name='Name']='Main']")
        if (-not $main -or $main.class -ne $entry[1]) { throw "Incorrect Main class in $($entry[0])" }
    }
    $workspace = $place.SelectSingleNode("//Item[@class='Workspace']")
    if ($workspace.SelectNodes('Item').Count -ne 0) { throw 'Production mapping must not own scene geometry' }
    $sourceCount = @(Get-ChildItem src -Recurse -File -Filter '*.luau').Count
    if ($place.SelectNodes("//Item[@class='Script' or @class='LocalScript' or @class='ModuleScript']").Count -ne $sourceCount) {
        throw 'Unexpected scripts in production build (possible test or starter script leak)'
    }
    Write-Output 'PASS Rojo build, source mapping, entrypoint classes and scene separation'
    if (Select-String -Path build/anime-battlegrounds.rbxlx -Pattern 'RoundTestDriver|TowerTestDriver|HeroTestDriver|ProgressionTestDriver|SurvivalTestDriver|M1TestDriver' -Quiet) {
        throw 'Test driver leaked into production build'
    }
    Write-Output 'PASS production contains no test remotes'

    if ($LuauDirectory) {
        $compiler = Join-Path $LuauDirectory 'luau-compile.exe'
        $analyzer = Join-Path $LuauDirectory 'luau-analyze.exe'
        $runner = Join-Path $LuauDirectory 'luau.exe'
        foreach ($tool in @($compiler, $analyzer, $runner)) {
            if (-not (Test-Path -LiteralPath $tool)) { throw "Luau tool missing: $tool" }
        }
        $files = Get-ChildItem -Path src,tests -Recurse -Filter '*.luau' -File
        foreach ($file in $files) {
            & $compiler --null $file.FullName
            if ($LASTEXITCODE -ne 0) { throw "Luau compile failed: $($file.FullName)" }
        }
        & $analyzer src/server/Services/RequestLimiter.luau src/shared/Combat/CombatState.luau src/shared/Config/CombatConfig.luau src/shared/Game/MatchState.luau src/shared/Game/MatchRoster.luau tests/MatchRoster.spec.luau src/shared/Game/ProgressionRules.luau src/shared/Game/RewardLedger.luau src/shared/Game/RewardRules.luau tests/RequestLimiter.spec.luau tests/CombatState.spec.luau tests/MatchState.spec.luau tests/Progression.spec.luau tests/Rewards.spec.luau
        if ($LASTEXITCODE -ne 0) { throw 'Pure logic type check failed' }
        & $analyzer src/shared/Combat/AbilityState.luau src/shared/Combat/HeroPoses.luau src/shared/Config/AbilityConfig.luau tests/AbilityState.spec.luau
        if ($LASTEXITCODE -ne 0) { throw 'Hero pure logic type check failed' }
        & $analyzer src/shared/Abilities/NarutoDefinitions.luau src/shared/Abilities/NarutoRules.luau src/shared/Abilities/RasenganState.luau src/shared/Abilities/CloneState.luau src/shared/Abilities/CloneCommands.luau src/shared/Abilities/WorldUnits.luau src/shared/Abilities/NarutoResources.luau tests/NarutoLegend.spec.luau tests/NarutoResources.spec.luau
        if ($LASTEXITCODE -ne 0) { throw 'Naruto Legend domain type check failed' }
        & $analyzer src/shared/Game/TowerRules.luau src/shared/Game/StructureRules.luau src/shared/Config/TowerConfig.luau tests/TowerRules.spec.luau
        if ($LASTEXITCODE -ne 0) { throw 'Tower pure logic type check failed' }
        & $analyzer src/shared/Game/RoundProtocol.luau src/shared/Game/JungleRules.luau tests/Jungle.spec.luau tests/Rounds.spec.luau
        if ($LASTEXITCODE -ne 0) { throw 'Round pure logic type check failed' }
        foreach ($suite in @('tests/MatchRoster.spec.luau', 'tests/Rounds.spec.luau', 'tests/RequestLimiter.spec.luau', 'tests/CombatState.spec.luau', 'tests/MatchState.spec.luau', 'tests/Progression.spec.luau', 'tests/Rewards.spec.luau', 'tests/AbilityState.spec.luau', 'tests/NarutoLegend.spec.luau', 'tests/NarutoResources.spec.luau', 'tests/TowerRules.spec.luau','tests/Jungle.spec.luau','tests/SkillLearning.spec.luau','tests/Gamakichi.spec.luau','tests/GamakichiSpells.spec.luau')) {
            & $runner $suite
            if ($LASTEXITCODE -ne 0) { throw "Unit tests failed: $suite" }
        }
        Write-Output "PASS Luau syntax ($($files.Count) files), pure logic types and unit tests"
    }
    else {
        Write-Warning 'Luau checks SKIPPED: pass -LuauDirectory with the official CLI binaries.'
    }
    if ($LuauLspDirectory) {
        & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap build/sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') src
        if ($LASTEXITCODE -ne 0) { throw 'Roblox-aware Luau type check failed' }
        Push-Location tests
        try {
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/test-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') studio
            if ($LASTEXITCODE -ne 0) { throw 'Roblox-aware Studio test type check failed' }
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/survival-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') survival
            if ($LASTEXITCODE -ne 0) { throw 'Survival test type check failed' }
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/progression-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') progression
            if ($LASTEXITCODE -ne 0) { throw 'Progression test type check failed' }
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/hero-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') hero
            if ($LASTEXITCODE -ne 0) { throw 'Hero test type check failed' }
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/tower-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') towers
            if ($LASTEXITCODE -ne 0) { throw 'Tower test type check failed' }
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/jungle-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') jungle
            if ($LASTEXITCODE -ne 0) { throw 'Jungle fixture types failed' }
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/learning-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') learning
            if ($LASTEXITCODE -ne 0) { throw 'Learning fixture types failed' }
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/gamakichi-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') gamakichi
            if ($LASTEXITCODE -ne 0) { throw 'Gamakichi fixture types failed' }
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/gamakichi-spells-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') gamakichi-spells
            if ($LASTEXITCODE -ne 0) { throw 'Gamakichi spells fixture types failed' }
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap ../build/round-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') rounds
            if ($LASTEXITCODE -ne 0) { throw 'Round test type check failed' }
        }
        finally { Pop-Location }
        Write-Output 'PASS full Roblox-aware source type check (Luau new solver)'
    }
    else {
        Write-Warning 'Roblox-aware type checks SKIPPED: pass -LuauLspDirectory.'
    }
    Write-Output 'Engine tests: build/combat-regression-stage3.rbxlx and build/survival-tests.rbxlx, Server & Clients, 2 clients.'
    Write-Output 'Stage 4: build/progression-tests.rbxlx, Server & Clients, 3 clients.'
    Write-Output 'Stage 5: build/hero-tests.rbxlx, Server & Clients, 2 clients.'
    Write-Output 'Towers: build/tower-tests.rbxlx, Server & Clients, 2 clients.'
    Write-Output 'Rounds: build/round-tests.rbxlx, Server & Clients, 2 clients, terminal victory with no restart.'
}
finally {
    Pop-Location
    Write-Output ('TIMING {0} total: {1:F2}s' -f $Mode,$totalTimer.Elapsed.TotalSeconds)
}
