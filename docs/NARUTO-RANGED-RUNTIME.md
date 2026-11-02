# Rikudo HY/HZ runtime slice

Base5516668ff1411bcdcfdb44561d0719d4490ce4c8 plus the domain/source content from
20e965bf02dd4f7d4f11065477db82751c2e1310. This patch enables only confirmed HY/HZ
point techniques. Source appendices are in docs/source; no Warcraft scripts/assets
are executed/imported. No Studio or Roblox publication was performed by this worker.

## Player behavior

Active KCM rankIII with the actual Hagoromo grant exposes a temporary **Rikudo**
panel above the existing HUD: **V** Chō Bijūdama Rasenshuriken(A0HY), **B** Chō
Bijū Rasenshuriken(A0HZ). Each costs1800 ordinary mana and has its own60sec cooldown.
Use the key/button, then click a ground point; Escape/right-click cancels selection.
Selection consumes its click before M1. The five learned lines/order are unchanged.
Existing5/E/X/Left/Right/J/T/Z/Q/F/G/H/C bindings retain their behavior.

Preparation controls the caster1.5sec, releases at1.3. Seven/nine procedural chakra
visuals fly toward the chosen point. They represent **one** damage query per pulse.
The server drives current-STR damage, expanding radii and signed movement from
NarutoRangedState. Clients render those states; they never supply targets, hits,
strength, ranks, grants, costs, pulse counts or movement vectors.

## Authoritative grants and lifecycle

`NarutoKcmAdapter.ActiveCast` reads the private admitted morph rank and cast ID.
Learning rankIII while an older rankII morph is active does not upgrade that morph.
`NarutoKcmService.RikudoGrant` refreshes the actual KCM state, verifies current token
ownership/life/round, admitted rankIII, learned rankIII, level27+, actual Hagoromo,
and returns a short-lived server snapshot. Replicated KcmActive/KcmRank/Hagoromo
attributes are display data and cannot authorize this cast.

Admission rechecks round, live character/participant/hero through the existing
network boundary and KCM provider; caster idle/not asleep/not anchored, M1 cooldown,
other Naruto preparation/held-Q/burst locks, finite point,125stud3D range and grounded
landing. Raw2000WC uses WorldUnits1/16. The mana debit and state transition commit
without yielding. Current character/epoch/request identity and existing remote
rate limits apply. Failed validation cannot spend1800 or create a cooldown.

Each cast owns coordinates, radius, counters, visuals and its KCM activation ID.
Death, character replacement, disconnect, round reset, form exit or a new KCM
activation cancel pending effects. Already paid cooldowns survive death/cancel and
reset with the round. Temporary panel visibility follows the actual grant. VFX keys
include owner/round/life/KCM-cast/ranged-cast identity; cancellation removes them.

## Explicit adaptations and boundaries

* **HY policy requested for this implementation:** missing, unpopulated source groups
 216/221/220/219/217/218 introduce **no exclusions**. The world adapter passes an
 explicit false membership result. This is a documented safe adaptation, **not
 native-certified IsUnitInGroup(null) behavior**. There are no invented overlap groups.
* HY integer floor((1050+4currentSTR)/58),58pulses, first radius640/final868; HZ real
 (900+4currentSTR)/7, seven damage pulses at source ticks,116expansion ticks, radius1100
 at completion. HZ additionally applies the signed450 motion sequence under the
 nonally filter, separately from enemy-only damage. No extra damage on those moves.
* World queries are planar and re-evaluated each pulse. Existing DamageService
 controls mitigation/protection/enemy admission; this is not universal true damage.
 Dead/despawned units are safely skipped. Structures are excluded. The existing
 game's neutral/enemy mapping remains in force.
* Movement uses source signed step distances, horizontal CFrame displacement,
 positive-step center clamp and wall Blockcast. Anchored roots are not moved. These
 are Roblox safety/pathing adaptations; exact Warcraft placement is not certified.
 Temporary server network ownership is restored within.4sec after the last motion,
 or on reset; an overlapping rigid-stun ownership record restores itself.
* Ground admission raycasts from12stud above the selected point,36stud down, excluding
 registered fighters. Projectiles do not gain enemy collision sweeping, homing or
 new wall-hit detonation. Landing is a chosen terrain point; no unit target accepted.
* The domain uses a per-cast .03 timer phase and pulse-time current effective STR.
 Frame catch-up queries the current world/stat context at processing time. Updating
 historical world membership across a stall is not claimed. No invented total damage
 is advertised for a victim entering/leaving the growing area.
* Procedural shapes, preparation poses, HZ nine-visual formation and colors are
 original Roblox presentation. Source7/9 counts, release/arrival and radius evolution
 are retained; no native model/animation/art fidelity is claimed. At most12 nearby
 effects are rendered,260stud creation range, with10sec fallback cleanup. HY visual
 pulse notifications are coalesced; server damage pulses are not dropped.
* Destructible-clearing commands do not destroy ordinary landscape decorations;
 no explicit map destructible adapter exists. No final cripple is added: the audited
 n00A has no evidenced executable cripple spell. No silent self-damage is inherited.

HO/HQ/A057 unknown inherited costs and IA unresolved history-dependent self-damage
remain closed. HU/HV source appendices are preserved for a separate slice. A0HW's
game-instance policy remains domain-only; no blink is enabled by this patch.

## Focused verification and integrator MCP fixture

Run `tests/run-ranged-runtime.ps1`. It runs ranged321, input-binding, KCM adapter,
KCM gameplay/domain and HUD layout checks; checks changed types; builds only the
focused place and production sourcemap. No full gate or Studio execution is implied.
The log is tests/results/ranged-runtime-headless-2026-11-02.log.

Integrator: open build/ranged-runtime-tests.rbxlx, Server & Clients,2 clients.
Expect `[RangedRuntimeTests] ALL PASS ...` only after observing it in Studio.
This worker **has not run the fixture**. The fixture shortens only the Hagoromo360s
deadline by wrapping the gameplay function locally; the real alive1sec grant sequence
remains, the wrapper is restored, and no production test hook was added. It also
advances owned ranged cooldowns solely to test cancellation without a60sec wait.

The fixture exercises forged-attribute rejection, actual private KCM3/Hagoromo grant,
low-mana/range/replay denial,1800debits, simultaneous HY/HZ,58/7damage callbacks to
one overlapping target,70separate HZ movement events, a movable neutral, pulse-time
STR changes, two-client VFX/panel creation and cleanup, KCM cancel/death/reset.
Client test messages exist only in this place. Production maps no QA driver/remotes.

Manual review still required: V/B aim and Esc/right-click; HUD overlap/readability at
1280x720 and1920x1080; seven/nine shapes and one clear damage-zone edge; camera angles;
wall-safe motion with players/minions/toads, overlapping stun/ownership restoration;
late entrants/leavers; form depletion mid-flight; respawn/disconnect/round reset;
5v5 minion-wave load and nearby simultaneous effects. Native parity/performance and
visual readiness remain unverified until those checks are observed.
