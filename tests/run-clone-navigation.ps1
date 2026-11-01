param([string]$LuauDirectory)
$ErrorActionPreference='Stop'
if (-not $LuauDirectory) { throw 'Pass official Luau CLI directory.' }
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    New-Item -ItemType Directory -Force build | Out-Null
    & (Join-Path $LuauDirectory 'luau.exe') tests/CloneNavigation.spec.luau
    if ($LASTEXITCODE -ne 0) { throw 'Navigation policy failed.' }
    & (Join-Path $LuauDirectory 'luau-analyze.exe') src/shared/Abilities/CloneNavigationPolicy.luau tests/CloneNavigation.spec.luau
    if ($LASTEXITCODE -ne 0) { throw 'Navigation policy types failed.' }
    $module=[IO.File]::ReadAllText((Join-Path $root 'src/server/Services/CloneNavigation.luau'))
    $harness=[IO.File]::ReadAllText((Join-Path $root 'tests/navigation-mock.luau'))
    $generated=Join-Path $root 'build/navigation-mock.generated.luau'
    [IO.File]::WriteAllText($generated,$harness.Replace('-- MODULE_UNDER_TEST',$module))
    & (Join-Path $LuauDirectory 'luau.exe') $generated
    if ($LASTEXITCODE -ne 0) { throw 'Navigation adapter mock failed.' }
} finally { Pop-Location }
