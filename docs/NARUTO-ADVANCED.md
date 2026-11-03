> **Historical handoff/checkpoint — superseded for current readiness.** Published main49d0a6b includes the integrated bounded runtime. See [latest MCP QA](MCP-QA-2026-11-02.md) for observed runtime/input/visual evidence and [current backlog](NARUTO-KIT-BACKLOG.md) for implemented, adapted and locked paths. Original NOT RUN/no-push statements below describe their earlier worker/checkpoint state, not today's readiness. CI0checks is not CI PASS; Roblox publication remains excluded.

# Advanced melee Naruto and wakeable Sleep

Base: 78bb59a071963599df04e807829122157190517c. Separate branch `codex/naruto-advanced`.
No Studio session, Roblox publication, remote push or external assets were used.
No AGENTS.md/.agents instructions existed in the checkout or checked Documents parents.

Evidence: `docs/source/naruto-progression-and-branches-contract.txt`, especially bounded
variant matrix. Also read Library `libfile_de3939fe995081919fd57704506aa2b1`
(naruto-base-abilities-contract.txt, A1-A4/B1-B4), and its integration supplement
`libfile_d4763cd0e4d08191a71e2b51ff436991`. Exact map SHA256 remains
8c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8.

## Implemented slice

* Learn Rasengan II/III at 11/18, sequentially, one point each. Existing base
  attack-start Rasengan remains available at all ranks. Base cooldown60/cost100.
* `Z` selects Odama during the first second of held Rasengan, rankII+. Independent
  cost200/CD40, preparation2, hold15, stun4, damage250+3*currentSTR after1sec.
  `X` selects melee Rasenshuriken within1sec of Odama selection, rankIII.
  Cost200/CD60, preparation1.3 and self-preparation control1.5, hold15.
  A selector hint appears in the existing HUD message region. Z/X are temporary
  branches; the five learned lines and existing HUD order are retained.
* Melee RS: attack-start consumes once, victim stun4.5; after.5, self-damage
  30*floor((450+4*selectionSTR)/87). Separate victim pulses use
  floor((600+4*CURRENT_STR)/87), .04 cadence, pull4WC, radius300 growing5WC per
  tick until500. No stale global SurikDamage from another cast is used.
  Caster hit pause1.5sec. AoE lasts3.5sec after first impact. Odama uses larger
  orb; RS uses four procedural blades and an expanding area ring.
* ClonesIV uses existing paced burst/navigation, count7 or30. Transaction reads
  eligibility AFTER base200, inclusive30%-of-max threshold, then drains another
  .30*max. Failure of threshold falls back7. This is a documented Roblox policy,
  not a claim that native Warcraft debit ordering was measured.
* `T` arms enemy selection for Sleep at cloneII+. The same server handler accepts
  an enemy Model for ShadowClones. Cost200, normal rank cooldown, zero combat
  clones; five noncombat cosmetic silhouettes for3sec. Self clones retain their
  original .30 outgoing/20incoming/20sec; copied HP is not scaled again.
* Sleep is separate from CombatState.Stunned and shares only movement-lock
  ownership. Valid hostile M1 attack-start, trusted basic-attack attempt, confirmed
  positive damage, expiry or reset wakes. Wake preserves an overlapping stun and
  its deadline. Zero spell damage alone does not wake. No .01 invulnerability is
  invented. Minion/clone/toad AI also respects Sleep. Sleep interrupts pending Q.
* Pure `NarutoAdvancedCatalog` records eligibility and exact blocking reasons for
  remaining advanced branches. Unknown branches are absent from network ability
  configuration and cannot be invoked by a forged ability ID.

## Explicit limits and unconfirmed effects

This is a bounded Roblox melee adapter, **not full Naruto Legend parity**. Exact
native Sleep damage-type/immunity and initial protection, spell debit event order,
rank-I inherited speed, later-rank native damage-taken/attack-speed inheritance,
Odama movement book's inherited speed, native illusion stat/item/dispel inheritance,
and native first clone learn level remain unmeasured. Existing first-level/floor-stat
policies remain provisional. Rasengan rankII/III .20 movement override is recorded
by source but not applied in this slice; inherited rank-I baseline remains unresolved.

