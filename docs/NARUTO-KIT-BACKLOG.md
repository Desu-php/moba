# Naruto kit: integration backlog

Audit date: 2026-11-02. Baseline: `78bb59a071963599df04e807829122157190517c`.
Source: [static map contract](source/naruto-progression-and-branches-contract.txt),
map SHA256 `8c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8`.
Base A014/A04N evidence and source references are also retained in
[NARUTO-LEGEND.md](NARUTO-LEGEND.md). Static evidence is not Warcraft execution.

## Current five-line boundary

| Line | Working bounded implementation | Remaining work / admission boundary |
| --- | --- | --- |
| A014 Rasengan | Rank I: helper preparation, right-hand sphere, explicit attack-start, delayed current-STR/current-level damage, two push phases, expiry and life/epoch guards | Ranks II/III remain unpurchasable; no unsupported rank may consume a point. Variant grant/selection, Sage Odama, shuriken releases and later form variants are absent. |
| A04N Shadow Clones | Ordinary self I/II/III: 3/4/5, CD 50/46/42, mana 200, life 20, .30 outgoing / 20 incoming; follow/assist/F and bounded navigation | Enemy Sleep, self IV mass/ordinary selection, advanced point targeting and alternate/form payloads remain disabled. Rank-I point path is bounded ordinary behavior, not proof of later point branches. |
| A005 Gamakichi | All ten learned ranks, early/adult profiles, one summon, follow/assist/F, oil G and adult chopping H | Native placement/control/replacement/stat defaults remain policy boundaries; oil Nsi4 attack-speed reduction is not implemented. Chopping has explicit adapted cadence/cap allocation. |
| A09J Sage | Learned direct I/II at 6/10; cost25/CD150, prep10/7, restore200/350, owned stat layers and cleanup | Meditation mode is a parallel task. III at14 is closed pending inherited HP resolution or an explicit provisional policy. Sage-derived Rasengan and future KCM layers need integration. |
| A017 KCM | Pure resource/domain state/config/tests only; no runtime or learning | Parallel KCM task owns adapter/morph policy. Need complete server/UI wiring, progression-preserving morph, life/epoch cleanup, Sage layering and rank gates. III requires Hagoromo in addition to level27 and learned rank. |

Learning keeps all five lines visible. Existing gates in `SkillLearning` and
`NarutoRankPolicy` are the runtime truth; source catalog `RuntimeReady=false`
describes an incomplete whole line. No extra sixth learnable line, free advanced
rank, manual attribute sink, or replacement Wind Palm is planned.

## Backlog and evidence gates

### R1 — Rasengan ranks II/III and variant eligibility

- **Source:** A014 purchase levels 4/11/18, three ranks. Ranks II/III explicitly
  contain .20 movement fields; rank-I inherited speed is unknown. The base
  `120 + CURRENT STR + 10*CURRENT level` impact is implemented.
- **Gap:** the current bounded contract does not certify every later-rank native
  buff/effect, transition or release path. Do not unlock II/III by merely reusing
  rank-I behavior or by treating all variants as the same projectile.
- **Next deliverable:** evidence table for each learned rank, granted temporary
  ability, selection-window action, cost/debit boundary and release path. Implement
  only an independently complete path, retaining closed unsupported purchases.
- **Acceptance:** current impact stats, one marker consumed by eligible explicit
  attack, no ally/building consumption, independent owners and cooldowns; cancel
  all life/epoch-stale work without changing committed costs.

### R2 — advanced Rasengan branches (after prerequisite forms)

Base Odama **A0DK** and Shuriken **A013** are themselves unfinished prerequisite
paths. Before exposing their downstream variants, certify and implement their
grant/selection, native cost, preparation, attack and release graphs. The advanced
matrix below does not substitute for those base paths or prove their full costs.

