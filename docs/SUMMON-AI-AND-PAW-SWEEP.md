# Gamakichi autonomy and Kurama swept melee — 2026-11-05

## Gamakichi

The server chooses a nearby visible hostile target without an owner attack. It respects existing group commands: Hold cancels pending strikes/channels and stops autonomous casts; Follow clears the current fight, returns to the owner and gives a two-second recall grace. Command/assist targets have priority when valid and within the owner leash. Acquisition, pursuit and leash distances share the existing companion policy (28/40/48 studs). ForceFields, hostility, line of sight, death and expiry are checked. The toad uses oil on an enemy without an active oil debuff, approaches and uses the adult chopping channel in range, then attacks normally during spell cooldowns. Existing source damage, ranges, cooldowns, lifespan and rank gates are unchanged.

Autonomous requests use the spell state's internal serial. Manual request replay protection has its own counter, so AI cannot make a later genuine player command look stale. Existing R → Z / X manual spells remain available, subject to their shared cooldowns.

Spawn searches nearby collision-free grounded locations instead of clamping the spawn into an obstacle. Navigation respects collidable terrain and ignores noncolliding visual foliage. Explicit gravity runs before Hold/control checks, so anchored toads settle after airborne summons. Humanoid HipHeight is zero and the cosmetic feet align to the navigation clearance plane. No blanket wall collision disabling or teleport-to-target was added.

The free Appendance Gamakichi model supplies the toad mesh and texture. It has no rigged animation set; locally authored breathing, hopping, attack lunge, oil recoil and sword-channel motion provide the animation. The imported scripts of rejected alternatives are never used. See CREATOR-ASSETS.md for attribution and limitations.

## Kurama

Ordinary Naruto M1 remains single-target. Full Kurama evaluates an active sweep from phase .32 to (.8/1.7)+.08 using the exact shared Avatar.Motion transforms and mesh dimensions of the attacking hand/lower arm. Left/right side follows attack serial. The server samples the swept boxes between heartbeats, collects all eligible contacted hurtboxes and keeps a per-attack victim set; there is no arbitrary victim count cap and no repeat damage to one victim during the same swing. Weapons/cosmetics do not extend victim hurtboxes. A teleport cannot leave a damaging trail across the map.

World walls, allies, ForceFields, life/round/profile changes and control cancellation are respected. Damage uses the existing ordinary M1 formula plus the form stat layer exactly once. The independent source shockwave proc retains its own rules. Claw trails use the same active phase interval. This is an explicit requested gameplay adaptation beyond the source map's single-target attack.

## Checks

Full compile/domain/Roblox-aware checks passed. The Studio single-player regression is `tests/summon-ai/Runner.server.luau`. It exercises a blocked spawn on grass, follow movement, airborne settling in Hold, autonomous oil and chopping, Hold interrupting the channel, independent manual replay IDs, basic attacks between spells, and the large paw sweep. A 28-target formation produced eight distinct paw victims in one swing, each exactly once; behind/far/ally/shield targets were excluded and a solid wall blocked the sweep. The original fixture's KCM exit waits for its actual domain tick before entering Kurama.

The final playable session is restarted without regression scripts, dummy targets, or the test floor. Builds do not contain marketplace review copies or test overrides. Asset visibility is verified in local Studio, not a published-universe permission test.
