# Locked Naruto variants: exact evidence requests

2026-11-02. Documentation-only follow-up; no runtime changes and no Warcraft execution.
The implementation commit e2bc48bbded6040431913654e41aa5e220492064 and its patch are unchanged.

## Evidence boundary

The available source contract is `docs/source/naruto-progression-and-branches-contract.txt`,
also read from Library `libfile_ba235c3502a88191b93cf938ba3922a6`, lines224-250.
Base A013/A014 evidence was read from `libfile_de3939fe995081919fd57704506aa2b1`,
lines25-179. These are prior static-analysis reports, not newly inspected raw JASS.
The source binary was resolved in Library as `libfile_1fd78f0b2d588191ae7316eed6853019`,
filename `Naruto_Legend_1_7a_FIX20_3.w3x`, size4,979,885 bytes.
Its expected SHA256 is 8c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8.
No archive extraction or execution occurred in this follow-up. Exact-name Library
searches did not locate separate `war3map.j` or `forms-object-evidence.json` files.
Thus no locked variant is newly certified by this audit.

All line numbers below refer to the reported 1-based `extracted/war3map.j`, not this
document. `ff` means the report gives a start only: extract the complete containing
function and every referenced callback/condition, rather than invent an ending line.

## Per-variant extraction queue

| Rawcode | Established by existing contract | Exact additional evidence needed |
|---|---|---|
| **A0HO / Cho Odama** | ANhs base; CD40/range600. Cast46037-46109, pulse function starts46122, collision callback starts49210, movement49313ff. Collision90+.8STR/radius450/stunA0JT8; extra45+.4STR pulses. | Full `Trig_pod_xe2_nar` including trigger registration/period, filters and every enable/disable call; full callback49210 and state6 movement branch; endpoint/termination tests and damage duplication. Dump A0HO and original/custom ANhs records, especially `amcs`, `acdn`, `aran`, `atar` and ability data. **Native mana is absent; cannot derive a number from this map override alone.** |
| **A0HQ / Wakusei** | Absk base; CD100/duration15; `Trig_RasenRikudo`48359ff, hit48791-48824:350+4STR, stun4, caster pause.5, push18/.03 for.7. | Complete cast/cleanup and hit functions, state3 changes and .7sec endpoint ownership; all writes of the common attack gate. Dump A0HQ plus original/custom Absk `amcs`, movement/attack/damage-taken data, `adur/ahdu` and target fields. **Mana cannot become0 because it is omitted.** |
| **A0HU / Rasen Ren** | Cost500/CD60/duration15; cast47076-47206;1.3prep/13.7window; self integer SurikDamage=(600+4STR)/87; melee48933ff; ranged release **A057**. | Complete melee state10->11->4 branch (including push and all waits), all A057 action/condition/registration references and transitive periodic/endpoint callbacks, cancellation cleanup. Dump A057 target/order/range/cost/CD fields and spellbooks granting it. Check whether release has an additional debit/CD. Melee and ranged must remain distinct paths. |
| **A0HV / Magma RS** | Cost700/CD60/duration15; cast47250-47358, assignment47273; state12, radius350, YReal414=-8; melee48994ff; self base700. | Complete state12->5->4 branch, all ranged release grants/rawcodes and transitive trajectory callbacks (release rawcode not supplied by current report), every write/reset of YReal414/radius and SurikDamage. Actual common victim pulse is base600, not700. Full release object records are required; do not guess A057 reuse. |
| **A0IA / Bijudama RS** | Cost1300/CD60/range0; cast47401-47503, state13,1.3prep/13.7window, radius350/pull2. This cast does not assign SurikDamage. `Ncl2` omitted. | Exact melee self-damage callback currently referenced only as490xx; complete all writes/readers of SurikDamage (including aliases/dynamic assignments), state13 cleanup/ranged graph. Dump A0IA and ANcl `Ncl2`, `atar`, order/channel and visibility fields. **No per-cast intended self-damage formula is established; a stale previous-cast value is not an acceptable implementation.** |
| **A0HY / Cho Bijudama RS** | Cost1800/CD60/range2000/pointNcl2=2; cast47511-47575;7projectiles; periodic36127-36190; filter34766-34810; damage34811-34820.58 nominal pulses, radius636+4/damage tick, pull2. | All creation/assignment/reset/read sites of YReal418 and related counters/groups; every membership mutation of the6 exclusion groups in34766-34810, per-projectile/owner indexing, cancellation and endpoint callbacks. Inspect exact arithmetic literals/types at34811-34820: unlike the common AoE and A0HZ, the report does **not explicitly settle integer vs real division here**. Do not infer total1050+4STR for every victim or7x overlapping damage. |
| **A0HZ / Cho Bijuu RS** | Cost1800/CD60/range2000/pointNcl2=2; cast47591-47706; state423;116explosion ticks; counter426 initialized16, first eligible and then every17ticks;7nominal damage pulses. Real(900.+4currentSTR)/7. at34856-34864. | Full periodic state423/426 dispatcher and all initializations/resets, projectile/visual vs damage-group identity, filters and expanding target inclusion. Callback34866-34873 casts cripple: extract its actual dummy ability rawcode, level/order, buff and object record; request its explicit slow/attack-reduction/duration/filter/dispellability fields. **The cripple rawcode is not named in available report; do not invent one.** Native-only omitted effects remain unresolved. |
| **A0HW / ChakraKnife** | Cost80/CD140/range600/unitNcl2=1; region test47714-47760, action47762-47800; .01delay/selfstun1, valid-region targetstun2/damage350+2STR/offset80. | Complete condition+action, initialization and every mutation of region pairs `Ne_tp`, `Inst`, `IZM`, `Duel`; exact rectangle identifiers/geometry/association. Need evidence for shared-region truth conditions, invalid-region cost/order, original caster-position capture and native teleport/pathing edge. An unrestricted MOBA blink is a design adaptation, not source parity. |

