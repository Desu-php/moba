--!strict
-- MOBA adaptation requested by the player. Keep Warcraft source records unchanged.
local Attributes = {
 HealthPerStrength = 22,
 AttackSpeedPerAgility = .01, -- +1 attack speed on a base of 100.
 MaximumAttackSpeedMultiplier = 7,
 Mana = table.freeze({ ManaPerIntelligence = 12, RegenPerIntelligence = .05, BaseManaRegen = .01 }),
}
return table.freeze(Attributes)
