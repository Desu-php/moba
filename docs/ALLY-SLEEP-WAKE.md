# Allied Sleep wake, 2026-11-03

Naruto's A0IC derives native AUsl. The saved map supplement confirms the3s Sleep
and wake boundary; Blizzard's primary description explicitly allows waking one's
sleeping unit by attacking it:
https://classic.battle.net/war3/undead/units/dreadlord.shtml (Sleep Counters).
Native immunity/zero-damage/DOT edge cases remain separate from this bounded path.

## Player behavior

Aim an ordinary melee attack at a nearby sleeping ally. The server chooses the
nearest admitted target inside the unchanged melee volume, direction and LOS.
One committed swing wakes that ally at attack-start and pays the normal attack
cooldown. It causes no friendly HP damage or reward credit. It cannot hit an enemy
later in the same swing. Holding M1 can make the next ordinary attack normally;
awake allies are not attack targets.

This is an explicit MOBA control adaptation of the native allied wake mechanic.
The wake interaction emits no offensive AttackStarted event, so it neither
consumes a held Rasengan nor starts Kurama/offensive procs. Other rigid stun is
preserved. Client protocol remains requestId/currentCharacter/roundId only: no
client target, damage, wake flag or extra friendly-fire capability is accepted.

The optional hitbox admission predicate is server-owned and only used at player
attack-start. Existing NPC/summon/default hitbox callers remain enemy-only.
Expired Sleep, self, neutral units, structures, ForceField, dead/old-epoch actors
and terminal matches cannot enter this path. DamageService.CanDamage is unchanged.

## Verification

NarutoAdvanced pure suite51 PASS, targeted Roblox types PASS. Focused engine
fixture31 PASS in3.1118s, using official MCP ExecutePlayModeAsync and a real
engine-created player inside the separately opened hidden sleep-wake-tests.rbxlx.
No mouse/keyboard injection, screenshot, external game-client window or user
scene interaction was required. It exercises the actual Combat.HandleRequest,
hitbox and Sleep services, including missing/stale epoch and injected-target
rejection, overlapping stun, no damage/proc/retarget and the next enemy attack.
The generic offensive event is observed by Model identity: BindableEvent copies
table arguments, so Fighter-table reference equality is not a valid assertion.

An initial RunMode fixture attempted manual Player creation and was rejected by
the engine's WritePlayer capability. That action was not retried or unlocked;
the fixture now waits for the normal PlayMode player. Other preliminary failures
were an omitted fixture epoch and the event observer's table identity comparison.
Production guards and assertions were preserved.

Build: `rojo build tests/sleep-wake.project.json -o build/sleep-wake-tests.rbxlx`.
Then, in that owned QA editor, use StudioTestService.ExecutePlayModeAsync and
require the returned `{ok=true,count=31}`. The fixture has a30s failure timeout
and ends its own test with EndTest; it is not mapped into production.
The full check script builds/types this fixture. Historical unrelated Studio
results remain REUSED; this server-focused test is not a new visual/input claim.
Fresh aggregate after the final source changes: Full PASS36.81s,196Luau files,
23builds, pure rules and Roblox-aware production/fixture types. The independent
read-only review found no remaining blocker. The user main and user windows were
untouched during development; only the owned QA was used and returned to Edit.
