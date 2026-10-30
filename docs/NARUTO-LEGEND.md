# Naruto Legend base abilities — domain slice

Source: `Naruto_Legend_1_7a_FIX20_3.w3x`, SHA256
`8c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8`.
Contract: Library `libfile_de3939fe995081919fd57704506aa2b1`,
`naruto-base-abilities-contract.txt`, read in full (241 lines).
Supplement: `libfile_d4763cd0e4d08191a71e2b51ff436991`,
`naruto-integration-supplement.txt`, read in full (49 lines).

## Published domain boundary (6b6cc8c)

This is a pure domain substep, **not the playable Naruto Legend kit**.
The new modules are not connected to the prototype OrangeNinja controllers/services.
Existing gameplay is preserved. All five source lines remain defined, with
`RuntimeReady = false`; no future form is represented as working.

- `NarutoDefinitions`: source values, identities and explicit unsupported capabilities.
- `NarutoRules.configure(definitions)`: raw formulas and base clone branch selection.
- `RasenganState.configure(definitions.Rasengan)`: ordinary preparation/hold, one
  empowered attack, delayed impact, cooldown and owner/round/life identity.
- `CloneState.configure(definitions.Clones)`: paced burst, separate clone records,
  expiry and atomic single-use empowered payload.
- `CloneCommands`: agreed third-person adaptation: follow the owner, assist its target,
  or prefer an explicitly commanded enemy. World adapters must invalidate lost/dead/
  nonenemy targets; owner death suspends intents and life/round changes reject old commands.
  No possession, movement speeds, pathfinding or selection UI are implemented here.
- `WorldUnits`: centralized proposed scale of 1/16 stud per Warcraft unit, explicitly
  tagged a prototype adaptation and tested for consistent range/travel-time conversion.

The application must validate authoritative hero/rank/target/resource data and commit
resource debits plus state transitions atomically. These modules are not network
endpoints. Existing rate limiting and round/character validation must remain in the
Roblox adapter. Ordinary Q admission does not implement rank selection or unlocking.

`clonePlan` takes **mana at SPELL_EFFECT**, not pre-cast mana. It reports the native
200 cost separately and never deducts it or chooses native charging order. That
distinction is essential for the rank-4 self-target threshold. Enemy plans explicitly
return Sleep with zero combat clones; native wake/invulnerability behavior is not
implemented as a stun. Burst admission applies only to a validated combat-clone plan.

Raw damage is resolved from current level/STR at impact, outside cast preparation.
Attack admission consumes the hit handler, not the held buff. After .01 seconds,
`claimControl` emits the stun command and begins the one-second impact delay;
`claimImpact` emits the raw-damage target and removes the held marker. This separates
the source's control and damage callbacks rather than moving stun to damage time.
No physical attack multiplier or unconditional true-damage label is applied here.
Distances remain Warcraft units; no value is silently interpreted as Roblox studs.
No clone max-HP multiplier is imposed in addition to its 20x incoming damage.

## Deliberate safety policies

Owner/round/life identity invalidates pending effects after death, disconnect (adapter
must invalidate the state), or reset. Payload consumption is atomic at attack admission.
These are robustness fixes, not claims about JASS global-state behavior. Cooldowns
persist across respawn and reset with the round, matching the current Roblox lifecycle
policy. Already-created clones are not purged by `newLife`; unfinished bursts stop and
empowered payloads are invalidated. Reset clears the entire clone collection.

## Contract fixture coverage

All tests below are pure-domain checks; none certifies Roblox or Warcraft runtime parity.

| Fixture | Domain coverage | Remaining integration |
| --- | --- | --- |
| 1 | 100 debit command once; 60 cooldown; 2 preparation; 15 buff lifetime | Actual mana transaction, preparation visuals, rank eligibility |
| 2 | Hostile/nonstructure admission once, 1-second delay, raw250, stun3.5 command | Attack-start adapter, actual status/damage |
| 3 | Formula accepts current impact STR | Authoritative STR source at delayed impact |
| 4 | Expiry without impact retains cooldown | Held effect cleanup |
| 5 | Unsupported Odama capability explicit | Selection window, native ordering, Odama adapter |
| 6 | Counts/cooldowns, paced burst, 20 lifetime, .30/20 modifiers | Actual summon stats/control, damage pipeline |
| 7 | Explicit post-native-cost threshold and fallback | Native resource charging order |
| 8 | Dead owner stops burst; completed clones expire independently once | Humanoid lifecycle and world cleanup |
| 9 | Enemy rank2+ selects Sleep with no combat clones; metadata distinct | Wake behavior, temporary protection, cosmetics |
| 10 | Fresh held marker; raw49; owner credit; one use; displacement metadata | World displacement and actual damage |
| 11 | Clones created without marker stay unmarked | Full Q/W integration |
| 12 | Separate owner states/targets/clone markers | Two-client Studio session |
| 13 | Life/reset cancels pending Q/payload/burst | Disconnect/round/character wiring |
| 14 | Request replay/spam cannot recreate cast/burst/marker | Remote rate limit and forged-packet tests |
| 15 | All five lines retained; runtime readiness false | HUD unavailable states and future verified handlers |

