# Shadow clone navigation handoff

Base: `d7c513332eddd5a615b4bac3069316301ab7cbe8` (clean source checkout). Branch: `fix/clone-navigation`. Studio/MCP was deliberately not used. No AGENTS.md exists in this checkout or the checked ancestor directories. The graphify skill was read; there is no existing graphify-out index to query.

## Diagnosis and changes

The active native implementation is `NarutoSummonService`, not the older `CloneService`. Its old movement used one target center for every clone, no peer separation/slot allocation, and a single straight Blockcast; any blocked step was abandoned forever without a route. Clones already have CanCollide=false, so physical collision between shadow clones is NOT established as the cause. Their visible crowding and failure to route around obstacles are established by the code.

`CloneNavigation` adds stable per-target reservations: eight melee positions and staggered waiting rings, up to 64 positions total. The nearest free usable ring is selected; reserved slots skip geometry queries. Ground, body clearance and target visibility are checked. Available inner slots are reused after removal or target changes. A slot failing repeatedly can be replaced. Overflow waits outside melee range; it never gains attack range or damage.

Clear routes use bounded swept steps; blocked routes use PathfindingService walk waypoints. Every actual step still checks static body sweep, ground support/slope and separation from other registered clones and the target. Look-ahead tangent steering avoids settled bodies; initially overlapping bodies may move apart. There is no new collision group. Existing noncolliding anchored rigs remain, moved with their existing PivotTo adapter in speed-bounded increments (no recovery teleport). No exclusion of the whole HeroSummons folder was added; Gamakichi keeps its independent collision and AI behavior.

Generation tokens reject old path results on target changes, idle/stun, Stop or Remove. Failed path searches back off; stalled progress clears old waypoints and retries/changes slots. Vanished/invalid targets retain the existing Commands invalidation/follow policy. F and assist still resolve through CloneCommands. Owner unavailable/idle halts movement, clone death/expiry removes the navigation record. Attacks remain in NarutoSummonService, with server 3D range, Visible and a repeated CanDamage check. Payload, cooldown and damage formulas are unchanged.

## Cost and intentional limits

- Global FIFO: one new calculation per 0.25 seconds (4/s), maximum 2 in flight. Fairness prevents first records from consuming the whole budget. Queue has at most one live entry per clone; invalid generations are discarded.
- Per clone: minimum 0.8 seconds between path starts; failed calculations wait 2 seconds. Goal movement over 2 studs requests a replacement; no-progress recovery after 1.2 seconds. Existing routes may continue while a replacement computes, always with swept-step validation.
- Slot validation at most every 0.5 seconds. Stable slots need one candidate probe; initial selection stops at the first usable eight-slot ring (absolute cap 64 candidate indices). If every slot is blocked the clone safely waits and retries.
- Local neighbor scan is O(N²) across active shadow clones, without a new spatial service. At 30 clones this is 870 peer pairs per update. World casts include a direct-route sweep plus up to five grounded, swept avoidance candidates per moving clone. Profile mass casts on the real server before increasing clone limits.
- Walk-only, AgentRadius >=1.5, AgentHeight=5, no jump/climb. Ramps/slopes with ground normal Y>=0.7 and bounded height changes are allowed. A jump-only route safely fails. Maximum movement delta is 0.1s, so a server hitch slows movement instead of teleporting.
- Eight inner slots are fixed-angle prototype positions. Very narrow geometry may have fewer usable melee positions; overflow waits. More than 64 clones pursuing one target may wait without a reservation. This is not a full Dota avoidance solver.

