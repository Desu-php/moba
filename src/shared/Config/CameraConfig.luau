--!strict
-- PC camera defaults. LocalPlayer CombatCamera* attributes may override these
-- within the bounds enforced by CombatCameraRules (e.g. a settings menu).
return table.freeze({
	Sensitivity = 0.18, -- Degrees per mouse pixel; rotation is never smoothed.
	Distance = 11,
	Height = 2.6,
	Shoulder = 1.8,
	Smoothing = 25, -- Follow interpolation rate; 0 means immediate follow.
	MinimumPitch = -65,
	MaximumPitch = 75,
	InitialPitch = -10,
	CollisionRadius = 0.45,
	CollisionPadding = 0.15,
	ReturnSpeed = 14,
	TeleportDistance = 30,
})
