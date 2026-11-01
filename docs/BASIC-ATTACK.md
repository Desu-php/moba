# Directed basic attack (Naruto balance, inspired by SMITE)

The old four-stage M1 chain (5/5/7/10, hitstun on every hit, heavy finisher/knockback) is replaced by one repeatable aimed melee attack. Click once or hold M1. Releasing stops held repetition. Explicit near-recovery clicks retain one bounded input buffer. Holding never fills a future buffer. WASD can still be used while holding M1. Q/1–5/F/G/H cancel held repetition; commands, ability buttons, focus loss, menus, shop, character replacement, and round changes cannot manufacture a new M1.

Aim is the character's current facing, sampled on the server at impact. There is no target-lock, camera teleport, target supplied by the client, or arbitrary enemy search. Turning away or moving the victim out of the volume during windup makes the attack miss. This patch does not add a camera controller or reticle to the other agent's HUD.

## Source basis

Primary Hi-Rez material researched on 2026-11-01:

- [SMITE 2 Alpha Weekend 1 notes, 2024-05-01](https://www.smite2.com/news/alpha-weekend-1-playtest-notes/): melee physical basics, attack-speed effects, physical/magical protections, unchanged protection formula `100/(100+x)`. Our existing `ProgressionRules.mitigate` already has this formula with DefenseScale=100, so it is retained in DamageService rather than applied twice. STR/INT scaling in those notes belongs to SMITE 2; it is NOT imported over this game's Naruto STR/AGI rules.
- [SMITE 2 Alpha Weekend 3 notes, 2024-06-26](https://www.smite2.com/news/alpha-weekend-3-playtest-notes/): explicitly describes differing damage/swing time within Thanatos's hit chain. This confirms swing timing is part of basic attacks; its chain and finisher are intentionally not copied because the user requested removal of our combo.
- [SMITE 2 Closed Alpha 1 notes, 2024-08-22](https://www.smite2.com/news/closed-alpha-1-update-notes/): melee basic attack classifications and swing-time progression. Used as qualitative timing reference, not a source for Naruto-specific timings.
- [Publisher-provided SMITE achievements](https://steamcommunity.com/stats/386360/achievements): Feel the Fury explicitly identifies maximum Attack Speed 2.5. We use 2.5 attacks/sec as a local balance ceiling, not a wholesale SMITE stat conversion.

Some official news URLs currently render only their shell in the page extractor; their indexed official text was available. No precise SMITE windup/recovery split has been certified. The finite windup/recovery values below are our implementation choices, not alleged SMITE constants.

## Our balance and authority

- Damage = 8 * existing AttackDamageMultiplier before the shared physical mitigation pipeline. No escalating hits, basic-hit stun or finisher displacement.
- Base interval .5s, windup .16s, visible duration .42s. Speed multiplier = min(1 + max(0, actual AGI) * .01, 2.5 * .5); all three timings divide by the same multiplier. At level 1 AGI15 this gives 2.30 attacks/sec; growing Naruto AGI reaches the cap. No invented item/hero attack-speed stats.
- A 5x5x5 server overlap box offset 2.5 studs forward, root-distance <=6, forward dot >=.5, solid-wall raycast. Only closest eligible live enemy, at most one humanoid hit, ForceFields/ally/protected structures excluded before nearest selection. Hurtbox cosmetics/accessories remain excluded.
- State.ClaimHit is one-shot and discards late hits. Stun/death/removal cancel active attacks. Fighter identity, LifeId and RoundId are captured at start and checked at impact; no pending callbacks are introduced into production combat.
- M1 remote remains requestId/current Character/RoundId only; server validates replay, rate, life availability, participation, round, cooldown and movement state. No client damage/speed/target parameter.
- Shared Damage.Apply remains the only damage application route. Clone multipliers, Gamakichi armor, jungle/team hostility, forcefields, reward and life attribution stay there. Clones keep their prior base5 through explicit CloneDamage=5 instead of accidentally inheriting hero base8.
- NarutoAbilityService's AttackStarted Rasengan proc is unchanged. It now sees the same closest eligible, visible, front-facing target as basic impact. A proc still pauses/stuns the caster; the ordinary hit is consequently suppressed while the existing delayed empowered payload runs once. No touch/projectile trigger was added.
- `step=1` remains a fixed animation/event token for existing VFX/procedural consumers, not a progression counter. ComboStep is removed from state/protocol and its old model attribute is cleared. Configuration arrays, combo reset and finisher timing/damage/stun fields are gone. Global HUD files were not edited.

## Integration against moba-sage

Base: d7c513332eddd5a615b4bac3069316301ab7cbe8. Isolated checkout and branch: task-5/combat-basic, codex/smite-basic-attack. Main checkout and moba-sage were read only.

Expected manual conflicts (preserve the integrator's new Sage features):

1. `src/server/Services/CombatService.luau`: after replacing array damage, KEEP Sage's additive bonus: `profile.Damage * multiplier + (if stats then stats.AttackDamageBonus else 0)`. Merge the new lifecycle guard/rate and remove old stun/knockback block.
2. `src/server/Services/NarutoSummonService.luau`: use `Combat.Profiles.OrangeNinja.CloneDamage * stats.AttackDamageMultiplier + stats.AttackDamageBonus`. Keep new ranks, Navigation, pathing, summon attributes, ownership and other integrator logic.
3. `src/client/Controllers/HeroMotionController.luau`: keep new Sage visual priorities; only replace ComboStep-dependent M1 lookup with Punch1 and existing published start/end.
4. `src/client/Controllers/InputController.luau`: merge with HUD agent if it changes click guards. Keep their entire ability/HUD click exclusion and preserve SelectingCloneTarget before M1. Held-repeat code must not bypass those exclusions.
5. Test/check files may overlap: retain new Sage/clone suites while adding CombatState to Targeted's pure suite list. Existing studio/survival assertions have been updated away from combo damage/stun/multitarget assumptions.

For HUD stats use `BasicAttackRules.speed(profile, HeroState.Agility) / profile.AttackCooldown` as actual attacks/sec, and `profile.Damage * HeroState.AttackDamageMultiplier` (+ Sage AttackDamageBonus after integration) for raw damage. Do not display the old 4-hit counter or fabricate AS. This patch does not touch global HUD layout.

## Verification

- Targeted: PASS, 3.12 seconds (includes the new 50-check CombatState suite, all existing targeted domain suites, source Roblox types, hero-fast build and fixture types).
- Full: PASS, 17.44 seconds (production/fixture Rojo builds, all Luau syntax, pure logic types/suites, all existing fixture Roblox type checks). This is headless verification; it does not run Roblox simulation.
- New `tests/basic-attack-manual.project.json`: Rojo build PASS, Roblox-aware fixture type check PASS from tests cwd.
- Source type-check warnings are existing MatchService unused Life import and NarutoAbilityService multiline statement; no source type errors.
- `git diff --check`: PASS.
- Studio, input, physics, actual wall/overlap behavior, visual animation alignment, F click routing, and integrated Sage behavior: NOT RUN by this worker. Only the single integrator may use Studio/MCP.

## MCP acceptance

1. Build/open `build/basic-attack-manual.rbxlx`, Server & Clients=2. Use the player named in `[M1Manual] READY`. The fixture only prepares/observes; it never invokes Combat.TryAttack or creates fake input.
2. Face initial direction. Physically click M1 once: `[M1Manual] START` then exactly one DAMAGE to M1_Main after windup and PASS Front. Closer blue ally and further red target remain untouched.
3. Physically hold M1 for ~2s, release: constant step1 damage and rate-limited intervals; stop after release. No fourth-hit stun, heavy flash or knockback. Walk during held M1; no navigation/input lock. Test focus loss/menu/shop and respawn with held M1; no inherited attacks afterward.
4. Setup only via MCP server console or Workspace property: `workspace:SetAttribute("BasicAttackCase", "Wall")`; wait READY, physically click M1. Repeat with Behind, Side, Range, ForceField. Every case must log PASS with zero hits. Return Front, rotate character or move victim sideways during windup: no hit once target exits aimed volume (Front auto-assert expects hit, so use a nonasserting case such as AimDodge for this manual movement check).
5. Set HighAgility, wait READY + stats update, physically hold M1. Compare logged .4s interval cap against level1 ~.435s; no attack faster than cap. Case switch should happen after recovery.
6. Before any attack, record CombatAttackSerial. Physically Ctrl+2 (learn),2 (summon),F,click enemy; command must change while serial remains unchanged. Check Q/1–5/G/H and HUD skill/learn buttons likewise do not emit M1. Verify HUD agent's renamed GUI remains excluded from attack clicks.
7. Run existing `build/rasengan-fast.rbxlx` separately (2 clients) for attack-start proc, armor-independent raw250 fixture, source3.5s stun, one payload, and self-pause. Then verify Q with actual key input in the integrated scene: no activation on touch/empty swing/ally/wall; explicit valid M1 consumes it once. Run Sage+clone integration fixtures after merging the two bonus expressions above.
8. Existing combat regression fixture tests malformed payloads/replay/flood, buffered input, changing facing during windup, death/respawn, ForceField, one-target limit and generic spell-stun restoration. Existing survival fixture tests NPC/team/shared damage. They were updated and type checked, but runtime must be executed/recorded by the integrator.
