--!strict

-- Plain Luau data: the same timing profile can be tested without Roblox.
local profileValues = {
	AttackCooldown = 0.5,
	InputBufferWindow = 0.12,
	AttackSpeedPerAgility = 0.01,
	MaxAttacksPerSecond = 2.5,
	Damage = 8,
	CloneDamage = 5, -- Preserve the existing clone balance independently of hero M1.
	HitDelay = 0.16,
	AttackDuration = 0.42,
	MaxStunDuration = 0.8,
	HitboxSize = table.freeze({ X = 5, Y = 5, Z = 5 }),
	HitboxOffset = table.freeze({ X = 0, Y = 0, Z = -2.5 }),
	MaxTargetDistance = 6,
	MinimumForwardDot = 0.5,
	MaxTargets = 1,
	KnockbackVelocity = 35,
	KnockbackUpVelocity = 8,
	MaxKnockbackSpeed = 45,
	KnockbackWallProbeTime = 0.12,
	KnockbackWallPadding = 0.3,
	KnockbackProbeSize = table.freeze({ X = 1.5, Y = 2, Z = 1.5 }),
	AnimationSet = "Default",
	AnimationKey = "Punch1",
}
local defaultProfile = table.freeze(table.clone(profileValues))

export type AttackProfile = typeof(defaultProfile)
local profiles: { [string]: AttackProfile } = { Default = defaultProfile }
local ninja = table.clone(profileValues)
ninja.AnimationSet = "OrangeNinja"
profiles.OrangeNinja = table.freeze(ninja)

return table.freeze({
	DefaultProfile = "Default",
	Profiles = table.freeze(profiles),
	RemoteLimit = table.freeze({ Burst = 6, RequestsPerSecond = 8, RejectReplyInterval = 0.25 }),
	MaxRequestId = 2147483647,
	PredictionTimeout = 1.5,
	CharacterReadyTimeout = 15,
	PositionEpsilon = 0.001,
	AnimationFadeTime = 0.06,
	AnimationCorrectionThreshold = 0.08,
})
