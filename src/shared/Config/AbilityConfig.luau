--!strict
export type Ability = { Name: string, Key: string, KeyLabel: string, Cooldown: number, Windup: number, Duration: number }
local abilities: { [string]: Ability } = {
	Rasengan = { Name = "Расенган I", Key = "One", KeyLabel = "1 / Q", Cooldown = 60, Windup = 2, Duration = 15 },
	ShadowClones = { Name = "Клоны I", Key = "Two", KeyLabel = "2", Cooldown = 50, Windup = 0.25, Duration = 20 },
	Gamakichi = { Name = "Гамакичи", Key = "Three", KeyLabel = "3", Cooldown = 0, Windup = 0, Duration = 0 },
	SageMode = { Name = "Режим мудреца", Key = "Four", KeyLabel = "4", Cooldown = 0, Windup = 0, Duration = 0 },
	KCM = { Name = "KCM", Key = "Five", KeyLabel = "5", Cooldown = 0, Windup = 0, Duration = 0 },
	CloneCommand = { Name = "Цель клонам", Key = "F", KeyLabel = "F", Cooldown = 0, Windup = 0, Duration = 0 },
}
return table.freeze({
	Abilities = abilities, Order = { "Rasengan", "ShadowClones", "Gamakichi", "SageMode", "KCM", "CloneCommand" },
	PrototypeEnabled = table.freeze({ Rasengan = true, ShadowClones = true, Gamakichi = true, CloneCommand = true }),
	InputAliases = table.freeze({ Q = "Rasengan" }),
	MaxRequestId = 2147483647, Burst = 4, RequestsPerSecond = 3, ReplyInterval = 0.25,
	Clones = { Count = 2, GlobalLimit = 24, Lifetime = 5, Radius = 18, Range = 4, Damage = 3,
		MaxHits = 3, Interval = 0.8, UpdateInterval = 0.1, Speed = 16, SpawnOffset = 3, SpawnForward = 1 },
	Visual = { MaxEffects = 32, SmokeLifetime = 0.55, ViewDistance = 240, BlendSpeed = 20, HUDInterval = 0.1 },
})