| Branch | Confirmed bounded evidence | Evidence still needed before complete admission |
| --- | --- | --- |
| A0HO Cho Odama | Sage-ready + level16 grant; CD40; point range600; two helpers, movement/pulses/endpoint callbacks | Inherited mana, exact pulse count/timing/sum, endpoint/travel and chained cost ordering. Do not claim one flat hit. |
| A0HQ Wakusei | Eligible N01H/N00E held branch, not Ewrd; CD100; 1s prep/13s attack; stun4, pause.5, damage350+4STR, .7s push | Inherited mana and native target/availability edges; requires working KCM eligibility. |
| A0HU Ren Shuriken | Mana500/CD60; prep1.3, hit13.7, self-stun1.5; distinct self-damage and shared target AoE | Full A057 ranged graph and actual pulse lifetime. Shared target AoE uses integer division `(600+4*currentSTR)/87` each .04s, not the self-damage variable. |
| A0HV Magma | Mana700/CD60; prep/hit windows; radius350, outward movement -8; Hagoromo grant | Ranged path and exact lifetime; its `(700+4STR)/87` variable does not define shared victim AoE. |
| A0IA Bijudama | Mana1300/CD60, pull2, radius350; advanced Ewrd/Hagoromo grant | Inherited Channel target mode and stale self-damage variable intent are unresolved. Never copy the global-state bug. |
| A0HY / A0HZ | Each mana1800/CD60/range2000; distinct projectiles/counters, pulls and damage callbacks | Overlap groups, concurrent counter isolation, pulse count/entry timing; HZ final native cripple fields. No unconditional total-damage claim. |
| A0HW Chakra Knife | Mana80/CD140/range600, source region gate, teleport, stun2, damage350+2STR | Map-specific region admission has no direct Roblox equivalent; define a visible adaptation rather than unrestricted blink parity. |

Temporary/book abilities are grants under the original five learned lines.
Grant visibility and authoritative cast validation must be separate, and both
must enforce current form/rank/owner/life/epoch. Use per-cast state instead of JASS
globals. No source assets or JASS code are transplanted.

### C1 — enemy Sleep II+ and advanced point branches

- **Source:** enemy target rank>=2 selects Sleep, no combat-clone burst; catalog
  records duration3, five cosmetic helpers, radius120 WC. Native Sleep wakes on
  attack; a generic stun is not a faithful replacement.
- **Unknown:** A0IC/AUsl inherited immunity, initial protection and wake interactions
  for zero, blocked, DOT or other damage; rank-II+ point-handler details.
- **Deliverable:** explicit sleep/status policy and wake admission, owner/cast
  cleanup, cosmetic-only helpers. Unknown edges stay tagged or unavailable.
- **Acceptance:** no autonomous damage from sleep helpers; valid hostile targets
  only, one admission/debit, wake/expiry/death cleanup once, independent Narutos.

### C2 — rank IV ordinary/mass self-cast

- **Source:** rank IV count7/CD38 ordinarily; valid self branch can select30 at
  effect-frame mana >=30% maximum and drains that fraction additionally. Native
  base cost200 is separate. Existing pure rules accept explicit effect-frame mana.
- **Unknown:** native mana charge/event order, inherited first learn level and
  advanced point behavior. Candidate first level1 gives 1/5/9/13; current first1
  remains a named product policy, not a proved inherited field.
- **Deliverable:** one documented transaction order and complete IV admission,
  selection and debit. Do not enable7 as a disguised IV when30 is unsupported.
- **Acceptance:** exact threshold boundary after selected debit order, no negative
  mana/double spend/replay, ordinary fallback, 30-clone load fixture and all current
  LOS/navigation/owner credit/lifetime guards. A fixture must not unlock IV live.

### S1 — meditation (parallel owner)

