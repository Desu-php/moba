# Kurama runtime and sharing domain handoff

Follow-up to playable KCM commit `136a9515d2228eceb3c10def5a03c4ac4e76fea9`. The earlier KCM patch file/commit is unchanged. This branch also retains the historical source-audit documentation commit `d5bc3c1`; the implementation patch is a subsequent commit, with that audit file as context only.

## Evidence and scope

The parent raw-source expert supplied the static supplement now preserved at `docs/source/naruto-kurama-sharing-raw-audit.txt` (file SHA256 `ecf50fb63d6d38d8e851bab56a5973718382caa524e3c2f80be1ad57151d7cd0`). It identifies the same map SHA256 `8c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8`. It is supplied source evidence, not an independent re-extraction or map execution by this worker.

This closes the earlier Ewar profile/agr_nar/filter/228 identity gaps substantially. It does not close inherited sharing cost/range, all native resistance/aura semantics, three-head cost, A011 downstream behavior or the orbit graph. The prior audit remains historical; use this supplement and this document for current readiness.

## Ready runtime: A01F-like Kurama

**6** is an auxiliary action unlocked at level21, outside the unchanged five learning lines. No skill point or learned KCM rank is required. Existing server owner/character/round/rate/replay admission remains. Require2500 separate Kurama chakra, spend it once through the existing KCM resource owner; ordinary native mana cost is explicitly0. Entering while KCM is active is denied. Source CD160 is independent of form activity.

`NarutoKuramaState` distinguishes:

- Effective buff/form: nominal30 seconds, corresponding to explicit ahdu30.
- Script release lock: cannot release before25 seconds; after that, waits for buff absence. This is not a25-second form.
- Ability CD160: persists after form ends and across a life change in the same epoch; resets with the epoch.

Default Roblox duration policy owns a30-second timer. A future authoritative buff system can call `NarutoKuramaService.ObserveBuff(player,life,epoch,castId,present)`; an observed present buff may persist beyond nominal30, and release then waits for its explicit absence. `ObserveBuffRemoved` supports early removal: the form layer disappears, but KCM remains locked until the25-second release boundary. These APIs are server-only hooks, not remotes or client-attribute trust. Death immediately cleans owned state and pending proc as a safety adaptation.

The visual is a non-archivable orange Highlight on the retained R15 character. It is a procedural form cue, not an imported Ewar model or a claim of native model parity.

### Explicit Ewar retention policy

`EwarBaseDeltaPreserveLedgerV1`: add one owned `NarutoKurama` layer, using raw Ewar minus Hpal base deltas: HP capacity+2500, armor+20, attack+90, movement+105 Warcraft units. Preserve progression/growth ledger, learned abilities, items and current ordinary mana/max mana. Preserve current HP at entry; increasing capacity does not heal it. On removal, current HP clamps to the remaining maximum through the existing Stats service. Existing M1 cadence/reach and regeneration behavior remain unchanged.

These are selected Roblox semantics, not certified native morph retention. Ewar is HPbase2800/armor20/attack100/speed375/MPbase1300; it is **not** Ewrd/KCMIII. Never replace live permanent stats with either raw unit record. A separate `NarutoSage` layer remains composed and expires on its own schedule; no whole-profile snapshot restoration is used.

Failed admission is a preflight denial with no script resource/CD debit or artificial1-unit reposition. Native failure-CD refund was not confirmed by the source; this is an explicit product policy.

### Attack-start proc

The existing Naruto attack-start hook forwards whether the current directed M1 has an admitted target. A structure can be the initial target; structure recipients are excluded from the later AoE. Air swings do not create a target. No M1 combo or targeting model is introduced.

