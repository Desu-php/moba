--!strict
export type Stats = { MaxHealth: number, Damage: number, AttackCooldown: number, AttackRange: number, DetectionRange: number, WalkSpeed: number }
local types: { [string]: Stats } = {
	Melee = { MaxHealth = 100, Damage = 8, AttackCooldown = 1.2, AttackRange = 5, DetectionRange = 16, WalkSpeed = 10 },
	Ranged = { MaxHealth = 70, Damage = 12, AttackCooldown = 1.8, AttackRange = 18, DetectionRange = 24, WalkSpeed = 9 },
}
return table.freeze({
	Types = types, WaveComposition = { "Melee", "Melee", "Ranged" },
	FirstWaveDelay = 5, WaveInterval = 20, MaxActiveNPCs = 108,
	UpdateInterval = 0.15, SpawnSpacing = 3, SpawnGrace = 0.3,
	WaypointRadius = 3, StuckTime = 3, ProgressDistance = 1,
	MaxRecoveryAttempts = 3, RecoveryOffset = 5, CorpseLifetime = 1,
	SpatialCellSize = 24, ProjectileDuration = 0.18,
	DebugPerformance = false, DiagnosticInterval = 10,
})
