# Naruto rank policy: isolated integration slice

Base: `d7c513332eddd5a615b4bac3069316301ab7cbe8`. No production runtime,
learning, HUD, Studio or source checkout changes. No Roblox publication or push.

`NarutoRankPolicy` is a pure, opt-in API. It does not grant skills, spend points,
charge mana or claim complete Warcraft/Roblox parity.

## API

- `minimumLevel(id, rank, cloneFirstLevel?) -> (number?, status)`:
  Rasengan has explicit map levels 4/11/18. ShadowClones has four ranks and
  spacing 4, but omitted/inherited first `arlv`. Without an explicit application
  choice it returns `NativeFirstLevelUnknown`. Supplying 1 yields candidate
  1/5/9/13, always labelled `CallerSelectedNativeBoundary`, never map-verified.
- `purchasePlan(profile, id, requestedRank, cloneFirstLevel?) -> (plan?, reason)`:
  validates finite integral level/points/learned rank, previous rank, max rank,
  required hero level and one point. Returns a proposal without modifying the
  profile. One-point cost follows the documented native default in the supplied
  progression contract; this API does not certify native UI/event ordering.
- `cloneRank(rank) -> (config?, status)` exposes counts 3/4/5/7, cooldowns
  50/46/42/38, mana200 and lifetime20. Configs are fresh copies.
- `castReason(id, rank, variant) -> string?`: nil means this policy supports
  that branch, not that world adapters/target admission are implemented.
- `ordinaryClonePlan(rank, variant) -> (config?, reason)` combines the safe
  cast subset with the per-rank clone config.

## What can be integrated

| Branch | Readiness |
| --- | --- |
| Rasengan I ordinary | Existing supported baseline; level4 |
| Rasengan II/III learning requirements | Confirmed 11/18 and three-rank cap; metadata ready |
| Rasengan II/III cast effects | Closed: inherited buff fields and later variant/form handlers are incomplete |
| Clones I ordinary self/point | Existing supported baseline; first learning level remains explicit application policy |
| Clones II/III ordinary self | New policy-ready configurations: 4/5 clones, CD46/42; world integration and two-client QA pending |
| Clones II+ point | Closed: advanced point handlers incomplete |
| Clones II+ enemy | Closed: native Sleep wake/protection policy unresolved, never replaced by stun |
| Clones IV self / mass | Catalog records seven/CD38; cast closed because self-target can choose30 and the native mana-ordering boundary remains unresolved |

There is no rank-based Rasengan damage multiplier invented here. The existing
base formula remains 120 + current STR + 10*heroLevel. Existing evidence records
explicit movement .20 at ranks II/III and missing rank-I movement; it does not
certify all inherited damage-taken/speed fields or the rank-III form graph.
Odama, Rasenshuriken, alternate payloads and mass summons are not enabled.

## Integration sequence (separate owner)

1. Import the new module, then call `purchasePlan` from the authoritative
   learning adapter against the current server profile. Restrict purchases to
   the actual supported runtime subset BEFORE spending; metadata readiness
   alone must not raise `SkillLearning.runtime` caps. Keep unsupported ranks
   visible as unavailable if desired.
2. Keep clone first-level choice in explicit application configuration. Preserving
   the current prototype choice1 is an adaptation, not resolution of native arlv.
3. For II/III self-target clone casts, resolve rank from learned server state,
   use `ordinaryClonePlan` for count/CD/cost/lifetime, and commit the200 mana
   debit, cooldown and burst atomically. Reuse CloneState/CloneCommands ownership,
   life/round guards and current summon-copy policy. Do not retrofit old clones
   when a rank is learned. Do not expose II+ point or enemy targeting.
4. Make HUD rank labels/CD match the server's chosen rank; verify II/III count,
   damage attribution, fresh Q markers, death/reset cleanup and concurrent
   Naruto owners in a separate two-client Studio session.
5. Only unlock the blocked branches after their specific evidence/adapter tests
   exist. Native first-level data or a controlled native fixture is still needed
   to call the clone learn sequence exact.

## Verification

Using the existing local Luau0.744 executables, no downloads:

- `luau-analyze src/shared/Abilities/NarutoRankPolicy.luau tests/NarutoRankPolicy.spec.luau`: pass.
- `luau tests/NarutoRankPolicy.spec.luau`: 109 assertions pass.
- Existing `NarutoLegend.spec.luau`: 142 domain checks pass.
- Existing `SkillLearning.spec.luau`: 25 assertions pass.

Coverage includes exact Q level boundaries, sequential purchases, unknown clone
arlv fail-closed behavior, configurable native boundary labels, forged/nonfinite
numbers, zero points, max ranks, profile immutability, returned-config isolation,
and denial of all unsupported variant paths. No Studio/native parity claim.

No AGENTS.md or project .agents directory was found in the supplied checkout or
its ancestor directories. The installed graphify skill was inspected; no graph
exists, and no graph build/software installation was needed for this bounded edit.

## Integrator update, 2026-11-01

Imported without changing the author's copy. The application now reads learned
server rank and uses ordinaryClonePlan for self-casts I/II/III. SkillLearning caps
clones at III before spending, supplies the explicit first-level policy1, and
uses purchasePlan for sequential gates. Rank II+ point and all enemy-target
branches fail before mana/cooldown/burst mutation. Rasengan runtime cap remains I;
IV/mass/Sleep are closed. HUD clone names reflect learned I/II/III and cooldown
deadlines come from the committed server cast. Existing bursts keep their count.

NarutoCloneRanks.spec exercises the shared policy + real CloneState burst/life
model and learning API. Two-client clone-ranks fixture is built/typechecked,
but its runtime/input acceptance is NOT RUN until new screen permission.
