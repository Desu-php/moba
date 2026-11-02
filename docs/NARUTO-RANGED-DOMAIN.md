# HY/HZ ranged domain slice

Runtime follow-up: [Rikudo HY/HZ runtime](NARUTO-RANGED-RUNTIME.md). The domain-only
statements below describe the earlier standalone20e965b slice.

Base e2bc48bbded6040431913654e41aa5e220492064. This follow-up adds pure modules,
tests and source appendices only. No AbilityService/AbilityConfig/learning/HUD,
Sage/KCM implementation or existing runtime handler is changed. No new ability is
available to players and no Studio or Warcraft execution was performed.

Evidence: [raw gap audit](source/naruto-advanced-raw-gap-audit.txt), sections4-5,
and [HU/HV release appendix](source/advanced-ranged-release-audit.txt), supplied
by the parent static audit. These supersede earlier unresolved group/counter/cripple
notes where they give exact evidence. They do not settle native engine boundaries.

## Implemented domain behavior

`NarutoRangedState` plans **A0HY** and **A0HZ** only. Each accepted request returns
one1800-mana debit and commits that ability's60sec cooldown. Both costs and point
range2000WC are confirmed; **there is no missing mana cost for HY/HZ**. The application
must debit the ordinary mana owner atomically before yielding. The module never
debits the separate Kurama pool and has no Roblox/world dependencies.

Admission needs a server-owned temporary `Grant`: exact owner/round/life, rawcode,
expiry, Ewrd form, learnedKCM3, Hagoromo, heroLevel27+. `allowed` additionally means
the server has admitted the live caster's current action state. No client grant,
rank, resource, strength or origin may be trusted. Current e2bc48b has no authoritative
KCM/Rikudo runtime grant provider, so **runtime admission wiring remains missing**.
Source grant sites are44446-44455 and46763-46788; A0HT contents are now known from
the HU/HV appendix. No permanent sixth/seventh learned line should be invented.

| Sequence | HY | HZ |
|---|---|---|
| Release / caster unpause |1.3s /1.5s|1.3s /1.5s; helpers removed2.5s|
| Flight | Fixed point heading,30WC/.03; arrival distance<=30; move visuals on arrival tick | Same point-distance threshold; no travelling-enemy collision query |
| Explosion center | One center projectile, even though7visuals | Chosen target point;9visuals do not multiply damage |
| Damage |58pulses on alternating ticks; floor((1050+4CURRENT_STR)/58) |7real pulses of(900+4CURRENT_STR)/7 at ticks1/18/35/52/69/86/103|
| Radius | Increment BEFORE each query:640..868 | Increment EVERY explosion tick: pulse radii640/708/776/844/912/980/1048; final1100 at116 |
| Pulse movement | Pull2WC, same query | Pull8WC, enemy/nonstructure query |
| Additional movement | None | Updated counter<10: separate nonally/nonstructure query, signed450 oscillator starting4,3,2,1,-13,...,-1,+13,...; no damage |
| Visual scale |120 then+1/pulse |200 then+2/explosion tick |
| Final status | Cleanup | Cleanup; no executable cripple command |

HY's six source excluded groups216/221/220/219/217/218 are null by the raw audit.
`eligible("NonAllyNonStructureNullGroups",...)` **denies if the caller omits an
explicit membership result** (`NullGroupPolicyUnresolved`). This prevents a silent
native `IsUnitInGroup(null)` assumption. The domain emits one query per pulse and
does not manufacture six live overlap groups or7independent AoEs.

HZ's extra motion filter intentionally differs from its damage filter: a nonallied
neutral can move without receiving the enemy-only damage. `Motion` has no damage
field. Do not implement it by repeatedly calling the damage pipeline or by replacing
the oscillator with a constant pull. Signed displacement is positive inward and
negative outward. World collision/pathing remains the future adapter's boundary.

No final cripple is applied: callback34866-34873 only orders n00A to cast a spell
absent from its evidenced abilities. This is evidence of no executable grant,
not a native-runtime certification of the no-op. No self-damage uses the shared
SurikDamage variable, even though the original HZ cast writes it for other branches.

## API and explicit safety policies

