> Updated melee behavior: [swept multi-target paw contact](SUMMON-AI-AND-PAW-SWEEP.md), 2026-11-05. Earlier single-target observations below describe the previous release.

# Full Kurama overhaul — 2026-11-05

Full Kurama previously rendered as a small fox over the human fighter and retained the human half-second M1 cadence. It now has a large articulated chakra avatar, a solid torso, a dedicated heavy claw attack and a bounded visual for the existing map shockwave.

## Anime reference and size

The official [20th anniversary anime retrospective](https://naruto-official.com/en/news/01_1333) shows Naruto and Kurama fighting together against giant tailed beasts. [Two-Man Team](https://naruto-official.com/en/anime/naruto2/list/01_773) is the transformation reference. These consulted official pages do not establish a numerical height in metres. No fan height estimate is presented as canon.

The existing Creator Store fox meshes are reused at four times their old in-game scale, with gold chakra material, red eyes and dark face/collar markings. This is a battlefield-scale adaptation: the inspected animated mesh bounds were approximately 43 × 34 × 52 studs including the wide nine-tail fan, varying with pose. Torso collision is deliberately smaller (10 × 6 × 13 studs); decorative tails are neither solid walls nor hurtboxes. The physical R15 rig remains underneath. This is an articulated mesh adaptation, not a newly skinned cinematic-quality model.

The camera backs out to 76 studs with an 18-stud pivot height, preserving obstruction handling. Owner-only tail fading keeps enemies visible. Opponents see the full tail fan. Portrait framing and ordinary camera settings return with the form transition.

## Map values versus adaptation

Source: `Naruto_Legend_1_7a_FIX20_3.w3x`, SHA256 `8c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8`; extracted `war3map.j`, SHA256 `fc5e64dd3e9905a4218c482619658bc50c3fc8b2cf4550ada383694bf3a68e3c`. The Ewar object record and `Trig_agr_nar_*` at JASS lines 40458–40525 were checked against the existing extraction. Warcraft itself was not executed.

| Behavior | Evidence / implementation |
| --- | --- |
| Attack cadence | Ewar base cooldown 2 seconds; now used instead of human 0.5. Existing Roblox AGI multiplier and 2.5 attacks/s cap remain. |
| Claw contact | 0.8-second base hit delay, 1.7-second animation; both scale together with attack speed. These timing choices are presentation adaptations. |
| Attack reach | Ewar range 150 / 16 = 9.375 studs beyond the adopted 6.5-stud body allowance: centre reach 15.875. Forward box 18 × 9 × 16 is a third-person adaptation. One victim per ordinary attack; no invented guaranteed cleave. |
| Damage | Existing retained-stat form layer stays +2500 max HP, +20 armor, +90 attack. M1 remains `8 * AttackDamageMultiplier + AttackDamageBonus`; the +90 is not applied twice. This retained-ledger policy is not exact Warcraft native base-stat replacement. |
| Shockwave trigger | Existing source roll `GetRandomReal(1,100) <= 12` at admitted attack intent, excluding illusions; 0.20-second delay. This is separate from the claw contact. |
| Shockwave area/damage | Radius 300 Warcraft units = 18.75 studs. Caster max HP / 25, before the existing Roblox defense mitigation; enemy nonstructures only. |
| Shockwave presentation | Gold ring emitted only after the server claims the proc. Expands to the damage boundary in 0.12 seconds, fades by 0.65; never exceeds the radius. Cosmetic ring follows ground; damage retains the existing root-distance check. |
| Form lifecycle | Existing 2500 separate chakra cost, level 21, duration 30, independent 25-second release lock and 160-second cooldown retained. Sage stacking and KCM exclusion retained. |

The existing per-owner 0.70-second proc suppression and cancellation on death/exit are Roblox safety policies, rather than the source's global trigger switch. Anime provides no numerical MOBA damage values; map data supplies the balance reference.

## Checks

- Full repository check passed: compilation, analysis, configured pure tests and place builds. New `KuramaCombat.spec.luau`: 34 assertions for cadence, contact phase at several AGI values, and unchanged ordinary M1 timing.
- Disposable single-player Studio `tests/kurama/Avatar.server.luau`: 20 runtime checks passed. Real outgoing M1 (104.4 on the level-30 fixture), single-victim/contact timing, reach, rear rejection, walls/ForceField, incoming melee on giant flank, wave radius, wave damage (156.8 = 3920/25), ally/outside exclusions, exact profile/stat/collider restoration and cancellation of the pending swing.
- Client inspection found all nine tails, grounded paws and moving limb welds. Actual replicated attack samples showed three claw trails on the active paw around contact; the opposite paw's trails stayed disabled. Paw contact centre was approximately (±1.29, -0.65, -15.09) relative to the root, matching the frontal reach.
- Separate authoritative death test passed: the collider, body-radius attribute and form flag are removed, and the previous combat profile is restored. Raw runtime outcomes are saved in `evidence/kurama-avatar-runtime.json`.
- Fresh Play is used after QA: test platforms, held-form overrides, manual camera and injected test scripts are not shipped.

The extended two-player `tests/kurama/Runner.server.luau` fixture was not run in this session. Local asset loading is not published-universe permission validation. Three-head Kurama and unresolved advanced map branches remain outside this change.
