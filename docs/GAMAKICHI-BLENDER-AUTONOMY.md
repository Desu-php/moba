# Gamakichi — Blender rig and independent combat

Supersedes the earlier model and owner-leash descriptions in GAMAKICHI.md and
SUMMON-AI-AND-PAW-SWEEP.md. Source rank profiles, lifetime, basic damage (41/101),
0.5-second damage point and oil/chopping rules remain unchanged.

Gamakichi chooses visible enemies within 28 studs and retains a valid unit within
40 studs. It has no owner-distance leash. With no unit target, it navigates to
the nearest eligible hostile tower. Nearby units preempt siege. Oil and chopping
are restricted to units; towers receive basic attacks. Hold cancels attacks and
casts; explicit Follow recalls the summon, then autonomous combat resumes.
Moving faces actual travel; attacking faces its victim; idle never tracks Naruto.

The primitive model is replaced by the authored Blender mesh and four skinned
animation clips. See [asset source](../assets/gamakichi/README.md). The independent
collider and bounded curb traversal are retained.

Validation: full syntax, domain tests and Roblox-aware source checks passed.
`gama-qa.project.json` builds the single-player Studio fixture. Autonomous.server
passed 11 assertions: mesh/16 bones, distant-owner tower choice, 101 tower damage,
no unit spells on towers, unit priority, enemy facing, resumed siege, Hold,
explicit recall and automatic oil/chopping. LaneCrossing.server passed 13 checks
on the real generated road lips for juvenile/adult crossing and wall blocking.
Client bone transforms and the rendered imported skin were observed during combat.
The earlier asset-generation warning cleared on the next play session.

Development release contains neither regression scripts nor the test floor.

## Cooldown and tower-navigation correction

`nocd on` now resets hero cooldowns only, including the summon button, but not the
toad's independent spell timers or their HUD attributes. Autonomous oil remains
25 seconds; chopping remains 30 seconds. An explicit `refresh` still clears all
cooldowns once. The Studio help text states this distinction.

The generated Blue_Mid tower reproduced a navigation failure: Roblox returned a
successful straight route through its collidable HumanoidRootPart. Body collision
correctly stopped the summon, but replanning kept returning the same invalid route.
Navigation now grounds and body-checks engine waypoints, uses a radius enclosing
the rectangular body, and falls back to a bounded corner visibility graph around
actual swept blockers. Each edge retains collision and curb checks. The fallback
uses at most six obstacles / 26 nodes and the existing shared request budget.

Verification: full source/domain/type checks passed. Studio passed 15 autonomy
checks, including two real automatic spell cycles with hero `nocd` enabled; 39
obstacle checks for clone-sized, juvenile and adult bodies; and the 13 existing
grass/road checks. Obstacle checks cover head-on/corner approaches, a wide wall,
and actual generated towers from grass/road, with clearance and continuous motion.
See [recorded results](evidence/gamakichi-cooldowns-obstacles.json).
