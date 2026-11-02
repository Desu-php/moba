# NarutoKcm domain integration

Base: d7c513332eddd5a615b4bac3069316301ab7cbe8. No runtime wiring is included.

## Existing interfaces checked

- `NarutoResources`: ordinary mana pool (`mana`, `maximum`, `regen`, `at`), mutable domain functions.
- `SkillLearning`: authoritative `Profile.Level`, `Learned.KCM`; configured minimums 13/20/27, KCM gameplay composition now enables represented ranks1–3; see `NarutoKcmGameplay.md`.
- `GamakichiState`: per-owner state/cast identity pattern. KCM uses independent owner state and monotonically increasing cast ids.
- Source: `docs/source/naruto-progression-and-branches-contract.txt`, forms section A017 and Kurama resource. No local AGENTS.md or .agents/skills was found in the source checkout or Documents parent.

## Runtime API

Require `NarutoKcmConfig` and `NarutoKcmState` from the same Abilities folder, then `local Domain = StateModule.configure(Config)`.

One `Domain.new(now)` per hero session. Keep this object server-side. Supply authoritative Context:

```
{level, rank, hagoromo, alive, fullKurama, kuramaCooldown,
 sageRemaining, sageAuraPresent}
```

`rank` is the learned KCM rank, never a client request. No XP, learned skills, ordinary mana, item upgrades or Sage timers are stored or reset by this module.

1. At every authoritative context change, call `update(state, now, oldContext)` before applying the new context. Update again at the same time with the new context when necessary (e.g. death). Process returned events once.
2. Call `enter(state, context)` at `state.clock`; it returns accepted/reason/events. It debits exactly 200 separate chakra and starts CD10. Apply the morph only on Entered. Capture its id for subsequent callbacks.
3. Drive `update` on the server clock. Drain uses 1-second ticks measured from entry, independently of the resource tick phase. DashReady appears after .5 seconds. Cancellation/buff removal set flags via `cancel(state,id)`/`buffRemoved(state,id)`; the next drain still charges40, clamps zero, then emits Exited.
4. `availability` provides form-related availability only, not full cast validation. Enter additionally validates rank/level/Hagoromo/chakra/CD/death/full-Kurama. Runtime must deny Gamakichi while active, hide dash on exit, and restore eligible skills from current authoritative progression. Apply full-Kurama availability only to its separate implementation.
5. On ReapplySage, reapply the external current Sage layer. It is emitted only when remaining>1 and aura is present. Do not restart its duration or replace progression. Death/close do not emit reapply.
6. `convert` requires level16/pool200 and returns RestoreOrdinaryMana(200). Apply once through the ordinary mana owner, clamped to its maximum. Failed conversion changes nothing.
7. External sharing code may set the count of owned active grants with `setSharingCount`. Resource ticks pay4/unit after optional idle regen; RevokeSharing requests removal of those grants. Grant stats, targeting, lifetime and heals are not implemented here.
8. `close` is idempotent: removes the active form and sharing ownership, makes updates/commands inert. Process Exited/RevokeSharing, then discard state. Never reuse a closed state for respawn/new round. A late callback carrying an old active id cannot cancel a newer cast. Runtime must additionally associate async callbacks with the owning State object/session, since ids start over on a new State.

Events are plain returned records; there are no coroutines, callbacks, Instances or timers to leak. ChakraChanged.amount is a delta; read state.chakra for final authoritative value. Events must not be applied twice. Exited includes id/rank/reason. No native animation/stat mutation is performed.

## Explicit policies and limits

- Manual cancel matches source next-tick charge; death uses immediate cleanup without an extra drain as a safety adaptation.
- Independent source timer ordering is unresolved. This module chooses resource-before-drain on equal timestamps. Threshold guard is strict `<900+100*level`, not a hard maximum; idle20 may overshoot and the entire sharing block skips at/above threshold.
- `update` rejects clock gaps over60 seconds atomically with ClockGap. This bounds catchup even for a steady sharing pool. Replay smaller intervals with historical context, or use an explicit runtime suspension policy. NaN/infinite/rollback clocks and malformed context leave state unchanged. Context is assumed stable across each replayed interval.
- Raw morph records in config are evidence, not additive bonuses or effective runtime totals. An integration policy must preserve progression, upgrades and temporary layers; inherited stats/metamorph retention need native fixtures. This module does not silently substitute them.
- Full Kurama/Rikudo, native transition timing, native dash targeting/pathing/damage, Hagoromo's grant timer, sharing grant abilities and full-Kurama passive heal are outside this module. FullKurama is only an external resource suppression/gating flag.
- Native CAST/EFFECT event ordering and actual buff lifecycle remain runtime integration tests. No claim of exact native parity.

## Targeted headless verification

Using the pre-existing Luau0.744 binaries in `%LOCALAPPDATA%/Temp/anime-fight-luau-0.744`:

```
luau-analyze src/shared/Abilities/NarutoKcmConfig.luau src/shared/Abilities/NarutoKcmState.luau tests/NarutoKcm.spec.luau
luau tests/NarutoKcm.spec.luau
```

64 deterministic domain checks pass. The optional headless adapter and its separate validation are documented in `NarutoKcmAdapterIntegration.md`. Coverage includes all rank gates, Hagoromo, exact entry cost, CD, fractional/no duplicate drain, dash delay, delayed cancellation/removal, depletion/clamp, death, closed sessions, stale ids, owner isolation, Sage layering/expiration, conversion, threshold overshoot/sharing quirks, bounded catchup, invalid clocks/context. These are headless domain tests, not Studio/network/morph validation.
