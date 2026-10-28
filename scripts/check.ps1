param(
    [string]$RojoPath,
    [string]$LuauDirectory,
    [string]$LuauLspDirectory
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    if (-not $RojoPath) {
        $command = Get-Command rojo -ErrorAction SilentlyContinue
        if ($command) { $RojoPath = $command.Source }
        else { $RojoPath = Join-Path $env:USERPROFILE '.aftman\tool-storage\rojo-rbx\rojo\7.7.1\rojo.exe' }
    }
    if (-not (Test-Path -LiteralPath $RojoPath)) { throw 'Rojo not found. Pass -RojoPath.' }
    New-Item -ItemType Directory -Force build | Out-Null
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
    & $RojoPath build tests/towers.project.json -o build/tower-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Tower test Rojo build failed' }
    & $RojoPath build tests/rounds.project.json -o build/round-tests.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Round test Rojo build failed' }
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
        & $analyzer src/server/Services/RequestLimiter.luau src/shared/Combat/CombatState.luau src/shared/Config/CombatConfig.luau src/shared/Game/MatchState.luau src/shared/Game/ProgressionRules.luau src/shared/Game/RewardLedger.luau src/shared/Game/RewardRules.luau tests/RequestLimiter.spec.luau tests/CombatState.spec.luau tests/MatchState.spec.luau tests/Progression.spec.luau tests/Rewards.spec.luau
        if ($LASTEXITCODE -ne 0) { throw 'Pure logic type check failed' }
        & $analyzer src/shared/Combat/AbilityState.luau src/shared/Combat/HeroPoses.luau src/shared/Config/AbilityConfig.luau tests/AbilityState.spec.luau
        if ($LASTEXITCODE -ne 0) { throw 'Hero pure logic type check failed' }
        & $analyzer src/shared/Game/TowerRules.luau src/shared/Game/StructureRules.luau src/shared/Config/TowerConfig.luau tests/TowerRules.spec.luau
        if ($LASTEXITCODE -ne 0) { throw 'Tower pure logic type check failed' }
        & $analyzer src/shared/Game/RoundProtocol.luau src/shared/Config/RoundConfig.luau tests/Rounds.spec.luau
        if ($LASTEXITCODE -ne 0) { throw 'Round pure logic type check failed' }
        foreach ($suite in @('tests/Rounds.spec.luau', 'tests/RequestLimiter.spec.luau', 'tests/CombatState.spec.luau', 'tests/MatchState.spec.luau', 'tests/Progression.spec.luau', 'tests/Rewards.spec.luau', 'tests/AbilityState.spec.luau', 'tests/TowerRules.spec.luau')) {
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
    Write-Output 'Rounds: build/round-tests.rbxlx, Server & Clients, 2 clients, three rounds on one server.'
}
finally {
    Pop-Location
}
