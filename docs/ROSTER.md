# Classic 5v5 roster and lobby

Base: `2f1d4310d16b9633d6f36724ff07034521d82904`. This slice preserves the existing round reset and combat systems.

## Rules

- Production starts only when both teams have five connected, assigned players. Spectators do not count. An assigned departure during preparation cancels the countdown; a replacement starts a fresh countdown.
- `TeamCapacity = 5` is enforced by the pure `MatchRoster` aggregate. Blue/Red internal IDs remain compatible with map paths; the HUD displays Альянс шиноби / Акацуки and connected counts.
- Before combat, a departure releases its slot. Waiting players are admitted deterministically by UserId when capacity opens.
- At combat start, membership is locked. Disconnected slots are reserved until the round ends; only the original member can reconnect. New arrivals wait for the next round, even if a team is currently short-handed. No in-match team switching/replacement.
- Waiting players have no spawned combat character and cannot deal damage, gain rewards or buy items. This is a waiting state, not a full spectator camera implementation.
- Reset creates a fresh roster, preserves the existing round-epoch guards, and assigns connected players deterministically. Overflow keeps waiting. Queue fairness beyond UserId ordering is deferred.
- `StudioMinimumPerTeam = 1` explicitly permits existing 1v1 regression scenes in Studio only. Set it to `5` for full-team validation. `DebugSoloMode` remains Studio-only. Neither setting reduces production readiness.

## Architecture

`shared/Game/MatchRoster` owns membership, capacity, reservations and readiness without Roblox dependencies. `TeamService` adapts Player lifecycle, spawning and attributes. `GameModeService` selects runtime configuration. `MatchService` coordinates readiness and locks membership; `MatchState` keeps phase/timing rules. Damage and economy check authoritative membership rather than trusting the presentation TeamId alone.

## Verification

Cloud Luau 0.744 compilation and pure tests are recorded in the delivery report. New Roblox runtime/UI behavior has not yet been verified in Studio; do not treat the previous round evidence as validation of this patch.

Required Studio matrix:
1. Two-player override starts, existing round/combat regressions pass across three rounds.
2. With override 5, 4v5 waits; 5v5 prepares and starts; departure during preparation cancels; a waiting replacement gets a fresh countdown.
3. Eleven connections never produce more than five members on either team. Overflow has no combat character and shop/damage attempts fail.
4. Locked-round departure plus new arrival preserves reserved slot; original member reconnects only to original team. Late joins cannot escape an eliminated team.
5. Reset with overflow and delayed character loading never exceeds capacity or retains a previous-round character.
6. HUD team names, counts, waiting/results state are readable on desktop and phone sizes. A waiting observer never sees a false defeat.

Deferred: hero selection/new abilities, matchmaking, ranked progression, full spectator camera, Naruto jungle, vertical/branch movement.
