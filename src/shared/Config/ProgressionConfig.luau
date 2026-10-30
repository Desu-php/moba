--!strict
local Naruto = require("../Abilities/NarutoDefinitions")
return table.freeze({
 Attributes = Naruto.Hero, NativeMana = Naruto.NativeInference, DamagePerStrength = 0.02, ArmorPerAgility = 0.2,
 StartingLevel = 1, MaxLevel = 30, StartingGold = 100,
 XPBase = 100, XPPerLevel = 50, MaxGrant = 1000000, MaxGold = 1000000,
 BaseStats = { WalkSpeed = 16, AttackDamageMultiplier = 1, Defense = 0 },
 LevelHeal = 10,
 DefenseScale = 100, XPRange = 70, AttributionWindow = 10,
 PassiveGold = 5, PassiveInterval = 10,
 MinionRewards = { Melee = { XP = 30, Gold = 20 }, Ranged = { XP = 40, Gold = 25 }, Jungle = { XP = 50, Gold = 35 } },
 HeroReward = { XP = 150, Gold = 100 }, AssistReward = { XP = 50, Gold = 25 },
 ShopDistance = 14, ShopPromptDistance = 10, ShopOffset = { X = 0, Y = 1, Z = 10 },
 ShopBurst = 4, ShopRequestsPerSecond = 2, MaxRequestId = 2147483647,
})