The full-form owner samples `NextNumber(1,100)` and accepts `<=12`, excluding illusions. This mirrors a real-valued threshold, not an exact integer12% claim (nominal continuous probability11/99; native endpoints unresolved). Only success starts suppression. Snapshot center at attack start, delay.20 seconds, then enumerate enemies/nonstructures within300 Warcraft units around that snapshot. Use the attacker's **current max HP at firing time /25** as raw damage. Moving the caster does not move the center. Existing server damage mitigation is retained as an explicit NORMAL/UNIVERSAL translation policy, not certified native universal-damage parity.

Suppression is.70 seconds **per owner/life/epoch**, replacing the source's global trigger suppression. Death/exit cancels pending damage to avoid stale-life effects. This bounded proc implements the full-form Ewar branch only; it does not enable unrelated o006 or XReal407 branches or reproduce a global flag39 interaction graph.

### Passive pulse and resource phase

The existing separate-chakra1-second callback now emits a Kurama pulse **inside the existing strict `<900+100*level` guard**. No20 chakra regeneration in Kurama, and no invented40/second drain. At/above threshold, the whole block still skips. The pulse restores20HP/20 ordinary mana to same-team nonstructures within400 Warcraft units. Source lacks an alive predicate; Roblox safety never resurrects a dead Humanoid.

Hero ordinary mana uses the actual Naruto pool; Gamakichi's authoritative attribute pool is capped normally. Other summon/meditation mana must use its actual owner, not replicated presentation attributes. Integrator seam:

```luau
KuramaService.ConfigureSummonManaReceiver(function(model, amount)
    return MeditationService.RestoreMana(model, amount)
end)
```

The supplied Sage worker has no such public receiver yet. Add a narrow owned-record method there that validates `record.valid()`, advances its Domain clone resource to current time, adds/clamps `record.clone.mana`, publishes it and returns true; return false for an unknown/stale model. Do **not** both edit a displayed Mana attribute and separately credit the domain. Until this hook is connected, non-Gamakichi summon mana pulses are skipped; HP pulses still apply. This remaining integration edge is explicit.

## Authoritative form markers and meditation

`KcmService.MeditationForm(player)` now returns **Kurama**, **KCM** or **Ordinary** from private validated state. Keep the already handed-off registration:

```luau
Naruto.ConfigureMeditationForms(KcmService.MeditationForm)
```

Captured clone profiles remain unchanged on subsequent morphs. Kurama's presence can now select the Sage worker's two nmbg-like clones; it does not enable three-head input automatically.

`KcmService.IsRikudo(player)` is true only for a current validated active rankIII KCM session. Presentation attribute `RikudoActive` is set on rankIII entry and cleared on exit/reset/death. The private adapter reads the **cast rank**, not a later learned-rank upgrade. This models transient marker228; it is separate from permanent Hagoromo unlock224. No orbital techniques, rods or new Rikudo stat profile are enabled here.

## Ready domain only: three-head and sharing

### A0KP three-head

Known metadata: CD600/range0, armor10/attack80, consume two stored nmbg and transfer CURRENT clone ordinary mana through their settlement path. **Inherited native cost remains unknown.** There is no client action, remote admission or runtime enablement.

`NarutoKuramaState.consumeThreeHead` rejects nil cost with NativeCostUnknown. An explicit caller policy can test a pair plan: require two distinct live nmbg of the same owner/life/epoch and active form, preserve600-second cooldown across same-epoch lives, reject duplicate/stale/foreign pairs, return owned modifier and expected current-mana settlement. The all-or-nothing live-pair validation and cooldown persistence are labeled safety/retention policies. A future world adapter must atomically claim actual clone records; returned mana is a settlement expectation, **not** permission to credit both this value and the existing death handler again.

A011 metadata is preserved (mana300/CD100/range2500) with RuntimeReady=false; its downstream effect is not invented.

### A0JW sharing

`NarutoSharingState` is pure and **has no world adapter, config action or remote**. Without explicit admission it returns NativeAdmissionUnknown; absent cost/range is never treated as zero. The test policy's17 mana/range700 is synthetic test data, not source values.

