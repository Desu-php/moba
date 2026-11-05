# Sasuke fire mechanics — 2026-11-06

Reference: extracted Naruto Legend 1.7A FIX20.3, `war3map.j` Katon actions at 110062/110555, Phoenix contact at 23185, Amaterasu at 107912, Enton at 107669.

- Targeted domain tests and Roblox-aware source type checks pass; output in `build/sasuke-fire-mechanics-check.log`. Existing unrelated lint warnings remain.
- `tests/sasuke-fire-runtime.luau`: **38 engine assertions passed** in Studio using an isolated clone of the production fire module. Covers one initial hit plus 3 s sustained damage, exactly 75 extra mana, allied/structure exclusion, movement/stun/low-mana cancellation, 20-shot cadence/spread, attached burn without stacking, extinguish, 4 s control limit, coating immunity and 8 magatama.
- Live Play in private test place **122335415000300**: Sasuke rank 5 / AGI 56; Gokakyu dealt approximately **639.105** damage (expected nominal 639; Humanoid floating-point accumulation), terminated, and emitted no ground patch. Net mana loss about 154.43 includes ordinary regeneration; gross channel cost is tested separately.
- Live Phoenix: no projectile in first 0.1 s, exactly **20** Projectile events after 4 s.
- Live Amaterasu: cast/steer/extinguish accepted, steering spent no extra mana and preserved the original cooldown, damage continued after target left the patch, then stopped after extinguish.
- First live extinguish attempt was correctly rejected as out of range; retested with the target inside legal range and all above checks passed.
- Visually inspected live Phoenix and the sustained widening fire breath with R15 cast pose. Added an axial particle stream after inspection to join the mouth to the larger flame volume. Re-ran targeted checks and rebuilt both release places afterward.
- No new runtime script errors in the live test. Existing asset-type warning for 203785492 and minion navigation recovery messages remain. One tool-only diagnostic used an isolated module cache and saw a nil match; gameplay checks were run through a temporary normal server Script instead.
- Original Studio sources backed up in `sasuke-fire-studio-backup-2026-11-06.json`; applied edits with concurrent-change guards and Studio undo waypoints. Temporary test objects did not remain in Edit mode.

Intentional adaptations: third-person aiming and movement cancellation; retain tooltip AGI scaling rather than the original `R2I(.2)` bug; fractional damage ticks; Amaterasu steering via repeated F → F; separate F → H magatama action. Full Warcraft animation/choreography and every contextual Enton branch are not certified as identical.
