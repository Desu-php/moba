--!strict
-- Positions relative to MapConfig.Origin; decorative plinths sit outside lane centerlines.
local priority: { [string]: number } = { Minion = 1, Hero = 2, Summon = 3 }
return {
	Health = 600, Range = 28, Damage = 18, AttackInterval = 1.2, Windup = 0.3,
	UpdateInterval = 0.1, AggroDuration = 3, TeamGold = 50,
	TargetPriority = priority,
	AllowSummons = true, -- Source clones are damageable illusions; DamageService excludes legacy cosmetics.
	-- Ordered from the river/front line toward the defending team's base.
	Tiers = {
		{ Name = "Внешняя", Mark = "I", HealthMultiplier = 1, DamageMultiplier = 1, IntervalMultiplier = 1, Height = 0 },
		{ Name = "Внутренняя", Mark = "II", HealthMultiplier = 1.75, DamageMultiplier = 1.5, IntervalMultiplier = 1.1/1.2, Height = 2 },
		{ Name = "Базовая", Mark = "III", HealthMultiplier = 2.75, DamageMultiplier = 2, IntervalMultiplier = 1/1.2, Height = 4 },
	},
	Positions = {
		Blue = {
			Top = { { -102, 4, -214 }, { -218, 4, -230 }, { -292, 4, -150 } },
			Mid = { { -124, 4, 47 }, { -229, 4, 29 }, { -303, 4, 17 } },
			Bottom = { { -102, 4, 214 }, { -218, 4, 230 }, { -292, 4, 150 } },
		},
		Red = {
			Top = { { 102, 4, -214 }, { 218, 4, -230 }, { 292, 4, -150 } },
			Mid = { { 124, 4, -47 }, { 229, 4, -29 }, { 303, 4, -17 } },
			Bottom = { { 102, 4, 214 }, { 218, 4, 230 }, { 292, 4, 150 } },
		},
	},
	Visual = { ProjectileDuration = 0.16, RuinFlashLifetime = 0.65, MaxEffects = 24, ViewDistance = 220 },
}
