# Sasuke attack animation and attribute update

- Full check PASS (56.82 s): source compilation, pure suites and Roblox-aware types.
- After sword choreography/trail refinement: Targeted PASS (6.99 s).
- Studio Sasuke fixture: 50 checks PASS, including exact first-contact Chidori damage, attacker/victim animation timestamps, health/mana agreement with the real resource pool and agility-scaled server timing.
- Sasuke level 30: 41 STR -> 1202 HP; 48.8 INT -> 885.6 mana; 56 AGI -> 156 attack speed, 2 / 1.56 = 1.28205 s interval. Initial map attributes/growth and spell damage remain unchanged.
- Manual UI: selected Sasuke, used level/learning/refresh commands, opened I panel; coefficients and interval visible without clipping.
- Actual Q, wait for preparation, LMB against a creep clone: 20000 -> 19524 HP, charge consumed, identical attacker impact and victim reaction timestamps.
- Three actual subsequent mouse attacks: all three sword-cut serials observed, 45 rendered frames with trail enabled, trail disabled after recovery.
- Visual inspection: slowed contact poses for sword cut and lightning thrust in a three-quarter camera. The sword uses its own wrist orientation; Chidori uses the left hand. Preview attributes/camera were confined to the QA session, removed, then Play stopped.
- Existing unrelated asset-type warning for 203785492 remains. No new script runtime errors observed.

Design reference: [Dota 2 attributes](https://liquipedia.net/dota2/Attributes). This is an explicit adaptation of three requested coefficients, not a wholesale copy of Dota's damage, regeneration, armor or primary-attribute system.

Release SHA-256:

- Development: `89cda5e8cb4a4d298280b26a809fcc39e6740d52e9d0ea93017b1277b38c16f3`
- Game: `40f9f8b2d31b9af9a4fd0441ee761bf6257fb9cc1d062a53a6f9a6d57fbf7812`
