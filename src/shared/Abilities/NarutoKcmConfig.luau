--!strict
-- Verified object/script facts; not final native morph stats or Warcraft parity.
local C = {
 InitialChakra = 600, EntryCost = 200, DrainPerSecond = 40, IdleRegenPerSecond = 20,
 MaxAdvance = 60, -- Reject larger gaps atomically; caller must replay bounded intervals with historical context.
 Cooldown = 10, DashDelay = 0.5, ResourcePeriod = 1,
 MinimumLevels = {13,20,27}, MorphRawcodes = {"N01H","N00E","Ewrd"},
 ConversionLevel = 16, ConversionCost = 200, ConversionMana = 200,
 SharingCostPerUnit = 4,
 Policy = {
  TickOrder = "resource-before-kcm-drain", -- Independent source timers: ordering not certified.
  DeathCleanup = "immediate-no-extra-charge", -- Safety adaptation; manual cancel retains next charge.
  MorphStats = "runtime-policy-required-preserve-progression-and-upgrades",
  Sage = "external-layer-reapply-only-when-remaining-over-one-and-aura-present",
  FullKurama = "external-state-only-no-transform-or-passive-heal-implementation",
 },
 -- Raw transformed-unit fields are evidence, never additive buffs or effective totals.
 RawMorphProfiles = {
  {armor=5,attackBase=35,attackCooldown=1.8,speed=320,manaBase=700,range=0},
  {armor=10,attackBase=60,attackCooldown=1.8,speed=370,manaBase=700,range=0},
  {armor=15,attackBase=110,attackCooldown=1.8,speed=370,manaBase=2300,range=80},
 },
}
for _, value in C.RawMorphProfiles do table.freeze(value) end
table.freeze(C.RawMorphProfiles)
table.freeze(C.MinimumLevels); table.freeze(C.MorphRawcodes); table.freeze(C.Policy)
return table.freeze(C)
