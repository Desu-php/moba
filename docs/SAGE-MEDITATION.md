# Sage III and meditation

Source: `source/naruto-progression-and-branches-contract.txt`, A09J and Meditation Mode; exact map SHA256 `8c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8`. This implementation does not import Warcraft assets or claim native-engine parity.

Sage ranks I/II/III learn at 6/10/14, consume one point each, prepare 10/7/4 seconds, spend 25 ordinary mana and start a 150 second cooldown. Direct mode restores 200/350/500 once at activation. Attack bonuses 10/30/50 and movement 105 Warcraft units use the existing stat layer. Rank III armor 15 is explicit source data. Existing 51 second modifier cleanup and 47 second aura policies are retained. Capacity never heals current HP.

Rank III HP uses an explicit **provisional 300 capacity policy** from the tooltip. The source's A07Y/AIl2 inheritance can resolve to 150 or 300 depending on native original-object override handling, which is not certified. `SageState.Policy.Rank3HealthProvisional` and character `SageHealthProvisional` expose this distinction. Ranks I/II inherited armor remains the existing provisional 3/7 policy.

Press Right Arrow to select meditation before casting 4; press Right Arrow again for direct mode. The mode is captured per cast. Meditation creates clones 0.1 seconds into preparation, gives the usual Sage layer at preparation end, and skips direct mana restoration. J recalls all owned meditation clones, returning their current mana. No extra learned line or large HUD change: mode and keys appear in the existing ability message. Requires learned Sage and normal server admission, owner, life and match validation. The mode persists through death, resets with the match.

Ordinary: one clone, or two total at rank III and hero level >=18. KCM: one, or two total at rank III and level >18. Kurama: two. Never three. Ordinary/KCM clones have HP1, maximum mana500, regeneration20/sec; Kurama clones HP1, maximum2000, regeneration100/sec. All are immobile, have no attack AI and expire at35 seconds. The native omitted ordinary/KCM initial mana is unknown: this implementation explicitly selects **zero initial mana**. Kurama initial zero is explicit source data. Clones use their owner's appearance with inherited combat/VFX state removed and a procedural seated breathing pose; no downloaded assets.

Death, expiration and recall atomically settle CURRENT mana once, cap credit at the correct owner's current ordinary capacity, then remove the entity and fighter record. Owner death, departure, changed character, changed life, changed epoch and terminal match cleanup invalidate without transfer. Removal never credits a new respawn or another Naruto. Native global owner bugs are intentionally not reproduced. A late update after preparation skips stale clone creation instead of granting delayed clones. These are safety adaptations.

J is a product control for group recall, not a claim that source A0I5 targets all clones. Native A0I5 has CD5 and unknown inherited cost. Group recall explicitly uses a 5-second owner cooldown and provisional zero cost; death/expiration has no recall gate. This avoids treating unknown inherited cost as a verified source value.

## KCM integration seam

After initializing authoritative KCM state, register once:

```luau
Naruto.ConfigureMeditationForms(function(player)
    -- Read server-owned form only. Valid results: Ordinary, KCM, Kurama.
    return KcmService.MeditationForm(player)
end)
```

Default is Ordinary. Called synchronously at clone spawn; no yield or client attributes as authority. Existing clones retain their creation profile across morphs. Provider must return Ordinary after form exit, death/reset or missing session. Sage is an independent `NarutoSage` stat layer; KCM must preserve it through entry/exit and preserve progression and ordinary resource identity. Do not call `Naruto.Reset` on morph. KCM owns its admission/disable policy, not this callback. `Naruto.Get(player).sage.active` exposes phase/rank/remaining time if needed. Full Kurama three-headed consumption is not implemented here: its worker should use an explicit validated pair transaction rather than assuming stored clone handles are alive.

## Focused validation and Studio handoff

Run `scripts/check-sage-meditation.ps1` with existing official CLI directories. It type-checks affected modules and fixtures, runs Sage (40), Meditation (32) and SkillLearning (25) assertions, compiles the changed modules and builds production plus the dedicated fixture. It does not launch Studio.

Integrator only: open `build/meditation-tests.rbxlx`, start Server & Clients with two clients, and require `[MeditationTests] ALL PASS` with no FAILED output. The fixture uses actual remote admission, real 4-second preparation, enemy Damage.Apply, owned mana pools and real death cleanup. It shortens only selected fixture cast expiry/cooldown and clone expiry to avoid 150-second idle waits; pure tests cover exact35/51 and cooldown boundaries. KCM level18 selection is an injected form callback, not a test of KCM implementation. It additionally checks direct III restore500, mode capture, no meditation instant refill, recall, owner death and terminal cleanup. Existing `tests/sage.project.json` remains the I/II regression fixture if shared Sage behavior changes.

Manual MCP checks: observe both clients' seated clones and breathing; ordinary level18 rankIII shows two; server KCM callback at18 shows one,19 shows two; inspect HP1/current mana on each. Kill a clone before500 mana and confirm only its owner gains that current amount. Let another expire naturally35sec. Toggle mode and verify message/Right Arrow/J work with chat unfocused. Confirm J cannot be forged for another owner, old character/round requests fail, and no clone remains after respawn/terminal match. Visual posture, real engine death ordering and native unknowns are **not certified by CLI checks**. This worker has not opened Studio, pushed or published.