RS .04 pulses over a half-open3.5sec interval produce88 nominal ticks here. Native
wait/callback scheduling and precise total were not certified. This count and modern
wall-safe pull are explicit adaptations; do not advertise tooltip450 or guaranteed
native total. Caster self-damage is direct Humanoid damage, so native self-mitigation,
ForceField interactions and death attribution require review. RS AoE center follows
the admitted target; all victims are re-evaluated each tick. Ranged release is closed.

Other outstanding branches (no implemented runtime effect):

| Branch | Verified data | Remaining evidence/runtime |
|---|---|---|
| Cho Odama A0HO | CD40, range600, impact90+.8STR, pulses45+.4STR | Native mana unknown; full pulse/timing/endpoint graph uncertified |
| Wakusei A0HQ | CD100/duration15, hit350+4STR/stun4 | Native mana unknown; form-grant/world adapter unimplemented |
| Rasen Ren A0HU | Cost500/CD60, prep1.3/window13.7, self base600 | Ranged graph, complete hit/pulse lifecycle not certified |
| Magma A0HV | Cost700/CD60, self base700; actual victims still base600 integer formula | Melee/ranged graph; push8, not invented700 victim formula |
| Bijudama RS A0IA | Cost1300/CD60, pull2/radius350 | Self-damage uses unassigned stale variable in original; no intended formula guessed |
| Cho Bijudama RS A0HY | Cost1800/CD60/range2000,58 nominal pulses of(1050+4currentSTR)/58 | Seven-projectile overlap ownership/filtering/concurrency graph |
| Cho Bijuu RS A0HZ | Cost1800/CD60/range2000,7 nominal real pulses of(900+4currentSTR)/7 | Counter/collision timing, expanding inclusion, native cripple stats |
| ChakraKnife A0HW | Cost80/CD140/range600,350+2STR/stun2 | Original paired-region gate unavailable in MOBA; do not expose unrestricted blink |

Additional limitations: advanced point-clone combos and alternate payload reachability
remain closed. RS does not grant ordinary carried-clone payloads. Existing Odama
clone markers still use ordinary verified payload formula; alternate reachability is
unknown. Full-Kurama-specific default4 clones and additional combinations require the
form worker/integrator, and are not represented by this base-form transaction.

## Integration and MCP QA

This patch touches small hooks in shared NarutoAbilityService, SkillLearning,
AbilityConfig, AbilityService and presentation. Merge those by intent alongside Sage
and KCM workers. No Sage/KCM implementation was changed. **Before enabling together**,
bind base-form variant admission to the KCM worker's authoritative session state.
Current defensive attributes KCMActive/KuramaActive must match its published names.
Variants deliberately reject any active Sage session until its routing is integrated;
do not treat base melee RS as Sage throw or Rikudo spellbook behavior. Route any new
form ability admission through the independent fighter.sleep guard as well.

Headless: `./tests/run-advanced.ps1`. Evidence is in
`tests/results/advanced-headless-2026-11-02.log`. Seven domain suites, focused Luau
types, touched Roblox service/controller types, and Studio fixture build/types only.

Integrator owns MCP. Open `build/advanced-tests.rbxlx`, Server & Clients with2 clients.
Expect `[AdvancedTests] ALL PASS ...`; this result is **not yet observed**. Fixture
covers real Ability.HandleRequest chain/debits/replay, wake with overlapping rigid
stun, mass30, full copied maxHP and modifiers, reset. It alters deadlines only in
the isolated fixture. Updated existing clone-ranks fixture expects working Sleep.

Then manually verify learnedII/III Z/X1sec windows, late selection denial/no debit,
M1-only consumption and current-STR Odama damage. For RS verify victim stun before
damage, distinct self-damage, late enter/leave AoE, allies/structures excluded, wall
pull, target death, owner death/disconnect/reset, simultaneous Narutos and VFX cleanup.
Verify T enemy selection consumes click before M1, cancels on Esc, sleep expiry,
basic attack with zero/blocked damage, positive DOT wake, unaffected overlapping stun,
minion/toad/clone action lock. For IV test both sides of post200 threshold, learning
during cooldown, death midway through30-spawn burst, navigation congestion and
5v5 waves. No Studio performance or visual readiness claim is made by headless tests.