Implemented domain behavior:

- Exact supplied recipient filter inputs: alive ally, nonstructure/nonillusion; exclude Hpb2/Huth, POSL identity exclusions and Susanoo identities; radius200. Nonhero recipients are allowed; self gets no group/stat grant.
- Owned grants carry caster session/life/epoch, recipient life/epoch and stable grant IDs. Heroes get15STR/15AGI commands; nonheroes get only raw ability identities. Duplicate casts do not add another15.
- One per-owner whole-group expiry at100 seconds, refreshed by accepted casts. This deliberately replaces multiple timers decrementing one global counter. Expire before a newly accepted grant, remove exactly owned grants once; surviving grants can outlive KCM exit, as the source describes.
- Caster self branch:350 at0/1/2 seconds, no self stat grant, lockout release61. Raw-specific Amaterasu cleanup command, not a generic DoT cleanse. The future world adapter needs exact Bapl/B04J removal within25 and the listed raw-unit removal within12.5; none is guessed here.
- One4-per-member bill per caller-owned resource phase, entirely skipped at/above threshold. Insufficient pool removes **all** owned raw abilities including A0FT, deliberately fixing the source alternate-remover leak.
- Recipient death/life changes, explicit guarded revoke/dispel, owner death/close, expiry and Down-command2-second guard. Nonhero cleanup does not subtract15 hero stats that were never granted.

A0FT AIsr/isr2=.35, A092 Aasl/aare10/Slo1=.10 and Asp5 raw identity remain evidence. No shield, direct move-speed bonus, immunity or extra numeric resistance is invented. A runtime still needs a canonical owned STR/AGI ledger, admission cost/range and explicit native-effect translation; existing four-number StatLayers alone cannot represent all sharing effects. Source aura/targeting semantics remain unresolved.

## Focused checks and Studio handoff

Run with existing official binaries:

```powershell
pwsh -File scripts/check-kurama.ps1 `
 -LuauDirectory C:/Users/dev/AppData/Local/Temp/anime-fight-luau-0.744 `
 -LuauLspDirectory C:/Users/dev/AppData/Local/Temp/anime-fight-luau-lsp-1.70.1 `
 -RojoPath C:/Users/dev/.aftman/bin/rojo.exe
```

Expected focused suites: Kurama58, sharing52, KCM64, KCM adapter69 (**243 assertions**). Analyze/compile affected modules and run the targeted Roblox type check; build only the isolated Kurama fixture. The existing unrelated MultiLineStatement lint in NarutoAbilityService remains. No full gate or Studio is run by this script.

Integrator only: open `build/kurama-qa.rbxlx`, Server & Clients2, require `[KuramaTests] ALL PASS` with no FAILED. The unexecuted fixture source is `tests/kurama/Runner.server.luau`: two level21 owners, real natural regeneration to2500 (about95 seconds; no production cheat setters), actual remote admission/debits, independent forms/owned layers, passive pulses, explicit early buff removal versus25-second release,30-second natural expiry, CD160 and return to KCM. Run it separately from other fixtures. It was built and type-checked by the worker, **not executed**.

Manual MCP follow-up:6 entry, cue/status visible to both clients, health capacity/current HP and mana retention with items/Sage; attack-start proc versus landed hit, moving during.2, maxHP changes, a structure as initial target, structures excluded from AoE; no stale damage after death/respawn. Deterministic CLI tests cover roll boundaries and timing without a flaky random-proc assertion. Rebind key6 if another integrated auxiliary already owns it. Preserve the integrator's previous X conflict resolution; this follow-up does not intend to restore the old X binding.

No WC3 execution, Studio/MCP/UI, push, publication, foreign checkout changes or unknown assets/plugins were used. Sharing, three-head, A011 and orbit techniques are not advertised as playable. Remaining native retention, damage-type, visual-model, summon-mana integration and advanced-technique boundaries are explicit above.
