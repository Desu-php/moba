--!strict
-- MOBA prototype balance, not Naruto Legend ability source facts.
return table.freeze({
	TeamId = "Neutral", Leash = 30, DetectionRange = 14, AttackRange = 5.5,
	RespawnDelay = 45, CorpseLifetime = 1, UpdateInterval = 0.15,
	Stats = { MaxHealth = 180, Damage = 10, AttackCooldown = 1.4, AttackRange = 5.5, DetectionRange = 14, WalkSpeed = 12 },
	-- Mirrored across the map centre; outside the three lane corridors and rocks.
	Camps = {
		{ Id = "NorthWest", Offset = Vector3.new(-32, 4, -44) },
		{ Id = "SouthEast", Offset = Vector3.new(32, 4, 44) },
		{ Id = "SouthWest", Offset = Vector3.new(-32, 4, 44) },
		{ Id = "NorthEast", Offset = Vector3.new(32, 4, -44) },
	},
})
