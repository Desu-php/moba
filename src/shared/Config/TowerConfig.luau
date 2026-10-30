--!strict
-- Positions relative to MapConfig.Origin; decorative plinths sit outside lane centerlines.
local priority: { [string]: number } = { Minion = 1, Hero = 2, Summon = 3 }
return {
	Health = 600, Range = 28, Damage = 18, AttackInterval = 1.2, Windup = 0.3,
	UpdateInterval = 0.1, AggroDuration = 3, TeamGold = 50,
	TargetPriority = priority,
	AllowSummons = true, -- Source clones are damageable illusions; DamageService excludes legacy cosmetics.
	Positions = {
		Blue = { Top = { -70, 4, -99 }, Mid = { -70, 4, 15 }, Bottom = { -70, 4, 99 } },
		Red = { Top = { 70, 4, -99 }, Mid = { 70, 4, 15 }, Bottom = { 70, 4, 99 } },
	},
	Visual = { ProjectileDuration = 0.16, RuinFlashLifetime = 0.65, MaxEffects = 24, ViewDistance = 220 },
}
