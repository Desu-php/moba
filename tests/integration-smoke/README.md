# Focused integration smoke: five parallel patch tracks

This is a **scenario specification**, not an executed test or a PASS-producing
runner. `scenarios.json` is the pending acceptance manifest. Patch-specific calls
will be bound to reviewed real APIs after each worker supplies its patch and test
fixtures; no fictional KCM/meditation API or production bypass is introduced.

## One owned MCP session

1. Identify the owned QA place and verify source fingerprints against the final
   integration revision. Never run the saved old baseline as proof of new patches.
2. Reuse existing `tests/sage.project.json` multiplexer, two-client test launch and
   existing navigation/learning/manual drivers. Extend the isolated test build,
   not production remotes. Keep a run ID, fixture generation and owner/life/epoch
   on all test records. Test setup may seed resources/learned ranks only inside
   the fixture; at least one learn/cast/command must use actual client input.
3. Prepare two opponents and an ordinary lane wave once. Reuse a visible hostile
   target, allied control target, real solid wall, corridor and unreachable goal.
   Put a single smoke-owned container around disposable fixtures. Do not delete
   the patch's actual map or replace geometry with an empty test floor for LAND.
4. Run LAND and MINION on actual new geometry. Run independent Sage/meditation,
   KCM and advanced-technique checks in the same session, resetting owned fixture
   state between cases. A completed case may not leave a live timer or an
   admission/availability override behind.
5. Combine the cross-track cleanup: one owner death/respawn and a peer cast that
   continues; replay old requests; finally destroy the **actual core** and assert
   terminal cleanup. Setting `match.phase='Finished'` alone does not prove the
   real core-destruction subscription path. No match restart is expected.
6. Stop only our session via `StudioTestService:EndTest`. Record original/user
   place state separately; no user scene save, discard, switch or publication.

## Finite cases and observable assertions

| ID | Setup and action | Required observation / failure boundary |
| --- | --- | --- |
| LAND-01 | Walk an ordinary hero and command live ordinary clones through each changed lane/forest corridor, then move the target | All three lane routes and tower/core/spawn access remain reachable; real navmesh detours and repaths; no wall penetration. Route timeout is FAIL, not silently replaced direct movement. |
| LAND-02 | Place hostile across a real wall, attempt M1, clone and relevant new technique; then make target unreachable and reopen the route | Server LOS rejects blocked damage; unreachable route backs off; newly reachable route recovers. Measure actual path starts/inflight, preserve 4/s, max2, per-clone.8s minimum and failure2s policy unless a reviewed patch explicitly changes them. Normal gameplay ranks remain enforced. |
| MINION-01 | Observe one allied ninja and enemy Zetsu lane unit on both clients while idle, walking, acquiring target, attacking and losing target | Faction silhouette is distinct; team/entity/epoch IDs remain correct; state/velocity drives locomotion; attack pose follows authoritative windup/hit/end. Damage is server-owned and single-event, never animation-marker granted. No per-frame animation restart or lingering swing after cancellation. |
| MINION-02 | Let minion die, leave target range or finish its attack while another wave continues | Cleanup once; no drifting corpse attack, stolen hero identity, changed reward/owner credit, missing neutral/hero targeting or unexpected server script from a cosmetic asset. |
| SAGE-01 | Learn actual supported rank, use actual meditation toggle/cast; simultaneously cast the peer's direct Sage | Confirm preparation, correct mode cost/CD, no immediate clone-mode direct refill; direct peer still restores its own mana once. Clones are stationary HP1/no attacks, with actual current mana under named initial-mana policy. Sage III is tested only if patch explicitly enables its provisional/native HP policy. |
| SAGE-02 | Recall/destroy one meditation clone, expire another, and attempt duplicate return; cross the rank/level count boundaries using controlled pure fixtures plus one real supported runtime case | Current mana returns once to its actual owner, never maximum500 instantly or the other Naruto. Natural35s expiration is exercised once, not repeated for every rank. Counts and native/adapted policy status remain explicit. No duplicate stat layer, reset of items/growth, invented entering/exiting heal or rank point spend for unsupported behavior. |
| KCM-01 | Learn eligible supported KCM rank, enter, inspect separate chakra/mana and stats, cancel around a real tick | Entry200, CD10, drain40/1s with declared timer ordering; manual cancel follows selected next-tick semantics. Progression/ranks/permanent growth/items survive morph. Dash is tested only if genuinely wired, and its .5s grant/range/cost/damage path is distinct from visual movement. |
| KCM-02 | Combine eligible Sage state and KCM transitions; try Gamakichi/Kurama while blocked; try rankIII without Hagoromo; use eligible level16 conversion if wired | Server admission and HUD agree with source availability matrix and selected morph policy. Independent Sage modifier is reapplied/removed once. Forbidden learn/cast leaves points/resources unchanged. Resource conversion is200 chakra to200 ordinary mana, not free mana. No flag granted merely by reaching25/27. |
| ADV-01 | Exercise only new supported Rasengan or shuriken melee/release branch through real input; change current STR before delayed impact | Correct grant/form/rank chain; one cost/CD/marker; source attack trigger and impact timing. Current stats at the specified frame; distinct self/target damage, integer division/pulses, push direction and wall policy. Do not infer total AoE from one tooltip or merge all branches into a projectile. |
| ADV-02 | Exercise supported Sleep and IV threshold below/exactly/above selected effect-frame boundary using deterministic domain fixtures plus one real runtime admission | Sleep does not create combat damage clones or become generic stun; selected wake policy works. IV selects7/30 and commits base/extra cost once under explicit native-order adaptation. If source boundary remains unresolved and runtime stays closed, assert rejection without resource/point loss and record capability NOT IMPLEMENTED, not feature PASS. |
| SHARED-01 | During pending effects, kill/reset owner A while B continues; resend old character/life/epoch/request IDs | A's stale work is rejected and cleanup idempotent; B's state untouched; owned mana returns/rewards/modifiers happen once; committed cooldowns retained. Do not loosen production guards for fixtures. |
| SHARED-02 | Actual learn buttons/Ctrl keys, hold/release M1, F/world click, HUD/portrait/icon/state checks; destroy actual core last | No F/HUD-generated M1; repeat stops on release; rank/resource/HP/MP/status match server. At terminal all owned movement/effects/timers stop and no new match begins. Two-client network assertions and viewed pixels are separate evidence. |

## Timing and results

All polls yield and have deadlines. The manifest contains **maximum diagnostic
waits**, not measured execution durations or claims that a scenario passed.
Client arrival gets45s, ordinary state/replication3s, route progress12s,
respawn10s, real Sage prep12s, and a single meditation lifetime probe38s.
Use controlled clocks for threshold permutations, repeated cooldown/timer math
and long Hagoromo360s logic; retain real preparation/drain/lifetime samples.
No silent retries after a deadline: record FAIL with state/position/source hash.

For each case save revision, affected file hashes, selected policies, fixture
generation, start/end/elapsed, assertions, and evidence. Result states are PASS,
FAIL, BLOCKED, NOT RUN, REUSED, or NOT IMPLEMENTED. PENDING definitions may never
be relabeled PASS merely because a tool returned `Success`. Network/server
assertions do not certify animation/rendering/input. Existing MCP capture grants
must be checked against their scope; do not assume old two-image permission
authorizes unlimited new captures.

Run affected pure/type checks per patch; one combined final aggregate after the
last gameplay fix. Reused results require unchanged affected source/dependencies.
Report cold build/start overhead, fixture time and result collection separately.
