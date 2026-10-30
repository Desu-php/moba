# Ordinary jungle / PC slice

PC only: keyboard/mouse, desktop resizing; mobile is outside acceptance.

Four symmetric camps at (+/-32,+/-44), relative to MapConfig.Origin, each contain
one forest guardian:180HP,10damage,1.4s attack period,12walk speed. Detection14,
leash30studs, melee5.5. These are centralized provisional MOBA balance values,
not Warcraft source claims. No advanced Naruto abilities are added.

Registered neutral fighters use the existing MinionFactory, FighterStateService,
DamageService and CombatLifeService. TeamId attributes alone never authorize a
neutral. Current match epoch/phase and participant restrictions still apply.
Neutrals oppose active factions, never each other; neither team owns a camp.

A guardian follows its target only within the home leash. During return it evades
new damage, ignores target changes and heals once home. Recovery is bounded: if
blocked for6seconds it returns to its home position. Damage from within the leash
also provokes retaliation. External stuns use the existing fighter state.

Confirmed lethal damage grants the existing last-hit/nearby-team minion reward:
35Gold to the credited player and50XP to eligible living teammates within70studs.
A jungle kill increments the existing minion count, never hero K/D/A. Summon
credit remains attributed to its owner by CombatLifeService. No second ledger.
Corpses clear after1second; a fresh life appears45seconds after death. Waiting and
finished matches do not spawn, attack, pay rewards or restart camps. No buffs,
boss, stacking, fog/minimap or camp timers in HUD are claimed in this slice.

Pure rules receive explicit clocks. tests/jungle.project.json is a Studio-only
2client fixture; its preparation shortcut is isolated from production. Runtime
checks retain real movement/attack and the natural respawn wait. Shared lane,
structure, progression and terminal behavior remain covered by existing tests.

Validation30.10.2026:21pure assertions; Jungle34integration checks on2clients, including M1, delayed Q, clone target/owner bounty, natural45s respawn and terminal shutdown. Survival38passed on the same production source revision. The initial fixture used a cast marker instead of Holding phase; corrected waiting condition, no production mechanics changed. Guardian visuals reuse prototype minion geometry; finished forest artwork and fog/vision are outside this slice.