Source prep10/7/4, no immediate direct refill in clone mode, 35s life, stationary
HP1 clones with owned current-mana return on death/expiration/enemy kill.
Normal rankIII level18 gives two total; KCM18 gives one and19 two; otherwise one.
Normal/KCM maximum500 and regen20 are explicit; initial mana is inherited.
Kurama pair starts0/max2000/regen100. A0I5 remaining native cost is inherited.
Require explicit initial-mana/recall policy, owned IDs, one return, cancellation,
and no instant maximum-mana award. Do not copy global Naruto ownership.

### S2 — Sage III

Source min14, prep4, restore500, attack+50, explicit armor15 and raw movement105.
HP A07Y derives AIl2 without its own override; original AIl2 map record150 versus
commonly inherited300 is unresolved. Resolve native application semantics or
choose and clearly label a provisional HP policy before enabling learning.
Keep rank-I/II armor3/7 provisional and the selected aura47/cleanup51 policy
visible. Test owned modifier removal over current growth/items, no invented heal,
meditation thresholds and independent Sage/KCM layers. Do not flatten forms into
one mutually exclusive enum.

### K1 — KCM I/II runtime (parallel owner)

Source levels13/20, separate pool initially600, entry200, CD10, drain40 each tick
before exit checks; cancel detected on next tick, dash exposed after.5s.
Idle resource threshold `900+100*level` is a gate, not a hard cap; sharing/passive
work is inside that source gate. Within the gate, ordinary non-KCM/non-Kurama
state regenerates20 chakra/s. At level16+, left-arrow source conversion spends200
Kurama chakra and restores200 ordinary mana; its PC binding and resource/HUD
admission must be explicit. Death-immediate cleanup and independent timer
order are existing named safety policies, not certified native behavior.

Require explicit morph stats/retention policy before runtime admission. Raw unit
records are replacement-profile evidence, not additive buffs; preserve XP,
learned skills, permanent growth and items. Reapply only the live eligible Sage
layer, never an old stat snapshot. Block A005 during KCM; cancel/terminal cleanup
must leave no drain or hidden modifiers. A0MK dash is point teleport or unit
teleport+damage100+currentSTR, mana100/CD40/range650; inherited target/pathing
edges need a named policy. Do not represent an unfinished dash as working.

Source availability actions must also be retained, separate from stat layering:
Sage activation disables A017 until its conditional cleanup; KCM entry disables
A005/A01F, and exit restores A017/A005/A09J plus eligible A01F when not on its
form cooldown. Layer reapplication is not permission to cast every combination
in either order. Build an admission matrix for preparing/active/cancelling/
expired states and validate both grant visibility and server cast eligibility;
do not reset a cooldown when restoring availability.

### K2 — KCM III, Hagoromo, full Kurama and sharing

- KCM III: learned rank at27 **and** per-hero Hagoromo grant. Level25 starts360s,
  then alive-wait and1s source pause; no instant flag/free rank. Morph retention
  still unresolved. Parallel KCM work must state which ranks it actually enables.
- Full Kurama A01F: level21 exposure, cost2500 separate chakra, CD160, object
  duration30; source waits25 before polling buff disappearance. Do not use25 as
  form duration. Native morph/presentation and independent cooldown need a slice.
- Sharing A0JW: source partial; hero +15STR/+15AGI owned grants, self350 immediate
  plus first two ticks, not tooltip150/s. FilteredUnits_2, inherited shield/speed,
  range/mana and cleanup need certification or bounded policy. Down-arrow cancel
  cannot remove another owner's bonuses.
- Later rods/orbs, face/Esc/Bijuu variants and three-headed behavior are separate
  contracts. The current matrix does not certify their complete downstream kit.

## Cross-cutting policies, not source parity

1 WC unit = 1/16 stud; third-person directed physical M1 and AGI speed; follow/
assist/F without possession; floor effective attributes; inferred mana/regen;
prototype XP curve/rewards, level heal and item/armor balance remain named Roblox
policies. Native XP handicap175% is known, but thresholds11–30, sharing and
AddHeroXP multiplication/rounding are not. Do not blindly apply1.75 twice or
replace the economy with Dota constants. Extra level30 skill points remain
unspent; no invented +2-all-stats button.

