# HUD review and integration

Base: d7c513332eddd5a615b4bac3069316301ab7cbe8 (main). Branch: ui/dota-hud.
Scope: only client presentation, original code-drawn icons, pure layout tests. No game mechanics, server, remotes, config, navigation, combat, or published assets changed.

## Sources actually inspected

- Valve's dedicated HUD documentation: https://www.dota2.com/700/hud/?l=english
- Opened and visually inspected both original 944x590 images:
  https://cdn.steamstatic.com/apps/dota2/images/700/hud/carousel_01.jpg
  https://cdn.steamstatic.com/apps/dota2/images/700/hud/carousel_02.jpg
- Later official HUD/stat changes checked in 7.33:
  https://www.dota2.com/newfrontiers?l=english
  https://www.dota2.com/patches/7.33
- Current official updates checked: https://www.dota2.com/news/updates

These are canonical Valve layout reference images from 7.00, not claimed to be screenshots of the current 2026 client. The later notes add barriers and always-visible attack speed/magic resistance. Those parameters are not invented in this project: absent replicated attributes are shown as an em dash, and unsupported Dota-only features are omitted. No Valve image file was added to the game.

Measured approximately from the actual reference image: roster x=243..701 (~48.5% image width), height ~25 (~4.2% image height), starting y=0; lower console x=270..674 (~42.8% width), height ~80 (~13.6% height). This adaptation uses 47.9% width/4.44% height roster at 16:9 and 46.9% width/15.2% height console. The lower console is slightly larger to accommodate five Naruto branches, permanent character stats, and F/G/H, rather than removing controls.

## Layout and data

Reference space 1920x1080, scale=min(viewportHeight/1080, (viewportWidth-32)/900, (viewportWidth-240)/920). Uniform scale, centered anchors, ScreenInsets.None and top y=0. Ultrawide preserves height-derived dimensions rather than stretching. PC-only; there is no mobile rearrangement.

| Viewport | Console | Primary icon | Roster | Top y |
| --- | --- | --- | --- | --- |
| 1280x720 | 600x109.3 | 40x40 | 613.3x32 | 0 |
| 1920x1080 | 900x164 | 60x60 | 920x48 | 0 |
| 2560x1080 | 900x164 | 60x60 | 920x48 | 0 |
| 3440x1440 | 1200x218.7 | 80x80 | 1226.7x64 | 0 |

Main branches remain in Config.Order and use Controller.TryCast; F uses BeginCloneCommand; G/H retain summon spells. Rank, disabled state and LearnReason come from existing replicated state; plus buttons call Learning.TryLearn. Learning/controller notices remain visible. Hover provides full names, ranks, unavailable reasons and cooldown. Sage Preparing/Active reads SageReadyAt/SageExpiresAt. Clone tooltip reads rank I/II/III. Effective Strength/Agility reflect buffs; XP, points, gold, K/D/A, defense, movement and mana regeneration read actual attributes. Portraits still use the existing ViewportFrame renderer. Inventory is the existing ownership projection (Own_<id> in ItemConfig order), not an invented reorderable inventory; consumables without persistent ownership do not appear as owned.

All ability and item artwork consists of original UI primitives, with no image IDs, network calls or asset uploads. Shader-like vertical cooldown shade and numeric seconds are both present.

## Integration

Only AbilityHUDController overlaps the integrator's Sage patch. Resolve by using this new presentation file; it already contains the Sage deadline/phase bindings, clone rank tooltip, and AttackDamageBonus display. HUDLayout/HUDIcons are new modules; SurvivalHUDController changes only layout/insets. No changes to MobaHUDView or HeroHUDController. Existing shop/reward window remains as-is.

## Actual verification

- HUDLayout.spec.luau: 68 assertions PASS, covering 1280x720, 1920x1080, 2560x1080, 3440x1440, 1366x768; stable ratios, centered bounds, no skill overlap, dedicated item area.
- luau-analyze: pure HUDLayout module + layout test PASS.
- luau-lsp 1.70.1 Roblox types with LuauSolverV2 and production sourcemap: all four changed/new HUD modules PASS, no errors. Informational warning about didChangeWatchedFiles registration is existing CLI behavior.
- luau-compile 0.744 --null: all four modules plus test PASS.
- Rojo 7.7.1 production build PASS: build/hud-review.rbxlx.
- git diff --check PASS.

## Required MCP visual/game checks by the sole Studio integrator

No Studio, MCP game control or screenshots were performed by this worker, as instructed. Static checks do not prove Roblox rendering or input behavior.

1. At 1280x720, 1920x1080 and ultrawide, inspect roster y=0, all ten portraits, centered score/clock, and Roblox core top-left controls clearance. Confirm names and death shade remain legible.
2. Inspect primary/auxiliary icon readability, tooltip wrapping, plus button position, item-name labels, 3x2 inventory, portrait, character stats and no overlap with any existing minimap or reward toast.
3. Exercise keys 1..5/Q/F/G/H, mouse icons, Ctrl+1..5 and plus learning. Verify locked KCM stays disabled, rank dots refresh, and notices update.
4. Verify cooldown numbers/shade during casts, insufficient mana, clone ranks II/III, Sage preparing/active/expiry/death/respawn, XP level transitions, health/mana and item purchases. Damage mechanics are the separate worker's responsibility.
5. Runtime/tooltips: confirm custom Unicode symbols render in Gotham; if not, replace only ornamental symbols. Confirm the full integrated physical attack stats are replicated before adding any new stat fields.