## Common dependencies: request once, reuse across all variants

1. Obtain raw `war3map.j` plus complete parsed `war3map.w3a` original AND custom
   tables with parent IDs, field IDs, rank indexes, types and values. Preserve hash
   of extracted files and original binary. An object tooltip is insufficient.
2. Extract grant sites44446-44455,46460-46484,46552-46560,46603,46634-46635,
   46680-46685,46763-46788, and all relevant cleanup/visibility resets. Dump spellbook
   **A0HT**, its spell-list field/metadata, and related **A0HR/A0I2** where referenced.
   Establish exact grant lifetime, form/rank/held-state requirement and release entry.
   A trigger matching only rawcode does not prove independent cast eligibility.
3. Extract shared attack conditions48500-48589, registration49104-49109,
   `Trig_Surik_oblast`48282-48356 and its timer registration, and the movement
   dispatcher49313-49477. Trace all gg_trg_VS enable/disable writes, CReal35 state
   writes, YReal414 changes, radius/scale counters and SurikDamage writes/readers.
   Collect full functions and callback call edges, not unrelated large JASS slabs.
4. Dump **A0JT** rank2/3/4/8/9 `adur`, `ahdu`, `Htb1` to keep self control, victim
   stun and actual damage separate. Source distances remain WC units; visual scale
   percentages120/200 are not distances. Inspect `Damage_Unit`4124-4132 and referenced
   damage hooks before labeling effects unblockable or true damage.
5. The source report found embedded native SLK/metadata absent. Missing `amcs` on
   A0HO/A0HQ and inherited A0IA channel data cannot be resolved by reading the same
   omitted override again. Need the exact selected Warcraft base-data/version and
   confirmed inheritance semantics, or an explicitly labeled Roblox policy. Native
   debit ordering, callback scheduling and immunity remain engine boundaries; no
   Warcraft execution is authorized/requested in this audit.

## What can follow in a separate patch without guessing

**Ready as a non-executable domain/evidence patch:** explicit cost/CD/range records
for A0HU/A0HV/A0IA/A0HY/A0HZ/A0HW; A0HO/A0HQ cost remains absent with a blocking
reason; formula helpers for the confirmed common integer pulse and A0HZ real pulse;
source-location IDs and a form/grant matrix. Test that missing costs/targets cannot
silently become zero/self, and distinguish selection-time self-damage from current-STR
victim pulses. No remote exposure, no purchased extra hero line, no promised totals.

**After focused raw extraction:** Wakusei's isolated melee handler is small, but
actual cast admission still needs its mana policy. Rasen Ren/Magma can get separate
melee handlers once complete transitions/push/cleanup are traced; ranged release
stays locked independently. ChakraKnife can have a pure region-policy function with
default denial; no live teleport until exact source regions or an explicit MOBA
adaptation is selected. Large RS projectile ownership/filtering comes after that.

**Still blocked:** A0IA self-damage has no established intended per-cast formula;
A0HO full pulse schedule; A0HY overlapping group semantics; A0HZ native cripple;
unresolved inherited costs/channel fields. Do not copy original global-state bugs
or silently repair them into an invented damage formula.

The earlier melee A013 adapter's88 nominal .04 pulses over a half-open3.5sec window
remain an explicit Roblox scheduling choice, not newly certified native timing.
This audit therefore supports further isolated work, not a statement of full parity.