## Integration ownership and acceptance order

The parent assigns landscape, ninja/Zetsu minions, KCM, Sage III/meditation and advanced Rasengan/Sleep/clone IV to isolated
workers. This integrator owns shared Hero/NarutoAbility/NarutoSummon services,
learning, HUD/input and Studio MCP. Do not edit authors' copies. Incoming patch
must include base SHA, commit or patch path, exact file manifest, tests, policies,
unimplemented edges and runtime scenarios. Review source facts before applying;
merge one patch at a time in this branch, preserving already integrated layers.

1. Review each independent patch and run its affected pure/type checks; record
   source revision and result. Do not restart unchanged suites merely by date.
2. Resolve shared service/HUD/input conflicts manually. KCM/meditation require
   joint stat/resource/lifecycle tests after both land. World/minion changes need
   lane, collision, LOS, navmesh and targeting checks on the new geometry.
3. Build one owned QA scene from the combined revision. Only the integrator drives
   official Studio MCP. Identify the scene before mutation; never replace or
   discard user work. Reuse test fixtures, controlled clocks where appropriate,
   and bounded waits with explicit failure.
4. Focused two-owner runtime: relevant input/HUD, progression/items/current stats,
   death/respawn/stale/terminal cleanup, summon commands without accidental M1;
   world routes/LOS and minion attack/movement presentation for changed regions.
5. One final aggregate gate on the final gameplay revision. Clearly label reused
   evidence versus fresh PASS and any unverified visual/native behavior.
6. Review diff/drift, prepare bounded commit; verify remote and applicable push
   authorization. No force push or Roblox publication. Stop only own tests.

### Focused combined QA matrix

| Changed surface | Required focused evidence |
| --- | --- |
| Landscape / navigation | Real navmesh around each changed obstacle and narrow corridor; moving/unreachable target, recovery, independent owners and bounded path request/inflight/retry rates. No through-wall M1, clone, summon or ability damage; actual server LOS remains authoritative. Preserve all three lane routes, tower reachability and spawn/core access. Vertical forest stays out of scope. |
| Ninja / Zetsu minions | Distinct faction presentation with unchanged team/entity/epoch identity; walk/idle from replicated state or velocity, attack animation from actual authoritative start/hit/end timing, scaling with the actual interval. Death/target loss/terminal cancel correctly, no animation restarted every frame, no animation marker grants damage, no inserted third-party executable scripts. Verify both clients and an ordinary lane wave. |
| KCM + Sage + meditation | Layered state, current growth/items/oil modifiers, preserved XP/points/ranks; current-mana return exactly once with correct owner; no direct-mode refill in meditation mode; charge/next-tick cancel semantics and no orphan ticks after exit. Unknown rank/form stays unavailable before spending. |
| Advanced Rasengan / clones | Grant and server admission both enforce form/rank/target/resources; one cost and payload; current delayed-impact stats; separate melee/ranged and self/target damage paths. Sleep wake and IV threshold obey named policies; existing walls/owner/life/epoch guards cannot be relaxed to satisfy a fixture. |
| Shared HUD / input | Five learning lines retained; availability/rank/cooldown/status/resource reflect real server state. Actual keys, mouse learning, hold/release M1 and F selection without accidental M1. View our PC QA viewport only; clearly distinguish rendering/input from server assertions. |

Tests use a ready fixture and bounded waits, not idle matchmaking. Preserve result
fingerprints by affected source region; pure controlled-clock tests prove timing
arithmetic, while actual runtime/network/visual checks prove adapter behavior.
One integrated Studio session may reset fixtures between scenarios. Record total
build/start/result time separately from each test's execution time; do not claim
an unmeasured percentage speedup or infer production FPS from a mass-spawn fixture.
