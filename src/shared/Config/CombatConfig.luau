--!strict

-- Plain Luau data: the same timing profile can be tested without Roblox.
local profileValues = {
	ComboResetTime = 1.2,
	AttackCooldown = 0.35,
	FinisherCooldown = 0.8,
	InputBufferWindow = 0.12,
	DamageByComboStep = table.freeze({ 5, 5, 7, 10 }),
	HitDelayByComboStep = table.freeze({ 0.10, 0.10, 0.12, 0.18 }),
	AttackDurationByComboStep = table.freeze({ 0.28, 0.28, 0.30, 0.55 }),
	HitStunDuration = 0.25,
	FinisherStunDuration = 0.65,
	MaxStunDuration = 0.8,
	HitboxSize = table.freeze({ X = 5, Y = 5, Z = 5 }),
	HitboxOffset = table.freeze({ X = 0, Y = 0, Z = -2.5 }),
	MaxTargetDistance = 6,
	MinimumForwardDot = 0.15,
	MaxTargets = 16,
	KnockbackVelocity = 35,
	KnockbackUpVelocity = 8,
	MaxKnockbackSpeed = 45,
	KnockbackWallProbeTime = 0.12,
	KnockbackWallPadding = 0.3,
	KnockbackProbeSize = table.freeze({ X = 1.5, Y = 2, Z = 1.5 }),
	AnimationSet = "Default",
	AnimationKeys = table.freeze({ "Punch1", "Punch2", "Punch3", "HeavyPunch" }),
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
