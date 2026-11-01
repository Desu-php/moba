--!strict
-- Pure, opt-in policy. Nothing here grants a runtime ability or mutates progression.
-- Source: docs/source/naruto-progression-and-branches-contract.txt, Learning;
-- existing NarutoDefinitions / docs/NARUTO-LEGEND.md provide base spell evidence.
export type Profile = { Level: number, SkillPoints: number, Learned: { [string]: number } }
export type Purchase = { rank: number, pointCost: number, minimumLevel: number, levelStatus: string }
export type ClonePlan = { count: number, cooldown: number, manaCost: number, lifetime: number }
local Policy = {}
local rasenganLevels = table.freeze({ 4, 11, 18 })
local cloneCounts = table.freeze({ 3, 4, 5, 7 })
local cloneCooldowns = table.freeze({ 50, 46, 42, 38 })
local function integer(value: number, low: number, high: number): boolean
	return value == value and value >= low and value <= high and value % 1 == 0
end
local function maxRank(id: string): number?
	if id == "Rasengan" then return 3 end
	if id == "ShadowClones" then return 4 end
	return nil
end
function Policy.minimumLevel(id: string, rank: number, cloneFirstLevel: number?): (number?, string)
	local maximum = maxRank(id)
	if not maximum then return nil, "UnknownAbility" end
	if not integer(rank, 1, maximum) then return nil, "Rank" end
	if id == "Rasengan" then return rasenganLevels[rank], "MapExplicit" end
	if cloneFirstLevel == nil then return nil, "NativeFirstLevelUnknown" end
	if not integer(cloneFirstLevel, 1, 30) then return nil, "NativeFirstLevelPolicy" end
	-- An explicit application choice, never promoted to verified native parity.
	return cloneFirstLevel + 4 * (rank - 1), "CallerSelectedNativeBoundary"
end
function Policy.purchasePlan(profile: Profile, id: string, requestedRank: number, cloneFirstLevel: number?): (Purchase?, string)
	local maximum = maxRank(id)
	if not maximum then return nil, "UnknownAbility" end
	local learned = profile.Learned[id] or 0
	if not integer(profile.Level, 1, 30) or not integer(profile.SkillPoints, 0, 30)
		or not integer(learned, 0, maximum) then return nil, "Profile" end
	if not integer(requestedRank, 1, maximum) then return nil, "Rank" end
	if learned == maximum then return nil, "MaxRank" end
	if requestedRank ~= learned + 1 then return nil, "PreviousRank" end
	local required, status = Policy.minimumLevel(id, requestedRank, cloneFirstLevel)
	if required == nil then return nil, status end
	if profile.Level < required then return nil, "Level" end
	if profile.SkillPoints < 1 then return nil, "NoPoints" end
	return { rank = requestedRank, pointCost = 1, minimumLevel = required, levelStatus = status }, "Accepted"
end
-- Evidence catalog is separate from supported cast admission.
function Policy.cloneRank(rank: number): (ClonePlan?, string)
	if not integer(rank, 1, 4) then return nil, "Rank" end
	return { count = cloneCounts[rank], cooldown = cloneCooldowns[rank], manaCost = 200, lifetime = 20 }, "BaseVerified"
end
function Policy.castReason(id: string, rank: number, variant: string): string?
	local maximum = maxRank(id)
	if not maximum then return "UnknownAbility" end
	if not integer(rank, 1, maximum) then return "Rank" end
	if id == "Rasengan" then
		if variant ~= "Ordinary" then return "VariantNotImplemented" end
		if rank > 1 then return "RasenganRankEffectsUnknown" end
		return nil
	end
	if variant == "EnemySleep" then
		return if rank < 2 then "Target" else "NativeSleepPolicyUnknown"
	end
	if variant == "OrdinaryPoint" then
		return if rank == 1 then nil else "AdvancedPointPolicyUnknown"
	end
	if variant ~= "OrdinarySelf" then return "VariantNotImplemented" end
	-- Rank IV self-target can select mass summons. Do not disguise it as seven.
	if rank == 4 then return "NativeManaOrderingUnknown" end
	return nil
end
function Policy.ordinaryClonePlan(rank: number, variant: string): (ClonePlan?, string)
	local reason = Policy.castReason("ShadowClones", rank, variant)
	if reason then return nil, reason end
	return Policy.cloneRank(rank)
end
return table.freeze(Policy)
