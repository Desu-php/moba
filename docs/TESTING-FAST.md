# Короткий цикл проверки

`scripts/check.ps1` принимает `-Mode Fast`, `-Mode Targeted` или `-Mode Full`
(по умолчанию Full). Передайте пути установленных официальных инструментов:

```powershell
$checks = @{
  RojoPath = 'C:\Users\dev\.aftman\tool-storage\rojo-rbx\rojo\7.7.1\rojo.exe'
  LuauDirectory = 'C:\Users\dev\AppData\Local\Temp\anime-fight-luau-0.744'
  LuauLspDirectory = 'C:\Users\dev\AppData\Local\Temp\anime-fight-luau-lsp-1.70.1'
}
./scripts/check.ps1 @checks -Mode Fast
./scripts/check.ps1 @checks -Mode Targeted
./scripts/check.ps1 @checks -Mode Full
```

Fast проверяет затронутые чистые правила/ресурсы/позы. Targeted дополнительно
проверяет Roblox-типы runtime и hero-сценария и собирает только
`build/rasengan-fast.rbxlx`. Откройте его в Studio: Server & Clients, 2 клиента.
Используется существующий hero-стенд, без башенного огня и волн; стартовый
отсчёт пропускается только в этой тестовой сборке. Сценарий проверяет подготовку,
помощника, правую руку, удержание, явную атаку, поворот/паузу, задержанный урон,
два этапа push, trail/endpoint и сохранение cooldown. Состояние между кейсами
сбрасывается. Полный hero-сценарий отдельно сохраняет expiry, dynamic STR,
клонов, двух Наруто, смерть/respawn/reset, поддельные запросы и disconnect.

Измерения 29.10.2026: targeted 2,88–3,64с; чистый этап 0,11–0,22с.
Короткий Studio:33 проверки за19,77с после загрузки скрипта,25,56с от старта
сервера. Предыдущий полный hero-прогон66 проверок завершался за100,28с от старта
сервера. Короткая итерация примерно в4 раза быстрее, с меньшим целевым набором;
она не заменяет полные проверки перед main. Измерения не включают ручное открытие
файла/настройку окон. Новое окно Studio не требуется для каждого изменения.

## One place and revision-scoped evidence

Use `scripts/verify.ps1` with the same three tool paths shown above. It caches only
successful checks and labels a cache hit `REUSED ... No tests were executed`.
Source, fixture, check-script and tool binary hashes invalidate automated results;
missing or changed build artifacts also invalidate their cached build result.

```powershell
./scripts/verify.ps1 @checks -Mode Fast
./scripts/verify.ps1 @checks -Mode Targeted
./scripts/verify.ps1 @checks -Mode Full
./scripts/verify.ps1 @checks -Mode Gate
# Force an intentional repeat:
./scripts/verify.ps1 @checks -Mode Targeted -Force
```

Full also builds `build/regression.rbxlx`. Open it once in Studio. In **edit mode**,
set `Workspace.RegressionSuite` to Tower, Progression, Survival, M1, Hero, Fast,
Terminal or Manual. The Command Bar equivalent is:

```lua
workspace:SetAttribute("RegressionSuite", "Tower")
```

Start Server & Clients with2 clients (Progression needs3). End Session, change the
attribute in edit mode, and start the next suite in the same editor. Each suite
runs its existing runner and driver in a fresh server/client runtime. This avoids
reopening scene files and their migration dialogs; it does not claim hot reloading
of modules in an already running server. Main is disabled in this test place until
the test bootstrap chooses the combat-only/normal startup. Default production
mapping contains no regression bootstrap, fixtures or selector.

After a completed run, record its **original Studio log**:

```powershell
./scripts/verify.ps1 -Mode Record -Suite Tower -Launch Unified -LogPath '<Studio server log>'
```

The recorder rejects failures, unfinished logs, or evidence older than scoped input
files. Gate requires current evidence for Hero, Terminal, Tower, Progression,
Survival, M1 and a separate Manual review. A Manual record is a human/agent visual
attestation (`[ManualReview] ALL PASS:` in the review log), not an automated claim.
It must describe actual input and visual observations. No missing suite is silently
converted into PASS. Evidence lives under ignored `build/verification/` and keeps
source/fixture fingerprints and the evidence log hash. All production sources, including AbilityController (used by Hero target-picker checks), remain in
its fingerprint. Standalone and Unified launch inputs are recorded separately.

Measured29.10: Fast wrapper executed229 pure assertions in0.41s including hashing;
repeat with identical inputs reused the proof in0.06s. Existing aggregate was10.41s.
Fast Studio was25.56s from server start,19.77s from fixture initialization (about5.8s
startup overhead); previous full Hero took103.06s and76 checks. Coverage differs,
so the fast scene does not replace full Hero validation. The pure domain already
accepts explicit clocks: timing boundaries are checked without real-time sleeps;
Studio retains real time for integration and presentation. Unified-place runtime has now passed Tower48 and Progression54 assertions. A clean
transition from the completed Progression session to launching Survival took56.37s
through the agent UI, without a rebuild or file-open dialog. The first transition
took270.889s including focus/menu diagnostics; this is not a controlled speedup
benchmark. QA targeted command wall time was3.27s, unchanged reuse0.33s. Separate
LSP clock measurement was1.05s; a privileged tool call previously reported934s,
so remote/approval overhead must be separated from the local test runtime. Record
Studio evidence after End Session releases the original log file.
Final30.10: Tower48 completed48.44s from server start; Progression54 completed28.31s. The measured agent transition (Tower stopped/recorded to Progression Play, including model/tool round trips) took129.43s; this differs from the earlier56.37s transition and does not establish a repeatable whole-cycle speedup. Full after the cache dependency correction took13.01s for checks and15.21s including unified build/types. Avoid interpreting fast-check reuse as fresh runtime coverage.

Final30.10: Terminal47 passed42.85s; Survival38 passed101.91s. Both used the same unified place with no additional build or file-open. Runtime waits and UI transitions dominate the end-to-end regression cycle; no repeatable whole-cycle speedup is claimed. Reuse avoids repeating unchanged Hero and earlier completed suites, while changed scopes still require fresh evidence.
