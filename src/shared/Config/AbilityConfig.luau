--!strict
export type Ability = { Name: string, Key: string, Cooldown: number, Windup: number, Duration: number }
local abilities: { [string]: Ability } = {
	ShadowClones = { Name = "Теневые двойники", Key = "Z", Cooldown = 14, Windup = 0.3, Duration = 0.65 },
	SpiralSphere = { Name = "Расенган", Key = "X", Cooldown = 8, Windup = 0.35, Duration = 0.9 },
	WindPalm = { Name = "Ветряная ладонь", Key = "C", Cooldown = 7, Windup = 0.25, Duration = 0.65 },
}
return table.freeze({
	Abilities = abilities, Order = { "ShadowClones", "SpiralSphere", "WindPalm" },
	MaxRequestId = 2147483647, Burst = 4, RequestsPerSecond = 3, ReplyInterval = 0.25,
	Sphere = { Damage = 22, Range = 6, ForwardDot = 0.15, ContactWindow = 0.2, Stun = 0.4, Knockback = 19, UpVelocity = 3 },
	Wind = { Damage = 14, Range = 16, ForwardDot = 0.65, MaxTargets = 3, Stun = 0.25, Knockback = 30, UpVelocity = 4, VisualDuration = 0.3 },
	Clones = { Count = 2, GlobalLimit = 24, Lifetime = 5, Radius = 18, Range = 4, Damage = 3,
		MaxHits = 3, Interval = 0.8, UpdateInterval = 0.1, Speed = 16, SpawnOffset = 3, SpawnForward = 1 },
	Visual = { MaxEffects = 32, SmokeLifetime = 0.55, ViewDistance = 240, BlendSpeed = 20, HUDInterval = 0.1 },
})
