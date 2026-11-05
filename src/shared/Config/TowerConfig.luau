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
			Top = { { -34, 4, -99 }, { -76, 4, -99 }, { -126, 4, -57 } },
			Mid = { { -34, 4, 15 }, { -76, 4, 15 }, { -116, 4, 15 } },
			Bottom = { { -34, 4, 99 }, { -76, 4, 99 }, { -126, 4, 57 } },
		},
		Red = {
			Top = { { 34, 4, -99 }, { 76, 4, -99 }, { 126, 4, -57 } },
			Mid = { { 34, 4, 15 }, { 76, 4, 15 }, { 116, 4, 15 } },
			Bottom = { { 34, 4, 99 }, { 76, 4, 99 }, { 126, 4, 57 } },
		},
	},
	Visual = { ProjectileDuration = 0.16, RuinFlashLifetime = 0.65, MaxEffects = 24, ViewDistance = 220 },
}
