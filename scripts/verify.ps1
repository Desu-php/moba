param(
    [ValidateSet('Fast','Targeted','Full','Record','Gate')][string]$Mode = 'Targeted',
    [ValidateSet('Hero','Terminal','Tower','Progression','Survival','M1','Manual')][string]$Suite,
    [string]$LogPath,
    [ValidateSet('Standalone','Unified')][string]$Launch = 'Standalone',
    [string]$RojoPath,
    [string]$LuauDirectory,
    [string]$LuauLspDirectory,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cache = Join-Path $root 'build/verification'
New-Item -ItemType Directory -Force $cache | Out-Null
$timer = [Diagnostics.Stopwatch]::StartNew()
$areas = @{ Hero='hero'; Terminal='rounds'; Tower='towers'; Progression='progression'; Survival='survival'; M1='studio'; Manual='manual' }
function Inputs([string]$scope,[string]$launchKind = 'Standalone') {
    $files = @(Get-ChildItem (Join-Path $root 'src') -Recurse -File)
    if ($scope -eq 'Fast') {
        $files = @(Get-ChildItem (Join-Path $root 'src/shared/Abilities') -File) + @(Get-ChildItem (Join-Path $root 'src/shared/Combat') -File) + @(Get-ChildItem (Join-Path $root 'src/shared/Config') -File)
        foreach ($relative in @('src/shared/Combat/HeroPoses.luau','src/shared/Config/AbilityConfig.luau','src/shared/Config/HeroConfig.luau','tests/AbilityState.spec.luau','tests/NarutoLegend.spec.luau','tests/NarutoResources.spec.luau','scripts/check.ps1','scripts/verify.ps1')) { $files += Get-Item (Join-Path $root $relative) }
    } elseif ($scope -eq 'Targeted') {
        $files += @(Get-ChildItem (Join-Path $root 'tests/hero') -File)
        foreach ($relative in @('tests/hero-fast.project.json','tests/AbilityState.spec.luau','tests/NarutoLegend.spec.luau','tests/NarutoResources.spec.luau','scripts/check.ps1','scripts/verify.ps1','default.project.json')) { $files += Get-Item (Join-Path $root $relative) }
    } elseif ($areas.ContainsKey($scope)) {
        # Hero also exercises the client's target picker; include its controller.
        $dir = Join-Path $root ('tests/' + $areas[$scope])
        if (Test-Path -LiteralPath $dir) { $files += @(Get-ChildItem $dir -Recurse -File) }
        $projectName = @{Hero='hero';Terminal='rounds';Tower='towers';Progression='progression';Survival='survival';M1='studio';Manual='manual'}[$scope]
        $project = Join-Path $root ('tests/' + $projectName + '.project.json')
        if (Test-Path -LiteralPath $project) { $files += Get-Item $project }
        if ($launchKind -eq 'Unified') {
            $files += Get-Item (Join-Path $root 'tests/regression.project.json')
            $files += @(Get-ChildItem (Join-Path $root 'tests/regression') -File)
        }
    } else {
        $files += @(Get-ChildItem (Join-Path $root 'tests') -Recurse -File)
        $files += @(Get-ChildItem (Join-Path $root 'scripts') -File)
        $files += Get-Item (Join-Path $root 'default.project.json')
    }
    return @($files | Sort-Object FullName -Unique)
}
function Fingerprint($files) {
    $lines = foreach ($file in $files) { $file.FullName.Substring($root.Length) + ':' + (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}
function ReadRecord([string]$name) {
    $path = Join-Path $cache ($name + '.json')
    if (Test-Path -LiteralPath $path) { return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json }
    return $null
}
function SaveRecord([string]$name,$record) {
    $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $cache ($name + '.json'))
}
if ($Mode -eq 'Record') {
    if (-not $Suite -or -not $LogPath) { throw 'Record requires -Suite and -LogPath.' }
    $log = Get-Item -LiteralPath $LogPath
    $text = [IO.File]::ReadAllText($log.FullName)
    $prefix = @{Hero='HeroTests';Terminal='RoundTests';Tower='TowerTests';Progression='ProgressionTests';Survival='SurvivalTests';M1='M1Tests';Manual='ManualReview'}[$Suite]
    if ($text -notmatch ('\[' + $prefix + '\] ALL PASS:') -or $text -match ('\[' + $prefix + '\] FAILED')) { throw 'Log does not contain an unfailed completed suite.' }
    $files = Inputs $Suite $Launch
    if (($files | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTimeUtc -gt $log.CreationTimeUtc) { throw 'Evidence predates an input file; rerun the affected suite.' }
    $fingerprint = Fingerprint $files
    $evidence = Join-Path $cache ($Suite + '-' + $fingerprint.Substring(0,12) + '.log')
    Copy-Item -LiteralPath $log.FullName -Destination $evidence -Force
    SaveRecord $Suite @{ result='PASS'; fingerprint=$fingerprint; launch=$Launch; originalLog=$log.FullName; log=$evidence; logSHA256=(Get-FileHash $evidence).Hash; recordedAt=[DateTime]::UtcNow.ToString('o'); kind=$(if($Suite -eq 'Manual'){'manual attestation'}else{'Studio runtime'}) }
    Write-Output "RECORDED $Suite with source/fixture fingerprint."
    return
}
if (-not $RojoPath -or -not $LuauDirectory -or -not $LuauLspDirectory) { throw 'Pass all three tool paths; a gate must not silently skip checks.' }
$scope = if ($Mode -eq 'Gate') { 'Full' } else { $Mode }
$fingerprint = Fingerprint (Inputs $scope)
$toolFiles = @((Get-Item $RojoPath)) + @(Get-ChildItem $LuauDirectory -Filter '*.exe' -File) + @(Get-ChildItem $LuauLspDirectory -Filter '*.exe' -File) + @((Get-Item (Join-Path $LuauLspDirectory 'globalTypes.d.luau')))
$toolStamp = ($toolFiles | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + (Get-FileHash $_.FullName).Hash }) -join '|'
$previous = ReadRecord $scope
$products = if ($scope -eq 'Fast') { @() } elseif ($scope -eq 'Targeted') { @('rasengan-fast.rbxlx') } else { @('regression.rbxlx','anime-battlegrounds.rbxlx','hero-tests.rbxlx','round-tests.rbxlx','tower-tests.rbxlx','progression-tests.rbxlx','survival-tests.rbxlx','combat-regression-stage3.rbxlx') }
$present = @($products | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root ('build/' + $_))) }).Count -eq 0
if ($present -and $previous) {
    foreach ($product in $products) {
        if (-not $previous.products -or $previous.products.$product -ne (Get-FileHash (Join-Path $root ('build/' + $product))).Hash) { $present = $false; break }
    }
}
if (-not $Force -and $present -and $previous -and $previous.result -eq 'PASS' -and $previous.fingerprint -eq $fingerprint -and $previous.tools -eq $toolStamp) {
    Write-Output "REUSED $scope PASS from $($previous.recordedAt); identical hashed inputs. No tests were executed."
} else {
    & (Join-Path $PSScriptRoot 'check.ps1') -Mode $scope -RojoPath $RojoPath -LuauDirectory $LuauDirectory -LuauLspDirectory $LuauLspDirectory
    if ($scope -eq 'Full') {
        & $RojoPath build (Join-Path $root 'tests/regression.project.json') -o (Join-Path $root 'build/regression.rbxlx')
        if ($LASTEXITCODE -ne 0) { throw 'Unified regression place build failed.' }
        Push-Location $root
        try {
            & $RojoPath sourcemap tests/regression.project.json -o build/regression-sourcemap.json
            if ($LASTEXITCODE -ne 0) { throw 'Unified regression sourcemap failed.' }
            & (Join-Path $LuauLspDirectory 'luau-lsp.exe') analyze --flag:LuauSolverV2=true --platform roblox --sourcemap build/regression-sourcemap.json --definitions (Join-Path $LuauLspDirectory 'globalTypes.d.luau') tests/regression tests/manual
            if ($LASTEXITCODE -ne 0) { throw 'Regression bootstrap/manual types failed.' }
        } finally { Pop-Location }
    }
    $productHashes = @{}
    foreach ($product in $products) { $productHashes[$product] = (Get-FileHash (Join-Path $root ('build/' + $product))).Hash }
    SaveRecord $scope @{ result='PASS'; fingerprint=$fingerprint; tools=$toolStamp; products=$productHashes; recordedAt=[DateTime]::UtcNow.ToString('o') }
}
if ($Mode -eq 'Gate') {
    $missing = @()
    foreach ($name in $areas.Keys | Sort-Object) {
        $record = ReadRecord $name
        if (-not $record -or $record.result -ne 'PASS' -or $record.fingerprint -ne (Fingerprint (Inputs $name $record.launch)) -or -not (Test-Path -LiteralPath $record.log) -or (Get-FileHash $record.log).Hash -ne $record.logSHA256) { $missing += $name }
        else { Write-Output "REUSED $name $($record.kind): $($record.log)" }
    }
    if ($missing.Count -gt 0) { throw ('Gate incomplete; missing/stale evidence: ' + ($missing -join ', ')) }
    Write-Output 'PASS final gate: automated checks and all required runtime/manual evidence match current inputs.'
}
Write-Output ('TIMING verification command: {0:F2}s' -f $timer.Elapsed.TotalSeconds)