## Product/source decisions required before runtime wiring

The existing project has no mana or STR model. Its level cap is 10, whereas A014's
rank requirements are 4/11/18 and the map cap is30. The supplement establishes raw
Hpal STR16/+1.4, AGI15/+1.1, INT14/+1, base mana1300 and initial-mana field9999.
Native-default inference gives itemless level1 mana1510 and regen.71/sec, **not
runtime-certified totals**; 9999 is not a maximum mana pool. Fractional attribute growth
and integer effective STR must be kept distinct; native rounding is unresolved.
A04N's first unlock and generic skill-point cost remain unresolved source defaults.

The existing clones automatically seek enemies and cannot be damaged; the source uses
controllable illusions. Follow/assist plus an explicit enemy command is now the agreed
Roblox control adaptation; verify copied stats before replacing those adapters.
The centralized scale is now the explicit prototype adaptation; attack-start versus
confirmed-contact semantics and Sleep damage/protection edge cases still need an
adapter boundary. Native Sleep can wake on an attack; zero/DOT/blocked damage and
initial protection are not certified. Odama, rank-3/form handlers and advanced point
clones remain incomplete; the prototype WindPalm is not evidence of source parity.

## Exact outstanding source evidence

| Source to inspect | Values needed | Why the adapter needs it |
| --- | --- | --- |
| Native hero stat calculation, Hpal inherited data and transformation/item hooks | Integer effective stat rounding, bonus inheritance and primary-attribute overrides | Raw growth is known; current integer STR and illusion copied stats remain to verify |
| Inherited Warcraft constants and JASS stat/mana setters | Runtime confirmation of inferred INT-to-mana/regen, other scripted modifiers, XP curve | Native-inferred1510/.71 are provisional; map cap30 and STR-to-health20 are known |
| `war3map.w3a` A014 plus native `Absk` defaults | Rank-1 movement bonus; inherited later-rank speed/damage-taken fields | Explicit fields only confirm .20 movement at ranks2/3; rank1 is omitted |
| `war3map.w3a` A04N plus native `ANcl`/hero-learning defaults | First required level, skill-point cost and rank advancement semantics | `alsk=4` alone does not prove unlock levels1/5/9/13 |
| Runtime fixture for `SPELL_EFFECT` and native A014/A0DK/A04N resource costs | Whether engine cost precedes source mana reads; exact chained Odama charges | Rank4 mass-clone threshold and native cost accounting |
| `war3map.w3a` A03B, item I002, native `AIil`, `Unit_Enters_Handler`/generic illusion hooks | Copied current/max HP, attributes and item bonuses; dispel/cleanup behavior | .30 outgoing/20x incoming/20s are known; no extra .05 HP scaling |
| A0IC/native `AUsl` runtime/base data and generic damage hooks | Wake on damage, initial .01 protection, eligible target interactions | Sleep must not become an unconditional stun |
| JASS all writes of `gg_trg_VS` and generic damage/avoidance hooks | Empowered-attack global gate, mitigation/immunity interactions | Cannot claim universal true damage or unconditional admission |
| JASS dynamic writes affecting `YReal[88]` | Reachability of alternate clone payload formula | Current ordinary formula only; marker art does not select alternate damage |

Warcraft-to-Roblox unit scale and attack-event mapping are adaptation decisions, not
missing map numbers. Exact engine ordering/illusion/Sleep behavior may require a
Warcraft runtime fixture even after static object-data extraction is complete.

## Rank-I runtime prototype

The runtime branch connects the source domain through `NarutoAbilityService` and
`NarutoSummonService`; it is a limited playable prototype, not full A014/A04N parity.
Source catalog `RuntimeReady=false` still means the entire line is incomplete.
`AbilityConfig.PrototypeEnabled` independently identifies the explicitly supported
rank-I capabilities. All five lines are shown. Gamakichi, Sage and KCM are disabled;
Odama, advanced Q ranks, rank2+ enemy Sleep and mass/advanced point clones are not
exposed. The unrelated Wind Palm prototype has been removed from the kit, input,
configuration, server effect handler, animation and VFX.

