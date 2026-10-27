--!strict
return table.freeze({
	MinimumPlayers = 2, PreparationTime = 5, RespawnTime = 4,
	DebugSoloMode = false, -- Additionally gated by RunService:IsStudio().
	BaseHealth = 1500, SnapshotInterval = 0.5,
	Teams = {
		{ Id = "Blue", Color = Color3.fromRGB(65, 145, 255), BrickColor = "Bright blue" },
		{ Id = "Red", Color = Color3.fromRGB(255, 85, 85), BrickColor = "Bright red" },
	},
})
