--!strict
local Policy = require("../src/shared/Abilities/NarutoRankPolicy")
local Definitions = require("../src/shared/Abilities/NarutoDefinitions")
local checks = 0
local function check(value: boolean, label: string)
	assert(value, label); checks += 1
end
local function profile(level: number, learned: number, points: number): Policy.Profile
	return { Level = level, SkillPoints = points, Learned = { Rasengan = learned, ShadowClones = learned } }
end
for rank, level in { 4, 11, 18 } do
	check(Policy.minimumLevel("Rasengan", rank) == level, "explicit Q level")
	local p = profile(level - 1, rank - 1, 1)
	check(select(2, Policy.purchasePlan(p, "Rasengan", rank)) == "Level", "Q below level")
	p.Level = level
	local plan = Policy.purchasePlan(p, "Rasengan", rank); assert(plan)
	check(plan.minimumLevel == level and plan.rank == rank and plan.pointCost == 1, "Q at boundary")
	check(plan.levelStatus == "MapExplicit", "Q source status")
	check(p.SkillPoints == 1 and p.Learned.Rasengan == rank - 1, "plan never debits")
end
for rank = 1, 4 do
	check(select(2, Policy.minimumLevel("ShadowClones", rank)) == "NativeFirstLevelUnknown", "no implicit native first")
	local required, status = Policy.minimumLevel("ShadowClones", rank, 1)
	check(required == 1 + 4 * (rank - 1) and status == "CallerSelectedNativeBoundary", "candidate levels tagged")
	check(Policy.minimumLevel("ShadowClones", rank, 2) == 2 + 4 * (rank - 1), "offset configurable")
	local p = profile(30, rank - 1, 1)
	check(select(2, Policy.purchasePlan(p, "ShadowClones", rank)) == "NativeFirstLevelUnknown", "unknown blocks learning")
	check(Policy.purchasePlan(p, "ShadowClones", rank, 1) ~= nil, "explicit policy purchase plan")
	local config = Policy.cloneRank(rank); assert(config)
	check(config.count == Definitions.Clones.Counts[rank] and config.cooldown == Definitions.Clones.Cooldowns[rank], "rank config regression")
	check(config.manaCost == 200 and config.lifetime == 20, "shared clone parameters")
end
local p = profile(30, 0, 1)
check(select(2, Policy.purchasePlan(p, "Rasengan", 2)) == "PreviousRank", "no skipped rank")
check(select(2, Policy.purchasePlan(p, "Rasengan", 4)) == "Rank", "no fourth Q")
check(select(2, Policy.purchasePlan(profile(30, 3, 1), "Rasengan", 3)) == "MaxRank", "max Q")
check(select(2, Policy.purchasePlan(profile(30, 0, 0), "Rasengan", 1)) == "NoPoints", "no free rank")
check(select(2, Policy.purchasePlan(p, "WindPalm", 1)) == "UnknownAbility", "no invented line")
check(p.SkillPoints == 1 and p.Learned.Rasengan == 0, "all denials immutable")
for _, bad in { -1, 0, 1.5, 5, 0/0, math.huge, -math.huge } do
	check(Policy.cloneRank(bad) == nil, "invalid clone rank")
	check(Policy.castReason("ShadowClones", bad, "OrdinarySelf") == "Rank", "invalid cast rank")
end
for _, bad in { -1, 0, 1.5, 31, 0/0, math.huge } do
	check(select(2, Policy.minimumLevel("ShadowClones", 1, bad)) == "NativeFirstLevelPolicy", "invalid first-level config")
	check(select(2, Policy.purchasePlan(profile(bad, 0, 1), "Rasengan", 1)) == "Profile", "invalid level")
end
for _, bad in { -1, 1.5, 31, 0/0, math.huge } do
	check(select(2, Policy.purchasePlan(profile(30, 0, bad), "Rasengan", 1)) == "Profile", "invalid points")
	check(select(2, Policy.purchasePlan(profile(30, bad, 1), "Rasengan", 1)) == "Profile", "invalid learned rank")
end
for rank = 1, 3 do
	local plan = Policy.ordinaryClonePlan(rank, "OrdinarySelf"); assert(plan)
	check(plan.count == Definitions.Clones.Counts[rank], "supported ordinary self")
	plan.count = 99
	check((Policy.cloneRank(rank) :: Policy.ClonePlan).count ~= 99, "returned plan cannot poison policy")
end
check(Policy.castReason("Rasengan", 1, "Ordinary") == nil, "base Q admitted")
for rank = 2, 3 do
	check(Policy.castReason("Rasengan", rank, "Ordinary") == "RasenganRankEffectsUnknown", "no fake later Q rank")
end
for rank = 1, 3 do
	check(Policy.castReason("Rasengan", rank, "Odama") == "VariantNotImplemented", "no Odama unlock")
end
check(Policy.castReason("ShadowClones", 1, "EnemySleep") == "Target", "rank I no enemy")
for rank = 2, 4 do
	check(Policy.castReason("ShadowClones", rank, "EnemySleep") == "NativeSleepPolicyUnknown", "sleep not stun")
	check(Policy.castReason("ShadowClones", rank, "OrdinaryPoint") == "AdvancedPointPolicyUnknown", "advanced point closed")
end
check(Policy.ordinaryClonePlan(1, "OrdinaryPoint") ~= nil, "base point retained")
check(select(2, Policy.ordinaryClonePlan(4, "OrdinarySelf")) == "NativeManaOrderingUnknown", "mass boundary closed")
check(Policy.castReason("ShadowClones", 4, "MassClones") == "VariantNotImplemented", "no mass bypass")
check(Policy.castReason("ShadowClones", 2, "Fake") == "VariantNotImplemented", "unknown variant denied")
check(table.isfrozen(Policy), "API immutable")
print("PASS NarutoRankPolicy: " .. checks .. " assertions")
