--!strict
-- Pure source rules. The application supplies authoritative stats and validated targets.
-- ManaAtEffect is AFTER native cost accounting; this module does not guess engine ordering.
export type Configuration = {
	read Rasengan: { read BaseDamage: number, read StrengthFactor: number, read LevelFactor: number },
	read Clones: {
		read Counts: { number }, read Cooldowns: { number }, read ManaCost: number,
		read MassCount: number, read MassManaFraction: number,
		read PayloadLevelFactor: number, read PayloadStrengthFactor: number,
	},
}
export type ClonePlan = { kind: string, count: number, cooldown: number, nativeManaCost: number, extraManaDrain: number }
local Module = {}
function Module.finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end
local function statsValid(level: number, strength: number): boolean
	return Module.finite(level) and level >= 1 and level % 1 == 0 and Module.finite(strength) and strength >= 0
end
function Module.configure(config: Configuration)
	local Rules = {}
	function Rules.rasenganDamage(level: number, strength: number): number?
		if not statsValid(level, strength) then return nil end
		local q = config.Rasengan
		return q.BaseDamage + q.StrengthFactor * strength + q.LevelFactor * level
	end
	function Rules.clonePayloadDamage(level: number, strength: number): number?
		if not statsValid(level, strength) then return nil end
		return config.Clones.PayloadLevelFactor * level + config.Clones.PayloadStrengthFactor * strength
	end
	function Rules.clonePlan(rank: number, targetKind: string, manaAtEffect: number, maxMana: number): (ClonePlan?, string)
		if not Module.finite(rank) or rank % 1 ~= 0 or rank < 1 or rank > #config.Clones.Counts then return nil, "Rank" end
		if not Module.finite(manaAtEffect) or not Module.finite(maxMana) or maxMana <= 0
			or manaAtEffect < 0 or manaAtEffect > maxMana then return nil, "Resources" end
		if targetKind ~= "Self" and targetKind ~= "Point" and targetKind ~= "Enemy" then return nil, "Target" end
		if targetKind == "Enemy" and rank < 2 then return nil, "Target" end
		local plan: ClonePlan = {
			kind = if targetKind == "Enemy" then "Sleep" else "Burst",
			count = if targetKind == "Enemy" then 0 else config.Clones.Counts[rank],
			cooldown = config.Clones.Cooldowns[rank], nativeManaCost = config.Clones.ManaCost, extraManaDrain = 0,
		}
		if rank == 4 and targetKind == "Self" and manaAtEffect / maxMana >= config.Clones.MassManaFraction then
			plan.count = config.Clones.MassCount
			plan.extraManaDrain = maxMana * config.Clones.MassManaFraction
		end
		return plan, "Accepted"
	end
	return Rules
end
return Module
