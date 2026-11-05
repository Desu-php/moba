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
