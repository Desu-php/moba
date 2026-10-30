# Gamakichi oil and chopping: bounded native-policy adapter

This adds A00A and the adult-only A0EW to the existing summon. It does not add
Sage/KCM, possession, a sixth learning line, or an always-on damage aura.
Reference: [exact map contract](source/naruto-progression-and-branches-contract.txt).
Runtime/physical verification is still required before this follow-up is shipped.

Confirmed overrides used:

- Oil: mana 0, cooldown 25s, range 750 WC units, area 150, duration 6s,
  projectile speed 900, arc .05. Tooltip confirms 30% miss and 40% movement slow.
- Adult chopping: mana 0, cooldown 30s, range 250, area 400, cast time .5s,
  four waves with raw damage 120, no building damage, raw cap 750 per wave.
- Existing shared scale remains 1 WC unit = 1/16 stud. No new owner STR scaling.

Explicit Roblox policies, not certified Warcraft parity:

- G selects an enemy for oil. H selects a world point for the adult channel.
  F retains group targeting. Escape/right-click cancel. Selection clicks are
  consumed by the existing input guard, and HUD clicks never issue M1.
- Commands act on the current owned toad; learning rank 6 while an early toad
  lives does not unlock its channel. Hero mana is not charged for toad spells.
- Oil uses a fixed flight time from initial distance, a homing target's current
  position at arrival, and enemy nonstructure AoE. Target life/epoch/LOS are
  checked again. Walls and ForceField protection are respected. There is no stun.
- Oil grants refresh without stacking. Different source IDs coexist; clearing
  one owner does not clear another. Move speed is 60% of the latest base speed,
  including base-speed changes while slowed and restoration after stun.
- Miss is rolled server-side for basic attacks only. A player's multi-target M1
  rolls once per swing; single-target NPC/summon attacks roll once per attack.
  Ability damage is not a basic attack. Existing attack-start Rasengan effects
  remain separate, so oil does not silently disable them. No client-supplied roll.
- Raw Nsi4=.4 is preserved as unverified data; attack-speed reduction is currently
  **not implemented**. Exact native miss, immunity, dispel, stacking and field
  interpretation remain boundaries. This is not a claim of full ANdh parity.
- Chopping locks the toad in place, suppressing its ordinary attacks for the
  channel. First wave follows .5s preparation, then three more at 1s intervals.
  Hbz5 is inherited and unverified: this cadence is explicitly MVP. Targets are
  re-enumerated each wave, including enemies entering/leaving the area. Raw 750
  is split equally if more than six targets would exceed the wave cap; mitigation
  follows the existing game rules. No guaranteed 480 damage against every target.
- Stun cancels pending toad spell actions; death, replacement, owner life change,
  disconnect and terminal state cancel actions and owned oil grants. Committed
  spell cooldowns are retained on interruption. These are safety/control policies,
  not proven native projectile or caster-death behavior.
- Existing independent summon lifetimes and owner reward attribution are reused.
  Oil copied as an incidental Roblox character attribute/tag is explicitly removed
  from newly created combat clones; native illusion buff inheritance is unresolved.
- Procedural oil projectile, tint, channel marker and pulse visuals are original
  placeholders. No Warcraft assets are imported.

Pure tests use controlled clocks for flight, exact cooldown boundaries, refresh,
independent grants, interruption, four-wave limits and cap allocation. The separate
Studio fixture uses real runtime updates and explicit test-only deadline advances
where documented. Production has no cooldown bypass. Relevant final regressions
include M1/status restoration, existing toad/clone commands and terminal cleanup.

Validation on 2026-10-30:
- New pure spell suite: 41 assertions.
- Two-client spell runtime: 30 checks, including range/wall/admission, finite four
  waves, owner reward, interruption, owner death, summon expiry and terminal cleanup.
- Existing M1: 44 checks; existing Gamakichi: 45 checks.
  The latter fixture now takes server physics ownership before its synthetic
  server-authored death, matching the M1 fixture; gameplay respawn is unchanged.
- Physical keyboard G/H and HUD oil selection both reached the real server path;
  observer recorded two accepted casts, four channel waves, and hero M1 serial 0.
  Both clients displayed the corrected ground-level channel pulses. Oil projectile,
  status tint and cooldown labels were inspected. Procedural visuals remain MVP.
- Only the visual height changed after automated runtime checks; their server and
  domain inputs remained unchanged. The final code gate is run after integration.

Manual reproduction: build tests/gama-spells-manual.project.json, start Server
& Clients with two clients, use Player1: 3, G then enemy, H then ground.
The fixture supplies learned rank 9 only in its test place; production still
requires normal learning. No production cooldown bypass is introduced.
