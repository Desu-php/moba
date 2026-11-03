# Naruto kit — current runtime and bounded backlog

Updated2026-11-03 for **published main49d0a6b**. Replaces the78bb59a planning matrix. This is not full Naruto/native parity. CI reported **0 checks**, not CI PASS.

Source: [static map contract](source/naruto-progression-and-branches-contract.txt), map SHA2568c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8. Base evidence: [NARUTO-LEGEND](NARUTO-LEGEND.md). Static analysis does not certify Warcraft execution.

## Current five-line boundary

| Learned line | Implemented bounded runtime | Policy / closed boundary |
| --- | --- | --- |
| A014 Rasengan I–III,4/11/18 | Ordinary helper/right-hand hold, explicit attack-start, delayed current STR/current-level impact and two-phase push; temporary Z Odama and X base melee RS | Later form variants/ranged releases closed. Inherited native fields remain distinct from policy |
| A04N clones I–IV | Self3/4/5/7, eligible massIV30; CD50/46/42/38, cost200, life20, .30 outgoing/20 incoming; follow/assist/F/navigation; enemy Sleep II+ | First level1/skip4 is policy. IV eligibility checks after base200, drains .30max additionally; native debit order not certified. Rank-I ordinary point only; later point/form handlers closed |
| A005 Gamakichi, ten ranks | Early/adult summon, follow/assist/F, oilG/adult four-wave channelH | First unlock, placement/replacement/control/defaults are policy boundaries. Channel1s cadence/cap allocation adapted; oil Nsi4 attack-speed reduction absent |
| A09J Sage I–III,6/10/14 | Cost25/CD150, prep10/7/4, direct restore200/350/500 or owned meditation; stat layers/current-mana return | III HP300 and I/II armor3/7 provisional. Aura47/cleanup51 selected. Ordinary/KCM initial mana0; group J recall5s/zero-cost is policy, not certified A0I5 targeting/cost |
| A017 KCM I–III,13/20/27 | Private chakra, entry/cancel/dash/conversion, retained-stat layer and layered Sage; III needs actual Hagoromo grant | Morph deltas preserve resources/growth/items, not native metamorph equivalence. Availability actions remain separate from stat layering |

Exactly five learned lines. SkillLearning and authoritative cast admission define runtime, not catalog whole-line flags. Cap30; initial point/+1 per level; no invented +2-all-stats sink. M1 is directed repeated melee/AGI cadence capped2.5/s, without combos. PC only.

## Implemented auxiliary/form paths

- **Odama/melee RS:** Z in base window, X in eligible Odama window. Separate grants/costs/cooldowns, self-damage versus victim AoE/current impact stats. [Bounded implementation](NARUTO-ADVANCED.md); original worker handoff is historical.
- **Sleep:** separate owned sleep, wake-on-attack/positive-damage, overlapping rigid-stun preservation. Native immunity/blocked/zero/DOT edges remain named policy boundaries.
- **Meditation:** ordinary rankIII level18 gives2; KCM18 gives1/19 gives2; Kurama gives2. HP1/immobile/no attacks/life35. Death/expiry/recall settles current owned mana once; stale/owner-death/terminal invalidates safely.
- **KCM:** entry200/CD10;40 drain before each cancellation check, dash after.5s; Left at16 converts200 chakra→200 ordinary mana. Idle+20 lies inside strict pool<900+100*level; no invented hard clamp. Sage/KCM admission is asymmetric by source actions.
- **Hagoromo:** level25 starts360s, alive wait/1s presentation; does not grant a learned rank. KCM III still needs rankIII at27 and actual admitted morph/grant.
- **Kurama A01F:** level21, cost2500 private chakra/CD160, effective30s buff and separate25s release-lock behavior; owned retained-stat policy, current-maxHP proc and actual20HP/20MP receivers. Bounded runtime implemented; full beast art/downstream kit absent.
- **HY/HZ:** V/B ground runtime under private current KCM III/Hagoromo grant;1800 each/CD60 independently. Per-cast counters, expanding areas/current STR/motion/shared ownership lease. Seven/nine original procedural visuals. Null-group non-exclusion/wall-safe displacement are policies, not unconditional victim totals/native parity; no fabricated final cripple.

## Remaining bounded backlog

| Path | Evidence / next deliverable | Runtime boundary |
| --- | --- | --- |
| HU Ren / HV Magma RS | Static graph known; consolidate preparation, melee/ranged transition, self versus victim damage, lifetime and grants before selecting a complete path | Disabled. Do not reuse HY/HZ counters or infer victim damage from self-damage variable |
| A057 ranged release | Audited release graph still needs native behavior/debit boundary | Inherited cost unknown, not zero; resolve or explicitly choose bounded policy before admission |
| ANso native edges | Resolve native semantics used by graph separately from script callbacks | Static graph alone does not prove native timing/filter/status parity |
| A0HO Cho Odama | Inherited cost, movement/pulse/endpoint sequence | Closed; no invented flat total/borrowed cost |
| A0HQ Wakusei | Eligible form/held path, CD100, distinct hit known | Inherited mana/target edges unresolved; closed |
| A0IA Bijudama RS | Advanced grants/AoE evidence exists | Inherited targeting/history-dependent self-damage intent unresolved; closed, no copied global bug |
| A0HW Chakra Knife | Domain/source region-gated teleport | Runtime closed; requires visible map-region adaptation |
| Sharing A0JW | Owned domain/resource rules | Runtime/input closed; native filter/shield/speed/range/mana/cleanup need complete bounded policy |
| Three-head | Domain-only transaction boundary | No player action; validate living owned pair/current-mana settlement and unresolved native/cost behavior |
| Other point/form payloads, rods/orbs/face/Bijuu | Separate contracts/grant chains | Closed unless independently implemented and verified |

Gamakichi Nsi4 and inherited attack/armor/native spell fields remain gaps. Tooltip alone does not certify a number. No wholesale Warcraft assets/JASS copying.

## Evidence and next gate

[MCP-QA-2026-11-02](MCP-QA-2026-11-02.md) is the latest runtime/input/visual report for this published increment: reused196 focused assertions, minion7550 invariants, real arrow/input correction, terminal14, captures and bounded performance samples. Final source gate40.31s covered195Luau files/22builds. Evidence applies to its revision/scope, not every native edge, long-session behavior or future patch.

Earlier [five-track handoff](INTEGRATION-QA-2026-11-02.md) and [Kurama/HYHZ checkpoint](KURAMA-HYHZ-INTEGRATION-QA.md) preserve pre-runtime NOT RUN states; they are not today's blocker. TESTING.md remains a historical dated report. The Studio client near15FPS was already limited in baseline; no production FPS guarantee follows.

Next bounded slice: source review → affected pure/type checks → one owned two-client QA with relevant input/HUD, resource/stat, owner/life/epoch and terminal assertions → final aggregate on final code. Record fresh PASS versus REUSED, avoid repeats by date. One integrator owns Studio/shared files. Preserve user/author copies, lane routes/LOS/navmesh, five lines and terminal single-match. No force push or Roblox publication.
