# KCM gameplay handoff

Base main: `78bb59a071963599df04e807829122157190517c`. This branch enables KCM gameplay; no Studio/MCP/UI, push or publication was performed by the worker.

## Enabled gameplay and seams

Five learning lines remain. KCM purchases ranks1/2/3 at13/20/27 with the existing authoritative skill-point transaction. Rank3 casting additionally requires the actual Hagoromo grant. Auxiliary actions belong to KCM and never create extra learned lines.

- **5** enters KCM (200 separate Kurama chakra, CD10). Initial pool600; source one-second drain40, .5-second dash reveal, idle20/second and strict threshold guard `pool < 900+100*level`, including overshoot behavior. X requests source next-tick cancellation with its last40 charge.
- **E**, then click an enemy unit or a walkable point: instant dash, ordinary mana100/CD40/range650 Warcraft units (40.625studs). A unit target takes `100 + current STR` through the existing server Damage service; point target takes no damage. Existing selection-click suppression prevents the selection from becoming M1.
- **Left Arrow** at level16 converts200 separate chakra to200 ordinary mana, clamped by the existing pool owner.
- KCM disables new Gamakichi summons, preserving existing summons. **Sage remains castable while KCM is active**, including meditation. Source KCM entry disables A005/A017/A01F, not the Sage line; the earlier domain availability's Sage restriction was corrected.
- Chakra, current form, rank, cast id, cooldown and dash state are replicated as read-only presentation attributes. The existing HUD gets one fallback status text hook; no layout or five-slot redesign. Server state/identity and progression remain authoritative.

The new `NarutoKcmService` owns KCM-specific records and concrete ports. `NarutoAbilityService` adds a require, route/ready/reset/update/start/removal hooks and injected access to its existing mana, busy and Sage state. `AbilityService` adds only auxiliary target admission and KCM learning mapping; existing round/life/rate/replay admission is retained. Config enables KCM and adds auxiliaries to the hero allow-list, outside the five-line order. No HeroService, CharacterStatsService, project files or global M1 behavior is changed.

## Retention and restoration policy

Explicit Roblox adaptation **KcmRawBaseDeltaPreserveResourcesV1**, not certified Warcraft metamorph parity:

| Rank | KCM-owned attack delta | Armor delta | Movement delta (WC units) |
|---|---:|---:|---:|
| 1 | 25 | 5 | 50 |
| 2 | 50 | 10 | 100 |
| 3 | 100 | 15 | 100 |

Deltas compare raw transformed records with Hpal raw attack10/armor0/speed270. Apply only `Stats.SetLayer(model,"NarutoKcm",...)`; HP delta is0. Preserve current/max HP, current/max ordinary mana, original growth ledger, learned ranks, items, M1 cadence and reach. Do not replace them with N01H/N00E/Ewrd effective stats. This deliberately leaves native stat retention/rounding, alternate mana bases and morph attack timing unresolved. A simple owned Highlight signals KCM; it is non-archivable so cloned characters cannot inherit the live owner aura. No downloaded assets.

Exit/death/reset removes **only NarutoKcm** and its exact token's Highlight. The independent `NarutoSage` layer remains composed automatically through Stats.Get/RecalculateStats; no snapshot/restore or timer restart. If Sage expires in KCM, its own layer removal leaves KCM intact. KCM's reapplySage port is intentionally a no-op because owned layers already compose. SageIII's provisional HP300 remains the Sage worker's policy, without duplication here.

Death/life/epoch cleanup uses adapter tokens and cast IDs. Within one epoch, chakra and absolute cooldown persist between lives; unbound/dead time freezes resource and a new resource phase starts on binding. This is the documented safety adaptation. A new epoch/reset starts600. Partial morph failure rolls back without entry debit; failed removal quarantines the life and reports a warning rather than silently retrying.

## Meditation worker seam (integrator)

After merging the Sage/meditation worker and after KCM initialization, register once, preferably immediately after `Kcm.Start(...)` in Naruto.Start:

```luau
Service.ConfigureMeditationForms(function(player)
    return Kcm.MeditationForm(player)
end)
```

Or from the integrator's composition root:

```luau
Naruto.ConfigureMeditationForms(KcmService.MeditationForm)
```

`MeditationForm` returns **KCM** only for the private adapter's current live owner/life/epoch active state; it uses `runtime.IsActive`, not replicated presentation attributes. Otherwise it returns **Ordinary**, including death/exit/reset/missing session. Full Kurama is not implemented, so it never returns Kurama. Existing meditation clones keep their captured profile. There are no key conflicts: KCM uses5/E/X/Left, meditation usesRight Arrow/J.

