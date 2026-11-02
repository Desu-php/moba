# Minion visual pass

Base: `78bb59a071963599df04e807829122157190517c`. Blue uses original Alliance shinobi silhouettes (flak vests, forehead plates, shin wraps; melee kunai, ranged scroll/cuff). Red uses original pale Zetsu silhouettes (leaf collars, face growth, spine; melee root blades, ranged seed pod/arm). Factions are world identities, so a Red player still sees Zetsu on their own side. No external assets or animation upload is required.

The six original physical parts/root keep their sizes and positions. Shoulder/hip pivots move to anatomical attachment points with compensating C1 offsets. Cosmetics are massless, noncollidable, untouchable, unqueryable welded primitives (at most 18 per NPC). No damage, cooldown, range, route, population, reward or corpse-lifetime config changed.

`MinionAttackAt` is written when the server commits an existing attack. The procedural contact pose starts at that timestamp and recovers over .38 seconds; there is no new windup or delayed damage. Idle/run use actual horizontal assembly velocity. Stun and death override attacks, and CombatDisabled stops movement poses. `MinionDiedAt` gives the .65-second fall a shared clock within the existing one-second corpse lifetime. Animation is client-only in one PreSimulation connection. Near/on-screen: 30 Hz; 85–220 studs: 10 Hz; off-screen/far: reset once, then only eligibility checks at 4 Hz. Discovery runs every .5 seconds, repairs streamed joints, and drops removed rigs. `Stop()` disconnects, resets motors and clears references. No per-NPC client connections or animation tracks.

## Focused automated checks

Use installed Luau 0.744, luau-lsp 1.70.1/globalTypes and Rojo 7.7.1 per TESTING.md. Run `luau tests/MinionPoses.spec.luau` and analyze that test plus `src/shared/Combat/MinionPoses.luau`. Generate the production sourcemap and analyze only the six changed/new production modules. Build production once and the dedicated fixture:

```powershell
rojo build tests/minions.project.json -o build/minion-visual-tests.rbxlx
```

## Integrator-owned MCP/Studio QA

1. Open `build/minion-visual-tests.rbxlx`, run Server & Clients with one client. Expect `[MinionVisualTests] PASS ... invariant checks; 3 x 108 cleanup` and `[MinionVisualClient] PASS stop/reset/restart`. These check physical dimensions, unchanged stats, cosmetic collision/query flags, bounded detail count, rest joint alignment, batch instance destruction and controller reset. They do not measure FPS or memory recovery.
2. Inspect four remaining samples from front and side: distinct factions/roles, readable headbands, no detached details or overlapping limbs during idle, moving run and hit recovery. Fixture camera faces the samples; adjust through MCP as needed. Motion should stop with actual movement, rather than continuing from an AI state label. Capture screenshots.
3. In the integrated production match, observe at least three normal waves: attacks against units and towers must occur on server timestamps and retain existing damage/cooldowns. Stun a moving/attacking minion; kill both faction/role variants and observe the fall plus original one-second removal. Observe after match stop/reset: no retained animated NPCs. Do not publish.
4. At the 108 cap, profile client script time/instance count over repeated spawns/deaths and camera moves across 85/220 studs. Verify distant/off-screen rigs stop being posed; moving camera back restores the current pose without replaying stale attacks. Confirm removed rig references are released after their next eligibility check (at most .25 seconds). Test streaming out/in if enabled. Capture MicroProfiler/Developer Console evidence; no runtime performance claim is made before this check.

Studio and runtime visual/performance checks are intentionally reserved for the single integrator; they have not been run by this task.
