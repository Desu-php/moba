> **Historical handoff/checkpoint — superseded for current readiness.** Published main49d0a6b includes the integrated bounded runtime. See [latest MCP QA](MCP-QA-2026-11-02.md) for observed runtime/input/visual evidence and [current backlog](NARUTO-KIT-BACKLOG.md) for implemented, adapted and locked paths. Original NOT RUN/no-push statements below describe their earlier worker/checkpoint state, not today's readiness. CI0checks is not CI PASS; Roblox publication remains excluded.

# Combined Naruto/world increment: QA handoff

Baseline main: `78bb59a`. This branch combines five independently reviewed patch
tracks. It is a bounded increment, **not all Naruto techniques or native parity**.
No Roblox publication is performed by this integration.

## Imported tracks

- Minions `e92c431`: Alliance shinobi/White Zetsu, original primitive cosmetics,
  server attack/death presentation timestamps and client procedural motion/LOD.
- Landscape `79f4519`: deterministic 325-part scenery, village/enemy enclosure,
  forest rim, shallow visual river/bridges. New decorations have collision,
  touch and queries disabled; authored maps are skipped.
- Sage/meditation `c0c676e`: represented ranks I–III, direct or owned meditation
  mana return. Rank-III HP300, ordinary/KCM initial mana0 and group recall cost0
  remain named provisional policies, not newly resolved native values.
- Advanced `e2bc48b`: base-form bounded Odama/melee RS, wakeable Sleep and IV
  ordinary/mass clones with explicit post-200 mana threshold policy. Uncertified
  ranged/form variants remain absent from network admission.
- KCM `136a951`: private chakra, I–III entry with Hagoromo gate, cancel/dash/
  conversion, owned retained-stat layer. Full Kurama/sharing/Rikudo remain off.

## Integration corrections

- One X route: active KCM -> KcmCancel; otherwise -> Rasenshuriken window. There
  is one alias dispatch/listener, not two competing X handlers. Z/T/Right/J/E/
  Left retain their own actions. All configured ability keys/aliases stop held
  M1; typing and processed input retain existing protection.
- Meditation form uses `Naruto.ConfigureMeditationForms(Kcm.MeditationForm)`;
  private current form is also the base advanced admission source. Existing
  meditation clones keep their spawn-time profile. Unsupported Sage/KCM variants
  are rejected before spend and their temporary Z/X hints are hidden.
- Sleep is checked before early Naruto routes and inside KCM's canCast snapshot.
  AttackAttempt wakes before Oil's single miss roll; positive Damage.Applied is
  separate. Remove the legacy nested ApplyAttack reassignment in CanDamage and
  the duplicate CombatService Oil roll. Stun/movement ownership remains separate.
- KCM cooldown has one owner: domain balance. Adapter publish now includes the
  absolute deadline; service no longer maintains a competing cooldown cache.
  Seven deterministic reconnect/publication regressions cover retained deadline,
  no rejoin debit, stale token, exact boundary and fresh epoch.
- Source admission actions are separate from stat layers: Sage activation disables
  new KCM entry; Sage expiry clears that gate; source KCM exit can restore entry
  while its Sage layer survives. Cancelling KCM during Sage preparation does not
  cancel the preparation. The KCM runtime fixture now tests both asymmetric orders
  and peer-owned SageIII/KCM composition instead of assuming all entries are free.
- HUD retains temporary action notices alongside the separate chakra/form status;
  joining meditation and KCM must not hide chakra or advertise two X actions.
- `scripts/check.ps1`/`verify.ps1` include all new pure suites and test inputs.
  Full builds/types cover minions, meditation, advanced and portable KCM fixtures.
  `tests/kcm.project.json` avoids relying on an author's absolute-path build file.

## Verification boundary

Fresh headless combined gate: **PASS31.13s**, 181 Luau files, all pure suites,
production/test builds and Roblox-aware source/fixture types. Included checks:
MinionPoses1154, map deterministic325-part plan, Sage40, Meditation32,
NarutoAdvanced48, AbilityInputRules24, KCM domain64/adapter70/gameplay36,
learning28, clone ranks54 and navigation46. CLI lint still reports the existing
MultiLineStatement warning in NarutoAbilityService; no type errors.

Targeted timings were minions2.71s, landscape1.20s, meditation3.34s and advanced
3.55s before final KCM integration. KCM merged targeted was2.16s; the final combined
gate covers subsequent context/HUD/availability integration. These are execution
durations, not total user waiting time or a measured percentage speedup.

**New Studio runtime/input/visual/load checks are NOT RUN.** The official bridge
handshake succeeds, but the connected instance returned `Place is not open`.
No user scene or settings were changed. There is no open-local-place tool among
the current34 schemas; start_stop_play only toggles an already open place.

Open our existing saved `moba-sage/build/sage-tests.rbxlx` through Studio File/Open
to establish an owned Edit DataModel. That baseline file is not evidence of this
new revision. The integrator must verify its identity, sync reviewed sources and
isolated drivers, and run [focused scenarios](../tests/integration-smoke/README.md).
Do not repeat unchanged full suites merely because the date/session changed.

Required remaining runtime: actual navmesh/LOS and camera/bridge readability;
minion animation timing/three-wave cleanup/108-cap profiling; two-owner meditation
current-mana/expiry; KCM layered admission/cancel/dash/reconnect/Hagoromo boundaries;
advanced windows/Sleep/IV/AoE and real keys/hold/F; actual core terminal cleanup.
Server assertions, observed input and viewed pixels are separate evidence. Stop
only our tests and retain all source unknowns and explicit policies in the report.
