# Ability families — 2026-11-05

The six roots Q/E/R/F/C/T replace the Tab catalog and Shift pages. The first key opens a compact non-modal strip; its fixed choices show a second key, availability and cooldown. Q also immediately starts base Rasengan. Reopening Q while held does not recast it. Q → Z and Q → X are sequential inputs; the existing latency-safe upgrade queue is retained. Roots and choices are mouse-clickable using Alt. Every action has a scrollable tooltip with controls, resource cost, description and current rejection reason. I opens character stats; Ctrl+1–5 learns the original five lines.

| Root | Choices |
| --- | --- |
| Q | Z Odama, X Rasenshuriken; ready LMB applies the held technique |
| E | E summon clones, X attack target, V follow, B hold |
| R | R Gamakichi, Z oil, X adult chopping |
| F | F aimed KCM dash, Z Rikudo HY, X Rikudo HZ |
| C | C Sage, Z learned KCM rank, X full Kurama, V exit KCM |
| T | T explicit meditation preparation, Z recall meditation clones, X Kurama chakra conversion |

Opening a family cancels an older target selection but does not spend resources, release the camera or stop WASD. The current family's choices take precedence over roots. RMB, death, round/life/form changes close selection. Out-of-family X never cancels KCM. Only one family is open; unavailable choices retain their positions and explain their requirements. A selected ground/enemy action enters the existing target validation flow and consumes its confirmation click. Mode timers, layering rules, learning gates and cooldowns are unchanged.

MeditationCast is an explicit alias of Sage preparation with meditation=true. It shares Sage learning/cooldown and does not change a persistent button mode. Ordinary clone casting retains the map's mana-dependent mass IV branch. No redundant point-cast alias is exposed. Per the user's canon preference, ShadowSleep is removed from the family and Naruto allowlist; direct requests and the old enemy-target ShadowClones route are rejected. Archived map domain rules remain for source documentation and shared status-system tests.

## Prepared first contact

The prior spell contact hook had a 5.125-stud centre-distance gate for ordinary roots, shorter than the ordinary melee hitbox. A target at 5.8 studs could therefore receive an ordinary strike while the orb remained held. The spell now consumes the combat system's already validated contact (hitbox, hostility, walls and ForceFields) without a second shorter gate. All three melee variants use this path. Their source damage formulas and delayed impact remain intact; misses preserve the charge and structures remain ineligible for the spell.

Client prediction and server admission both suppress ordinary attacks during formation and while the consumed spell awaits impact. Holding LMB starts the strike when ready. Sage Rasenshuriken retains aimed LMB throwing.

## Validation

- Full repository check: Luau compilation, domain suites, Roblox-aware source and fixture type checks.
- AbilityFamilies tests cover roots, choice priority, no legacy direct casts, movement isolation, descriptions and server allowlists; sleep removal is asserted.
- Rasengan domain checks cover preparation/ready/consumed/expired attack-guard boundaries.
- `tests/ability-families/FirstContact.server.luau`, disposable Studio Play: all three variants at 5.8 studs reject preparation attacks, consume on first contact, emit no preceding ordinary damage and deliver the expected spell formula. Miss/retry retains then consumes the charge. Test targets follow facing to avoid the player camera rotating away during preparation.
- Actual keyboard: E leaves movement/camera captured and summons nothing; E → E summons 30 at rank IV/full mana; E → B holds, E → V follows, zero M1 attacks from navigation. Q → X produces held Rasenshuriken directly. I opens stats; Tab opens no catalog. Mode tooltip shows Hagoromo requirement and current key sequences. T → T creates meditation clones without changing the persistent meditation toggle; T → Z recalls them. Subsequent C → C uses ordinary Sage preparation. In active Rikudo, X leaves the mode active and C → V exits. Sage Q → X followed by a real mouse click throws the projectile, consumes the orb and generates zero M1 attacks.

This is a local Studio validation, not a multiplayer soak test. Runtime fixtures and observers are not included in the release places. Direct sleep and targeted-clone bypass requests were rejected in Studio; clicking Gamakichi summoned it without M1, and a real RMB closed the family.