- Rasengan (Roblox 1, with Q alias) requires the verified level4 boundary. It prepares for2 seconds, holds until15,
  and consumes one **server-admitted attack-start** against an enemy nonstructure.
  Surface contact uses scaled50 plus root half-widths; it is a documented collision
  approximation, not Warcraft collision parity. After.01, spell stun3.5 and caster
  pause begin; after another1 second current STR/level determine raw spell damage.
  Physical M1 damage is suppressed during that empowered attack. DamageService still
  applies existing defense/protection rules. The attack-start target cannot be supplied
  by the client; it is selected from the server's current melee candidates.
- Preparation follows the source sequence: the first second permits movement and
  ordinary M1. At t1 a cosmetic helper appears120 Warcraft units to the side facing
  Naruto, and self-stun lasts until t2. At t1.5 the orb attaches to the right hand.
  At t2 the helper poofs and the hero freely carries the orb for the remaining13s.
  Walking/contact alone does not discharge it. One explicit server-admitted M1
  starts the empowered hit; the caster faces the target and pauses1s while the target
  receives3.5s stun. Damage reads current STR/level after that pause. Push steps are
  1WC/.03s during the first second and18WC/.03s during the second, recalculating
  direction from current caster position. Fast push has spin/trails; ground FX
  occurs at its end. Source refs:46389–46535,48500–48589,48693–48789,49313–49477.
- Shadow Clones (Roblox 2) ordinary rankI creates3 clones, cooldown50, lifetime20,200 mana. RankI is granted
  for this prototype without claiming a verified native first learn level or point cost.
  The application commits the200 debit once, then creates the burst. Post-cost policy
  is explicit; no rank4 threshold branch is exposed, so unresolved native ordering does
  not affect the supported ordinary count. Point requests can use the same ordinary
  burst after range/finite checks; unverified advanced handlers stay disabled.
- Clones follow/assist their owner. F targets the pointed enemy (screen center with
  locked mouse/touch), or arms selection when no target is under aim. The HUD button
  explicitly arms the next world click; Escape/right-click cancels. Selection consumes
  its click before M1. The compact bottom HUD includes real HP/MP and all five lines. Server
  ownership, epoch, target eligibility,125-stud range and existing rate limits apply.
  No possession or unsolicited nearest-enemy aggro. Follow spacing/formation is a
  Roblox root-size adaptation. Walk speed270/16 is a provisional native inference.
- The clone inheritance policy copies current/max HP and current prototype physical
  attack scaling once. It imposes .30 outgoing and20 incoming, with no extra .05 HP.
  Full native stat/item/dispel inheritance remains uncertified. Summons are damageable
  fighters, available to minion/ability/tower targeting, without hero death rewards.
  Damage attribution resolves the original owner's user ID. Fresh held-Q clones carry
  a single ordinary payload; old clones are never retrofitted. Payload raw damage has
  no additional .30 factor and no original Q stun. It requests600/16 displacement over.5.
- Existing clones survive owner death until expiry, while unfinished bursts and empowered
  effects are invalidated. Death/respawn/disconnect/round reset use life and round guards;
  new rounds clear the world summons. External stun cancels Q while preserving cooldown
  as an explicit existing-game safety adaptation. Self-stuns used for preparation/pause
  are distinguished so they cannot cancel their own cast.

Mana1510/regen.71 at level1 are implemented as provisional native-default inference,
not measured Warcraft totals. Initial creation/respawn fills the inferred pool; the9999
source initial field is clamped rather than used as max mana. Raw fractional STR growth
is retained, with explicit provisional floor-to-integer for effective STR. Impact reads
current server-side strength bonuses. Level-up updates capacity/regen without inventing
a refill. The current Roblox HP/defense/items, M1 balance, XP curve and cap10 are preserved;
the map's HP620/cap30 are recorded source values, not implemented balance claims. Advanced
ranks remain disabled. The global scale1/16 applies to source-derived world distances;
existing prototype geometry/legacy combat is not silently rescaled.

Burst .01 requests run on the next available Roblox Heartbeat, with engine frame
granularity. Displacement steps preserve .01/.03 cadence with catch-up rather than
frame-dependent travel; walls may reduce travel. Presentation uses existing procedural
poses, local helper copies, a layered right-hand swirl orb, smoke and ground impact.
Joint angles, orb geometry, spin rate and trail artwork are original Roblox adaptations;
source timing/attachment does not certify identical Warcraft animation/art. The local
helper is cosmetic, has no server combat identity and cannot create damage/payloads.
No Warcraft assets or JASS code are imported.