When merging `NarutoAbilityService`, retain both workers' existing injected mana/busy/Sage hooks and route predicates; do not replace one full file with the other. Preserve KCM's early route so X can cancel during Sage preparation, and leave Sage castable in KCM. `Kcm.Update` must continue running during Sage preparation so40/second drain remains independent.

## Hagoromo and remaining gaps

The full verified progression contract is sufficient for the grant control flow: once level>=25, start360 seconds; then wait until alive, impose one-second server spell stun/presentation, grant once per owner/epoch. Death during that second restarts the alive presentation as a safety adaptation. The grant does not learn rank3. Server folder/character attributes expose HagoromoUnlocked and the deadline. No network path sets the flag.

**Full A01F Kurama is not enabled.** Its cost2500, unlock21, CD160 and native-duration30 are recorded, but effective Ewar/native morph retention, three-headed consumption and downstream abilities are not sufficiently complete for a full gameplay promise. KCM sharing A0JW, advanced rank3 variants, Rikudo and associated forms remain separate gaps. KCM I/II/III entry, chakra, cancellation, dash, retained stat layer and rank3 grant gating are implemented; this is not a claim that all Naruto branches or native parity are finished.

Dash safety adaptations: admit enemies that are Hero/Minion/Summon, exclude ForceField and structures; require ground and line/volume clearance, no wall crossing, height difference<=12studs. Victim receives existing mitigated server damage rather than an invented universal-damage bypass. These are explicit Roblox policies; native target/pathing/universal semantics remain uncertified.

## Focused checks and MCP QA

Run `pwsh -File scripts/check-kcm.ps1 -LuauDirectory C:/Users/dev/AppData/Local/Temp/anime-fight-luau-0.744 -LuauLspDirectory C:/Users/dev/AppData/Local/Temp/anime-fight-luau-lsp-1.70.1 -RojoPath C:/Users/dev/.aftman/bin/rojo.exe`. Explicit paths avoid redirected sandbox TEMP/LOCALAPPDATA defaults. Headless checks use existing Luau0.744, luau-lsp1.70.1 and Rojo7.7.1. Run only the touched suites: NarutoKcm, NarutoKcmAdapter, NarutoKcmGameplay, SkillLearning, Gamakichi and Sage. Expected counts:64,63,36,28,65,38 respectively. Analyze/compile the KCM modules, affected network/service/controllers/configs and fixture. All 294 assertions, targeted Luau/Roblox type checks, compile and fixture build passed. Only a pre-existing MultiLineStatement lint in NarutoAbilityService was emitted; no type errors. No full gate is required for this patch.

An isolated fixture source is `tests/kcm/Runner.server.luau`. It is **not mapped into production**. A locally generated absolute-path test project is `build/kcm-qa.project.json`, with build `build/kcm-qa.rbxlx`. Integrator may open that build via Studio MCP and start **Server & Clients,2 clients**. The fixture suppresses waves/towers/jungle and creates its own floor only inside that isolated run; it calls actual Ability.HandleRequest and real Stats/Damage. Require `[KcmTests] ALL PASS` with no FAILED output. It checks two ranks/owners, separate chakra, retained mana/HP/stat layers, unit dash, cost/CD, cancellation during Sage preparation, stale epoch rejection, Sage survival and KCM reentry/exit over Sage. **This fixture was built/type-checked, not executed by the worker.**

Then perform MCP input QA on a normal two-client session: learn via Ctrl+5/plus, press5, verify aura/status on both clients, E-select point and unit, X cancel, Left conversion at16, no accidental M1 on selection. Check blocked wall/friendly/structure/NaN targets leave dash mana/CD unchanged. Kill/respawn one Naruto while the other remains active; no orphan aura/layer, no600 refill. During KCM cast4 in meditation mode and validate authoritative form profiles at18/19 with the Sage worker's fixture. Let Sage expire during KCM and check only its layer disappears. For a full real-time grant, level>=25 starts a6-minute wait, alive1-second presentation then flag; learned rank3 at27 must fail before the grant and succeed after. Pure tests cover timer boundaries without granting a test bypass.

Build/sourcemap note: the generated test project lives in build, so run luau-lsp from **build/** with `--sourcemap kcm-qa-sourcemap.json` and `../src/...`, `../tests/kcm/Runner.server.luau`. Its paths are relative to that project root. Production sourcemap remains relative to repository root.
