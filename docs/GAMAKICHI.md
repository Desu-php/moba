# Gamakichi: bounded summon slice

This slice implements A005 summon ranks 1–10, not the complete toad kit. Oil (A00A)
and chopping (A0EW) are not implemented or exposed as working controls. Sage/KCM and
advanced Rasengan/clone branches remain unavailable. The existing five learning
lines are preserved. This is a PC keyboard/mouse prototype.

Source: [map contract](source/naruto-progression-and-branches-contract.txt), A005,
h00H/h005. Cast cost: 50 for ranks 1–4, 150 for 5–8, 300 for 9–10. Cooldown: 60s
for 1–5, 150s for 6–10. Lifetime: 10 through 55s in 5s increments. One summon per
cast, early at 1–5, adult at 6–10. Profile is captured once per cast; learning a
rank does not upgrade an existing entity. No Naruto STR/level damage scaling.
Early/adult HP 500/1500, HP regen 2/5, armor 7/15, movement 350/400 WC units,
mana 500/1000, raw attack base 41/101. These are object values, not proof of
native zero-sided-die damage behavior. Mana is retained as profile data; no toad
spell cost or inferred mana regeneration is simulated yet.

Explicit Roblox adaptations (not certified Warcraft parity):

- Initial learn level 1, then every two levels; inherited AOsf arlv is unresolved.
- Key 3 summons. F commands the owner's clones and toad together; otherwise they
  follow/assist the owner. No possession or autonomous target acquisition.
- One active toad per owner; a future allowed recast replaces it. The existing
  source cooldowns normally exceed lifetime. No stack exploits through rank-up.
- Placement 8 studs to the owner's right, clipped against solid geometry. The
  source's cosmetic smoke at 200 units does not certify actual summon placement.
- Movement/range use the centralized 1/16 WC-unit scale, simple horizontal
  collision-aware movement, not full Warcraft pathfinding. No wall teleport.
- Basic attack uses raw base 41/101, a provisional 2s interval, source damage
  point .5s, source 100-unit range plus target collision radius. Hit validity and
  visibility are checked again at impact. Existing MVP armor mitigation applies.
- Owner death, character removal, disconnect and terminal match cancel entity
  and pending attacks; cooldown survives death/expiry, new-match reset clears it.
  This is a lifecycle safeguard, not a claim about native owner-death behavior.
- Original code-built placeholder frog; no Warcraft assets imported. Cosmetic
  parts do not extend the hurtbox. No claim of final animation/art quality.

Unresolved native fields: first unlock, placement/cap/control semantics, inherited
attack interval/acquisition/mana regen/attack and armor types, zero-sided dice;
oil immunity/dispel/stacking and exact Nsi field interpretation; chopping wave
interval/first-last tick, per-target cap and native filters. Oil's 30% miss/40%
movement reduction and chopping's four-wave data must not become a fake stun,
passive DPS aura, or an invented guaranteed damage total.

Verification: `scripts/check.ps1 -Mode Targeted` includes the pure rank/transaction
suite. `-Mode Full` adds all code gates plus the Gamakichi fixture build/types.
`build/gamakichi-tests.rbxlx` runs two Studio clients using the existing regression
harness. Its deadline advances are explicit test-only shortcuts after pure clock
boundary tests; production has no bypass. Runtime and physical controls must pass
before this slice is transferred to main.

Verified on two Studio clients: 45 runtime checks including ranks 5/6, mana/cooldown,
owner reward, independent owners, clones coexistence, expiry/death/respawn/terminal.
Physical Ctrl+3, 3, 2 and F+click were observed; command did not increment M1.
Lifetime boundary advancement is test-only; no claim of a 55-second wall-clock soak.

Follow-up oil/chopping implementation and native boundaries: [GAMAKICHI-SPELLS.md](GAMAKICHI-SPELLS.md). Its runtime acceptance is separate from the core results above.
