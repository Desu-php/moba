# Ability catalog and quick sets — 2026-11-05

The primary HUD previously rendered only `AbilityConfig.Order`, which omitted KuramaForm even though 6 invoked it. Other auxiliary actions had no discoverable button; the Rikudo pair lived in a separate transient panel.

The HUD now keeps six permanent buttons: Rasengan, clones, Gamakichi, Sage, KCM/Rikudo and full Kurama. The five learning lines are unchanged; full Kurama remains a level-21 auxiliary unlock. Its icon is visible while locked, displays its 2500 separate-chakra cost and shows the active timer. KCM rank III is labelled Rikudo; the catalog explains the Hagoromo requirement.

Tab or the Techniques button opens a catalog of all 20 implemented actions. Three groups (attacks, modes, support) each contain stable pages of six entries. Conditions and cooldowns never remove/reorder entries. Hover/click selects a description, including the unavailability reason; Apply closes the catalog and uses the existing ability controller. Long descriptions scroll. Unsupported source branches are not advertised as working actions.

The selected group/page stays on a compact quick row above the main HUD. Shift+1–6 invokes that row, including when the catalog is closed. PgUp/PgDn changes page inside the catalog; Shift+PgUp/PgDn changes it during play. Group tabs are clickable using the existing Alt cursor release. Preferences persist for the current client session, not across reconnects. Capacity grows by adding catalog entries/pages instead of increasing the primary row.

Existing Q → Z/X, 1–6, E, F/G/H, V/B, T, arrows and J remain. Ctrl+1–5 still learns the five primary lines. An early Alt+1–6 prototype was rejected after Studio intercepted Alt+1 Begin events; final bindings use Shift. Opening the catalog releases the camera, stops held M1/movement, and cancels target selection. Catalog clicks cannot become world attacks; Apply re-enters normal targeting when required. Tab/close button returns to gameplay; Escape also invokes Roblox's own menu. Text focus and other menus block the quick shortcuts. Server admission and damage logic are unchanged.

Validation:

- `AbilityDeck.spec.luau`: 148 checks, including every implemented action discoverable exactly once, page boundaries, no phantom slots, six primary entries, description coverage and modifier/text/menu/control isolation.
- Full repository compilation, pure tests, Roblox-aware type analysis and place builds passed.
- Studio: low-level Kurama card visibly states level 21; main 6 icon is present. Pages 1/2 and support/mode tabs work; empty page slots stay hidden. Reviewed the catalog and quick row in the live client.
- Actual keyboard Q → Shift+1 emitted exactly Rasengan then Odama requests (serials 1,2), with server variant Odama and zero M1 attacks. Support Shift+4 emitted only MeditationToggle (serial 3), with Sage inactive and zero M1 attacks. Navigation/menu interaction generated no additional ability requests. Final source contains no observers or test overrides.

The reusable paging data lives in `src/shared/Abilities/AbilityDeck.luau`; presentation and bindings live in `AbilityDeckController`. This release defines Naruto's catalog; other heroes need their own supported ability definitions/catalog entries. No additional combat techniques or modes were invented.
