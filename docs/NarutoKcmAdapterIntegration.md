# NarutoKcm runtime adapter integration

This is an unconnected, headless server adapter. Existing services use per-owner records and explicit Update/Remove; this adapter follows that pattern. No scheduler, Roblox APIs, remotes, UI, learning changes or project mapping is added. The shared location allows the standalone Luau tests to load it; production must instantiate it only on the server.

## Construction

```
local rules = NarutoKcmState.configure(NarutoKcmConfig)
local runtime = NarutoKcmAdapter.configure(rules, ports, explicitMorphPolicy)
```

Omitting the policy, or `policy.enabled=false`, returns Disabled from Bind/Enter. The policy is an explicit required integration decision, not a set of guessed native stats.

The policy implements synchronous `apply(token, rank) -> boolean` and `remove(token, rank)`. Apply may partially change the character and return false or throw; remove is always attempted once for that owned application. It must remove only KCM-owned modifiers/morph state, preserve progression/items and other temporary layers, and scope ownership to the exact token. A thrown remove calls `ports.fault(token, "MorphRemoveFailed")`, detaches the session and quarantines this owner/life/epoch until a different life or epoch is observed. Reset cannot bypass quarantine. The adapter cannot repair a failed external modifier removal; the integrator must inspect the fault and ensure the old character is discarded or repaired before reuse.

## Minimal ports

All ports and policy functions must be synchronous/non-yielding. Read/publish/effect/mana/Sage/sharing/fault ports must not throw. Only morph apply/remove are exception-protected, because partial modifier application is an explicit transaction boundary. Do not enter Studio or use network callbacks from inside these functions.

- `now() -> finite monotonic seconds`
- `read(ownerId) -> Snapshot?`: authoritative server character/progression state, never client payload.
- `publish(token, chakra, availability)`: reconcile chakra and skill permissions for the exact token's character. Availability is the intersection of domain form restrictions and the current authoritative `Snapshot.allowed`; cooldown readiness still comes from its proper subsystem.
- `effect(token, kind, castId)`: Entered, DashReady, Exited. Each resource/effect must be owned by token and castId; Exited removes only those resources. Capture castId here for cancellation or buff observations.
- `reapplySage(token)`: reapply the current external Sage layer, never reset its timer. The adapter only calls it when current Sage remaining>1 and aura exists, and coalesces repeated reapply requests in a catchup batch.
- `restoreMana(token, amount)`: apply once to authoritative ordinary mana with its normal maximum clamp.
- `revokeSharing(token)`: clear owned external sharing grants idempotently.
- `fault(token, reason)`: surface ClockGap or MorphRemoveFailed for diagnostics/recovery.

`Snapshot` is `{life, epoch, eligible, canCast, context, allowed}`. Life/epoch must identify the actual character life and a monotonically distinct match epoch. Context fields are the domain's `level, rank, hagoromo, alive, fullKurama, kuramaCooldown, sageRemaining, sageAuraPresent`. Allowed contains booleans for `kcm, gamakichi, sage, dash, sharing, fullKurama` computed from learned ranks/unlocks/runtime support/current match rules. `eligible=false` means this session must end (wrong hero, invalid match/phase, despawn); `canCast=false` denies new Enter/Convert while allowing ongoing KCM to drain and be cancelled (e.g. stun).

Every writing port must check token identity before touching an Instance. Cleanup of an old life uses the old token and must never remove modifiers or effects belonging to a replacement character.

## Runtime calls

- `Bind(ownerId) -> token?, reason`: idempotent for an already bound matching life/epoch. Keep the returned frozen token in server-owned records. It is checked by object identity; reconstructing the same fields does not authorize a call. Do not serialize tokens or accept them from a RemoteEvent.
- `Enter(token) -> boolean, reason`: advance time, validate server gates and domain.canEnter, apply the explicit policy, reread/revalidate life/epoch/permissions/rank, then commit the domain cost and effect. Failed application/gating leaves entry cost and entry cooldown unchanged; ordinary elapsed resource ticks still apply. A different valid rank after policy apply also rolls back, preventing the wrong morph from committing.
- `Update(token)`: call from an existing server update loop and at observed authoritative transitions. No timers are owned by the adapter. Resource ticks use the previous recorded context for elapsed time, then current context at the observed transition. To preserve exact transition timing, call at that transition; the adapter cannot reconstruct unobserved history.
- `Cancel(token, castId)` / `BuffRemoved(token, castId)`: mark source-style next-tick cancellation; cleanup follows the final40 drain. Current epoch/life and cast identity are checked before mutation.
- `Convert(token)`: domain conversion plus one ordinary mana port call; server request admission/rate limiting remains with the caller.
- `Remove(token)`: close and clean only that session. Repeated/stale removal does nothing. Dead/missing/ineligible/replaced characters are similarly detached at the next observed adapter call, with immediate no-extra-drain safety cleanup.
- `Reset()`: close all active sessions and discard retained balances at epoch end. It refuses reentrant execution. Quarantined life identities remain blocked.

Call `Update` at the actual death/character/match change; otherwise cleanup occurs when next observed. The adapter owns no death-event subscriptions.

Reentrant calls from a port/policy return Busy. Stale tokens return Stale. Backward/nonfinite time returns Clock without mutation. A gap over60 seconds reports ClockGap and detaches, preserving the last known balance rather than inventing elapsed context; rebinding explicitly begins a new session.

## Resource lifecycle policy

Within the same epoch, Bind after death/Remove/life replacement preserves the last separate chakra and absolute KCM cooldown. This avoids a free600 refill on respawn. Unbound time does not regenerate resource; resource tick phase starts one second after rebinding. This freeze/phase reset is an explicit safety adaptation, not certified native death behavior. A new epoch or Reset starts from the configured600. Domain additions are small and backward compatible: pure `canEnter`, `balance` returning a detached snapshot, and optional `new(now, balance)`.

The adapter currently does not expose sharing grant creation/count updates, full-Kurama transforms/heals, dash casts, or other techniques. It manages KCM lifecycle/permissions/effect requests and chakra conversion. Additional branch integrations must be explicit and tested; no capabilities are enabled in learning by the adapter itself. The concrete gameplay composition is documented in `NarutoKcmGameplay.md`.

## Unresolved morph decisions

No effective transformed stats are supplied. The integrator must choose and document native retention/rounding, alternate-form base vs added modifiers, maximum health/mana handling, preserved current health/mana, transition timing, ownership of visuals and buffs, and coexistence with items/Sage. Raw Config morph fields remain evidence only. Parent integration must independently verify the chosen Roblox policy in Studio; fake ports certify control flow only.

## Validation

Existing Luau0.744 binaries: analyze and compile the three NarutoKcm modules and both specs, then run:

```
luau tests/NarutoKcm.spec.luau
luau tests/NarutoKcmAdapter.spec.luau
```

Results: **64 domain checks, 63 fake-port adapter checks, all PASS**. Coverage includes default-disabled policy, authority gates, delayed cancellation/removal, exactly-once cleanup/effects, permission restoration, owner isolation, death, life/epoch change, retained chakra/CD, stale/forged tokens, reentrancy, partial/throwing policy rollback, cleanup quarantine, rank changes during apply, Sage coexistence/expiry, conversion, invalid clocks, clock-gap cleanup and reset. No Studio/MCP/UI was used and no runtime integration/publication performed.
