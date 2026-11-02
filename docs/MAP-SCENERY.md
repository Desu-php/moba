# Shinobi battlefield scenery

Presentation-only pass over the generated map: tall forest belts and layered rock
ridges frame the arena; plaster houses, tiled roofs and a timber Alliance gate
sit behind Blue. Red has an ash-coloured stone enclosure, pale root ribs and red
seals. A shallow visual river crosses under three timber bridges. Existing roads
use an earth palette. All geometry is original Roblox primitives; no external
assets, animation IDs, textures or plugins are required.

`MapSceneryPlan` is a deterministic pure layout, with a hard 900-part budget.
`MapScenery.Ensure` materializes a versioned `Map.ShinobiScenery` folder. It skips
authored maps, reuses the current version, and replaces only its own generated
folder on version changes. Construction happens off-tree and cleans up on failure.
No timers, tasks, particles, lights, Terrain edits or global Lighting changes.
All new parts are anchored, noncolliding, nontouching, nonqueryable and do not cast
shadows. The floor, routes, obstacles, structures, spawns and camps retain their
positions and collision. The river is an opaque thin visual surface above the
existing floor: it does not swim, slow, drown, or change pathfinding. Bridges are
visual overlays above the existing collidable road. Tall decor's rotated bounding
boxes stay outside the 340 x 250 playable ground; internal decoration stays below
four studs above Origin. Existing neon base cores remain unchanged.

## Focused checks

Run `luau tests/MapScenery.spec.luau`, compile the changed Luau files, and build
`default.project.json` with Rojo. The pure test checks deterministic generation,
independent results, names, budget, tall silhouette clearance and all landmarks.
It does not claim Roblox engine, rendering or camera coverage.

Local verification on 2026-11-02: the layout test passed with 325 parts;
`luau-analyze` passed for the pure module/test; `luau-compile` passed for all
four changed/new Luau files. Roblox-aware `luau-lsp analyze` passed for the three
production modules using solver V2, the production sourcemap and Roblox definitions.
Rojo built `build/map-scenery.rbxlx`. `git diff --check` passed.

## Integrator MCP QA (Studio owner only)

Use the normal generated-map place. Start one normal match, check Output for
errors, then run the following on the server (adjust service root only if needed):

```lua
local map = workspace.Map
local builder = require(game.ServerScriptService.Server.Services.MapBuilder)
local decor = map.ShinobiScenery
local count = #decor:GetChildren()
assert(count == decor:GetAttribute("PartCount") and count <= 900)
assert(builder.Build() == map and map.ShinobiScenery == decor)
assert(#decor:GetChildren() == count)
for _, part in decor:GetChildren() do
    assert(part:IsA("BasePart") and part.Anchored)
    assert(not part.CanCollide and not part.CanTouch and not part.CanQuery)
end
print("[MapSceneryEngine] ALL PASS: flags and repeated Build", count)
```

For regeneration QA in a disposable edit/test session, set decor's SceneryVersion
to 0, call Build again and check there is exactly one ShinobiScenery with the same
part count. Set AuthoredSurvivalMap=true on a disposable map and check Ensure does
not add scenery. Do not mutate the live match for these checks.

Camera positions below are absolute world coordinates (Origin is 0,32,0). Use
`workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(...), Vector3.new(...))`
on the client. Capture each frame and return to the player camera after QA.

| View | Camera | Look at | Review |
| --- | --- | --- | --- |
| Whole battlefield | (0,295,180) | (0,32,0) | Three clean lanes, forest rim, river and bridges |
| Alliance settlement | (-235,105,100) | (-153,38,0) | Four roofs, timber gate, banners, core visible |
| Enemy enclosure | (235,105,-100) | (153,38,0) | Pale ribs, ash walls, red seals, core visible |
| North bridge | (35,96,-45) | (0,34,-84) | Deck seams, no flicker, no covered lane |
| South forest/ridge | (-65,130,220) | (-20,48,135) | Staggered tall trees, layered silhouette |

With the ordinary PC camera, walk each lane in both directions and cross the
river away from bridges. Fight at each bridge, existing rock and all four camps;
check targeting, damage/LOS and clone movement remain clear. Watch minions traverse
all three routes and attack towers. Check no canopy fills the camera at the map
edge and no seams flicker during movement. Existing rocks remain gameplay
obstacles; new decoration must never act as one. Assess at 1920x1080 and a smaller
desktop window. No full unrelated gameplay gate is required for this visual slice.

If visual QA finds occlusion, move the offending silhouette farther out; keep the
spatial clearance test. Studio visual/runtime checks are pending until performed
by the integrator; do not treat these instructions as evidence of a pass.
