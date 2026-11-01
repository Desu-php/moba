# Sage A09J: bounded direct-mode prototype

Source: docs/source/naruto-progression-and-branches-contract.txt, exact Naruto
Legend 1.7A FIX20.3 map SHA256
8c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8.
Static analysis only. JASS 44750–44851 preparation/direct restore;
44343–44363 modifiers; 44305–44339 timer. No assets or JASS imported.

## Available scope

Learn rank 1 at hero level 6 and rank 2 at 10 through the existing skill-point
pipeline. Key 4 / the fourth HUD button casts direct Sage. Each cast costs 25
ordinary mana once and starts a 150-second cooldown. Preparation self-stuns for
10 / 7 seconds, then restores 200 / 350 mana once, capped by current maximum.
The mana transaction follows the application's existing post-admission debit
policy; native Warcraft debit/event ordering remains uncertified.

Active bonuses: attack +10 / +30 raw damage, maximum HP +150 / +200, movement
+105 Warcraft units through the shared 1/16 prototype scale. Flat attack bonus
is added after the existing M1 multiplier and before victim mitigation. This
integrates with our combat balance; it does not certify Warcraft attack totals.

## Explicit native policies and gaps

- Armor +3 / +7 is **provisional tooltip-based policy**, not a resolved inherited
  AId3/AId7 object value. It is isolated in SageState.Policy, not source facts.
- Rank 3 remains unavailable without spending a point: A07Y/AIl2 HP inheritance
  is unresolved (150 versus 300). Its known level 14, prep 4, restore 500 and
  attack 50 are retained as source data, not an enabled gameplay rank.
- The source timer starts at 50, removes aura on callback 47 and modifiers on
  callback 51. The prototype explicitly selects 47 seconds of active aura and
  51 seconds of active stats, rather than silently claiming exact 50 seconds.
- Capacity increase keeps current HP; removal clamps HP to the current maximum.
  No heal is invented for entering/exiting Sage. Native bonus-HP behavior remains
  an engine boundary. Level-up healing continues through existing progression.
- Owned additive layers compose over current level, StrengthBonus and purchased
  items. Removing Sage removes only its layer; it never restores an old snapshot.
  Death, character replacement, disconnect and terminal match cancel the cast
  and layer; committed cooldown survives respawn. These lifecycle safeguards are
  intentional modernization of source waits without death checks.
- Nonlethal external stuns do not cancel the source's timed preparation. Held
  Rasengan blocks starting Sage as a bounded prototype conflict policy; it does
  not consume mana. Existing ordinary techniques remain available after prep.
- New ordinary combat clones retain the established spawn-time stat snapshot
  policy, including current flat attack bonus. They do not inherit the owner's
  Sage cast, aura tag, timers or autonomous modifier layer. Native illusion
  inheritance is not certified by this slice.
- Meditation toggle/clones, Sage Rasengan variants, KCM layering behavior and
  advanced forms are **not implemented**. Sage state/layer identity is separate
  from future KCM; it is not a mutually exclusive global form enum. Five learning
  lines remain present; unavailable ranks/forms remain explicitly unavailable.
- Preparation pose, orange aura and desktop countdowns are original Roblox
  presentation, not certified Warcraft animation/model parity.

## Verification

Pure Sage/StatLayers suite uses controlled clocks for exact readiness, one-shot
activation, cooldown, source policy boundaries, independent owners, stale life,
late update, rank gates and idempotent layer removal. Existing learning tests
retain closed rank-3/KCM assertions.

Build tests/sage.project.json and start Server & Clients with two clients for the
runtime suite. First preparations use real 10/7-second clocks. Only later expiry
and cooldown deadlines are advanced inside the test fixture to avoid idle waits.
There is no production bypass. The fixture checks real M1 damage and cancellation,
current growth/items, oil speed composition, death/respawn and terminal cleanup.

Runtime and visual acceptance must be reported separately from headless PASS.
No mobile requirement: this game targets PC keyboard/mouse.