Primary API references: [Roblox pathfinding](https://create.roblox.com/docs/characters/pathfinding), [WorldRoot casts and overlap](https://create.roblox.com/docs/reference/engine/classes/WorldRoot). Blockcast does not detect initial overlap, so slot body clearance also uses GetPartBoundsInBox.

## Headless evidence

Run `tests/run-clone-navigation.ps1 -LuauDirectory <official CLI directory>`.

- 46 pure policy checks: cooldown/backoff, lifecycle generations, slots, segment avoidance, follow/assist/F.
- Production navigation code embedded unchanged in a controlled engine double: wall detour and speed bound, eight distinct melee slots, moving target, 30-clone non-overlap and melee filling within 17.5 simulated seconds, unreachable backoff, FIFO service for twelve blocked clones, two in-flight cap and removal while computations are pending.
- The double supplies its own wall geometry and waypoint responses; it does not certify Roblox navmesh or physics.
- Full `scripts/check.ps1 -Mode Full` runs production and fixture Rojo builds, syntax checks, all existing pure suites and Roblox-aware source/fixture types. Existing MatchService unused import and NarutoAbilityService formatting warnings are unrelated.

Local logs: `build/navigation-headless.log`, `build/navigation-full-check.log`. These ignored build artifacts are not runtime evidence.

## Exact two-client acceptance scenarios (NOT RUN)

Use Server & Clients, 2 PC clients, in the integrator's combined Sage/navigation test place. Client A summons, client B is the enemy. Test normal/rank-II/rank-III/mass summons through the actual ability/learning flow; preserve production lifetime. Record server root positions, HP, SummonMoving/SummonSwingAt and output errors. Do not publish the place.

1. **Open ground:** Use a flat floor with top Y=0; A root at (-20, 3, 0), B root at (12, 3, 0) for the standard rig (otherwise use Humanoid.HipHeight + root.Size.Y/2 as root Y). Summon 7 then 30 clones, use F on B. Within 17.5s, free inner positions should fill and remaining clones spread into waiting rings. No repeated overlapping pile at B; server damage is only from roots within the existing stop/range formula. Allow initial spawn overlap to separate without increasing it.
2. **Wall detour:** add anchored CanCollide wall centered at (0,4,0), Size=(2,8,12); keep the ground extending past both ends. A/clones start X=-12, B X=12. F B. Clones must traverse around Z>7.5 or Z<-7.5 and attack after approaching B. No root crosses the expanded wall footprint; B takes no clone damage while LOS is blocked.
3. **Single-file doorway:** two wall segments at X=0 leave a 4-stud opening around Z=0. Several clones approach together. They must queue/pass and spread after the opening, without clipping a wall or permanently sealing the doorway. If the navmesh declares the opening too narrow for radius1.5, widen to 5 studs and retest; document the actual threshold.
4. **Moving target:** while clones approach B, run B around the wall and then 12 studs sideways. Clones must update their route/slots and eventually re-approach, without a sudden position jump or attack at stale positions. Repeat F to a different valid enemy and check the previous path never resumes.
5. **Unreachable and invalid target:** fully enclose B using solid walls. Clones wait without crossing or hitting through walls; path starts remain <=4/s globally and failed clone searches at least 2s apart. Remove one wall and confirm eventual recovery. Kill/remove B and verify commands invalidate and clones follow A. Invalid F targets must remain rejected by the existing command validator.
6. **Lifecycle:** stun a moving clone while a path is computing; it must stop and ignore that path. Resume, then kill/remove/expire the clone before another result completes. No callbacks move a removed model or produce errors. A dies/respawns/disconnects, a round ends, and a cast expires: verify existing lifecycle semantics and no orphan routes/movement.
7. **Follow/assist:** with no command, A walks around a wall; clones follow assigned positions. A's valid attack assists B; F overrides assist. Let the F target disappear; follow/assist fallback resumes. Repeat with owner unavailable, then a valid new life.
8. **Regression/performance:** summon Gamakichi near clones and a neutral camp. Verify their AI, aggro/leash, hits/oil and collision remain functional. No clone body exclusions should apply to Gamakichi. Repeat simultaneous 30-clone casts from two owners with server profiling; capture frame time and ComputeAsync count. Neither this performance case nor the new geometry cases have engine evidence yet.

## Integration surface

New production files: `src/server/Services/CloneNavigation.luau`, `src/shared/Abilities/CloneNavigationPolicy.luau`. The only existing production file edited is `src/server/Services/NarutoSummonService.luau`: require, register/remove/stop hooks, repeated CanDamage gate, replacement of the final movement block. This file is the expected overlap with the Sage/rank agent; merge those small hooks while preserving its attack/rank runtime changes. No HUD, learning, Sage/KCM definitions, Gamakichi or jungle implementation files changed. New tests and this document are independent.

## Integrated engine evidence (2026-11-01)

In the integrator QA copy, official Studio MCP + StudioTestService ran two real clients.
Geometry fixture passed 12 assertions: swept wall clearance/detour, moving target,
5-stud doorway, unreachable enclosure with no through-wall damage, recovery after
opening, removed-model stale route rejection, independent 30+30 groups and reset.
Runtime logpoints were installed on the actual server module (Edit logpoints alone
were not sufficient for separate server processes). Recorded starts were at least
0.25s apart; failed same-agent retries were about 2s apart. Observed concurrency
was 1; the cap of 2 is supported by code/mock checks, not saturation in this run.

The lifecycle/load fixture passed 8 assertions: moving-clone stun, 60 live clones,
peer spacing, owned expiry, assist/follow fallback, owner death and real core death
terminal cleanup. Minimum spacing 2.3502 studs; 950 Heartbeat samples, p95 18.26ms,
maximum 398.81ms. These are Studio fixture measurements, not production profiling.
Sixty models were spawned synchronously by the stress fixture; the maximum is not
representative of the ordinary timed 4/5-clone burst. No FPS improvement is claimed.

A test-only earlier failure used a direct `phase="Finished"` assignment, which
bypassed MatchService's real core-death cleanup. The corrected fixture kills the
actual BaseService humanoid; production cleanup/guards were not changed.

Reproduce geometry with Workspace.RegressionSuite=Navigation, and lifecycle/load
with NavigationLifecycle in tests/navigation.project.json. Geometry intentionally
waits up to45s for a QA-only NavigationMetricsReady attribute after server logpoints
are installed through MCP. Production does not include these fixtures or flags.
