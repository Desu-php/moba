# Sasuke spell presentation — 2026-11-05

Client presentation now consumes server centres, radii, endpoints, area IDs and timestamps. Damage and cooldown formulas are unchanged. Amaterasu uses a 12.5-stud boundary and Kirin a 34.375-stud boundary (200/16 and 550/16 from the existing Naruto Legend port). The fireball preview was corrected to the actual 300/16 impact radius.

- Amaterasu and burning areas: ground-following boundary, black animated fire, scorched ground and existing Creator Store particle textures. Flame origins are inset from the damage boundary. Extinguish removes the matching area immediately through AreaEnd.
- Kirin: hand raised toward storm clouds, a descending blue horned creature, a 1.5-second fixed warning and a lightning impact within that boundary. The creature is authored geometry; it is a stylized approximation, not an imported anime model. Two Creator Store candidates were inspected in an isolated scratch place and were not included.
- Susanoo: curved ribs, translucent armour, chakra wisps and a blade driven by the server attack contact time. Cosmetic arms now animate the displayed appearance, with no weld changes to the server character assembly. The ground footprint follows the existing frontal attack box and angle requirement.
- Fire/phoenix projectiles, Senbon, Eiso, Nagashi, Katana, Enton, summons, genjutsu, teleport and Chibaku drop have distinct presentations. Eiso displays corridor width; Chibaku shows all nine landing circles and removes hovering spheres on drop.
- Successful casts publish authored upper-body poses. Sasuke sheathes his sword during hand signs. Optional Sasuke meshes prewarm and no longer block an entire appearance transition; Naruto's existing face-preservation path remains in place.

The effects are local, non-colliding and cannot be selected by combat raycasts. They expire with their server lifetime, death, area cancellation or round reset. Ground rings show the horizontal extent of existing server distance checks; this does not change damage into a terrain-following cylinder.

Validation: Full checks passed before the final visual refinements; Targeted build/type checks passed after them. The final Studio run passed 59 server checks and 7 client visual checks. Evidence: `evidence/sasuke-spells-studio-2026-11-05.log`. Studio also reported a pre-existing content-type warning for asset 203785492; that ID is not referenced by these spell assets.

`tests/sasuke/Review.server.luau` is an optional visual storyboard, excluded from releases. Its Kirin warning is deliberately slowed for silhouette review; the real 1.5-second delay is verified by the automated runner. `VisualProbe.luau` checks live geometry and cleanup without changing production damage. Manual review covered black flames, the Kirin silhouette and the complete Susanoo transition. Visual taste and crowded multiplayer performance still require playtesting.