* `new(ownerId,round,life,now)` creates one server-owned state. `request(...)`
  validates/debits by command once. Separate casts and separate owners own all
  coordinates, radius439, visual440, pulse counters and signed motion450.
* HY285 is deliberately initialized0 **for every new cast**. Source does not reset
  this global on cast and interruptions could leak its phase. This is documented
  source-bug isolation; the normal isolated58-pulse sequence is retained.
* `update(state,now,strengthAt)` returns commands, ordered by time/cast/sequence.
  `strengthAt(at)` reads effective integer STR for that pulse, not cast-time STR.
  Drive updates before authoritative STR changes or supply a historical lookup
  during catch-up. Invalid/overflowing STR cancels the affected cast.
* Scheduling chooses a per-cast timer phase: first periodic tick is release+.03,
  with1e-9s comparison tolerance for floating-point roundoff. The arrival tick runs
  the explosion block. Exact global Warcraft timer phase is not claimed.
* Positions are planar WC units. A future world adapter converts through WorldUnits;
  it must not use these numbers as studs or substitute homing/swept collisions.
  Coincident origin/target chooses heading0 explicitly. VisualCount is metadata;
  exact per-visual art/offset realization is outside this pure state.
* Query each damage/motion event against current world membership, including late
  entrants and excluding leavers; do not snapshot victim lists for the whole effect.
  Apply existing damage/mitigation/protection policies separately. Commands are not
  unconditional true damage. HY arrival records destructible clearing500WC; HZ
  destructible-clearing executor is absent because its radius is not specified here.
* `newLife` invalidates pending casts, emits cancellation commands and preserves
  cooldowns. `reset` also clears cooldowns; serial/request high-water marks survive.
  `cancel(state,cast)` rejects stale object identities. `close` cannot be reopened.
  These are lifecycle adaptations, not reproductions of leaking source globals.
* A delivered command batch may include a cast's final pulses followed by Completed.
  Verify owner/round/life and per-cast sequence when applying it; do not reject all
  final pulses merely because `current(state,cast)` is false after completion.
  `current` is for asynchronous callbacks. If death/reset changes identity while
  applying a batch, reject its remaining old-life commands and clean owned visuals.

`ChakraKnifeInstancePolicy` adds **only** the delayed instance predicate. `begin`
copies eligible caster game-instance identity before the .01sec delay; `resolve`
reads target identity after delay, requires both eligible and the same exact
match/instance ID, and resolves once. Nil/ineligible/different instances deny.
No WC3 rectangle coordinates, teleport, damage, cost transaction or player exposure
is implemented. Source caster-position snapshot, pre-gate self-stun/cost and target
native stun still belong to a later A0HW adapter; this helper cannot bypass them.

## Remaining locks and next work

* HY/HZ: supply authoritative current form/temporary-book grant and ordinary mana
  transaction, lifecycle cancellation and world-query/visual adapters. HY also needs
  an explicit native-null-group membership policy. Then perform two-client Studio
  checks for overlapping visuals, moving membership, oscillator neutrals, simultaneous
  Narutos, late death/form exit, barriers and cleanup. No Studio fixture is certified
  by these domain checks.
* HO/HQ: inherited amcs still unknown. Original Absk's separate30 override cannot
  automatically be merged into custom A0HQ. No cost guessed.
* IA: intended per-cast self-damage unresolved; neither stale history nor resetting0
  is silently implemented. IA remains unsupported by this planner.
* HU/HV/A057: full new audit saved. HU500 and HV700 preparation costs are known,
  **A057 release mana remains unknown**. Unit target/notself is not enemy-only;
  priority Sasuke combo and late ANso item add separate boundaries. No release is
  enabled by this patch, no inherited release cost is silently0, no homing introduced.

Run `tests/run-naruto-ranged.ps1`. It checks just these two new modules and their
deterministic suite. Source-number fixtures cover counts/radii, integer vs real
division, pulse-time STR, signed motion, group-policy boundary, state isolation,
grant/resource/range/replay/lifecycle guards and game-instance snapshots. These
prove the specified domain contract, not Roblox/native runtime or full Naruto parity.
