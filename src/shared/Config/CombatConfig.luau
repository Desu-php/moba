--!strict

-- Plain Luau data: the same timing profile can be tested without Roblox.
local KuramaAvatar = require("./KuramaAvatarConfig")
local Attributes = require("./AttributeConfig")
local profileValues = {
	AttackCooldown = 0.5,
	InputBufferWindow = 0.12,
	AttackSpeedPerAgility = Attributes.AttackSpeedPerAgility,
	MaxAttacksPerSecond = Attributes.MaximumAttackSpeedMultiplier / .5,
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
local sasuke=table.clone(profileValues)
sasuke.AnimationSet="Sasuke";sasuke.Damage=10;sasuke.AttackCooldown=2
sasuke.HitDelay=.24;sasuke.AttackDuration=.68
sasuke.MaxAttacksPerSecond=Attributes.MaximumAttackSpeedMultiplier/sasuke.AttackCooldown
profiles.Sasuke=table.freeze(sasuke)
local susanoo=table.clone(profileValues);susanoo.AnimationSet="Sasuke";susanoo.Damage=10;susanoo.AttackCooldown=3;susanoo.HitDelay=.6;susanoo.AttackDuration=1.1
susanoo.MaxAttacksPerSecond=Attributes.MaximumAttackSpeedMultiplier/susanoo.AttackCooldown
susanoo.HitboxSize={X=12,Y=14,Z=16};susanoo.HitboxOffset={X=0,Y=0,Z=-8};susanoo.MaxTargetDistance=18
profiles.SasukeSusanoo=table.freeze(susanoo)
local kurama = table.clone(profileValues)
-- Ewar attack cooldown/range from the map; windup, box and animation are the third-person adaptation.
-- Keep damage in the existing stat ledger (+90 for the form), rather than applying the bonus twice.
kurama.AttackCooldown = 2
kurama.MaxAttacksPerSecond=Attributes.MaximumAttackSpeedMultiplier/kurama.AttackCooldown
kurama.HitDelay = 0.8
kurama.AttackDuration = 1.7
kurama.HitboxSize = table.freeze({ X = 18, Y = 9, Z = 16 })
kurama.HitboxOffset = table.freeze({ X = 0, Y = 0, Z = -8 })
kurama.MaxTargetDistance = KuramaAvatar.AttackReach
kurama.MinimumForwardDot = 0.25
kurama.MaxTargets = math.huge -- Every distinct enemy actually touched by the paw sweep.
kurama.AnimationSet = "Kurama"
kurama.AnimationKey = "ClawSwipe"
profiles.Kurama = table.freeze(kurama)

return table.freeze({
	DefaultProfile = "Default",
	Profiles = table.freeze(profiles),
	RemoteLimit = table.freeze({ Burst = 8, RequestsPerSecond = 20, RejectReplyInterval = 0.25 }),
	MaxRequestId = 2147483647,
	PredictionTimeout = 1.5,
	CharacterReadyTimeout = 15,
	PositionEpsilon = 0.001,
	AnimationFadeTime = 0.06,
	AnimationCorrectionThreshold = 0.08,
})
