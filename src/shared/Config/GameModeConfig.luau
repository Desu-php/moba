--!strict
return table.freeze({
	TeamCapacity = 5, PreparationTime = 5, RespawnTime = 4,
	StudioMinimumPerTeam = 1, -- Explicit Studio-only 1v1 override; production always requires 5v5.
	DebugSoloMode = false, -- Additionally gated by RunService:IsStudio().
	BaseHealth = 1500, SnapshotInterval = 0.5,
	Teams = {
		{ Id = "Blue", DisplayName = "Альянс шиноби", Color = Color3.fromRGB(65, 145, 255), BrickColor = "Bright blue" },
		{ Id = "Red", DisplayName = "Акацуки", Color = Color3.fromRGB(255, 85, 85), BrickColor = "Bright red" },
	},
})
