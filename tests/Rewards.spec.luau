--!strict
local Rules = require("../src/shared/Game/RewardRules")
local Config = require("../src/shared/Config/ProgressionConfig")
local count = 0
local function check(name: string, value: boolean)
 assert(value, name); count += 1; print("PASS Rewards: " .. name)
end
local players: { Rules.PlayerSample } = {
 { userId = 1, teamId = "Blue", active = true, alive = true, inRange = true },
 { userId = 2, teamId = "Blue", active = true, alive = true, inRange = true },
 { userId = 3, teamId = "Red", active = true, alive = true, inRange = true },
 { userId = 4, teamId = "Blue", active = true, alive = false, inRange = true },
 { userId = 5, teamId = "Blue", active = true, alive = true, inRange = false },
 { userId = 6, teamId = "Green", active = false, alive = true, inRange = true },
}
local actor: Rules.Actor = { userId = 1, teamId = "Blue" }
local assistant: Rules.Actor = { userId = 2, teamId = "Blue" }
local npc: Rules.Actor = { userId = nil, teamId = "Blue" }
local inactive: Rules.Actor = { userId = 6, teamId = "Green" }
local changed: Rules.Actor = { userId = 1, teamId = "Green" }
local event: Rules.Death = { kind = "Minion", teamId = "Red", victimUserId = nil, killer = actor, assists = {} }
local plan = Rules.plan(event, players, Config.MinionRewards.Melee, Config.HeroReward, Config.AssistReward, true)
check("melee last hit", plan[1].XP == 30 and plan[1].Gold == 20 and plan[1].MinionKills == 1)
check("full XP each nearby ally", plan[2].XP == 30 and plan[2].Gold == 0)
check("enemy gets nothing", plan[3] == nil)
check("dead hero excluded from nearby XP", plan[4] == nil)
check("distant hero excluded from nearby XP", plan[5] == nil)
check("inactive team excluded", plan[6] == nil)
plan = Rules.plan(event, players, Config.MinionRewards.Ranged, Config.HeroReward, Config.AssistReward, true)
check("ranged last hit", plan[1].XP == 40 and plan[1].Gold == 25)
event = { kind = "Minion", teamId = "Red", victimUserId = nil, killer = npc, assists = {} }
plan = Rules.plan(event, players, Config.MinionRewards.Melee, Config.HeroReward, Config.AssistReward, true)
check("NPC kill shares XP", plan[1].XP == 30 and plan[2].XP == 30)
check("NPC kill has no gold or hero last hit count", plan[1].Gold == 0 and plan[2].Gold == 0 and plan[1].MinionKills == 0)
event = { kind = "Hero", teamId = "Red", victimUserId = 3, killer = actor, assists = { assistant, assistant, actor } }
plan = Rules.plan(event, players, nil, Config.HeroReward, Config.AssistReward, true)
check("hero killer bounty", plan[1].XP == 150 and plan[1].Gold == 100 and plan[1].Kills == 1)
check("assistant bounty once", plan[2].XP == 50 and plan[2].Gold == 25 and plan[2].Assists == 1)
check("killer is not assistant", plan[1].Assists == 0)
check("victim death count", plan[3].Deaths == 1 and plan[3].Gold == 0)
check("nonparticipants not paid", plan[4] == nil and plan[5] == nil)
plan = Rules.plan(event, players, nil, Config.HeroReward, Config.AssistReward, false)
check("finished match no rewards or counters", next(plan) == nil)
event = { kind = "Hero", teamId = "Blue", victimUserId = 2, killer = actor, assists = {} }
plan = Rules.plan(event, players, nil, Config.HeroReward, Config.AssistReward, true)
check("friendly death gives no bounty", plan[1] == nil and plan[2].Deaths == 1 and plan[2].Gold == 0)
event = { kind = "Base", teamId = "Red", victimUserId = nil, killer = actor, assists = {} }
plan = Rules.plan(event, players, nil, Config.HeroReward, Config.AssistReward, true)
check("base has no bounty", next(plan) == nil)
event = { kind = "Hero", teamId = "Red", victimUserId = 3, killer = npc, assists = { assistant } }
plan = Rules.plan(event, players, nil, Config.HeroReward, Config.AssistReward, true)
check("NPC hero kill still rewards eligible assistant", plan[2].Assists == 1 and plan[2].Gold == 25 and plan[1] == nil)
event = { kind = "Hero", teamId = "Red", victimUserId = 3, killer = nil, assists = {} }
plan = Rules.plan(event, players, nil, Config.HeroReward, Config.AssistReward, true)
check("unattributed death only counts death", plan[3].Deaths == 1 and plan[1] == nil)
event = { kind = "Hero", teamId = "Red", victimUserId = 3, killer = actor, assists = { inactive } }
plan = Rules.plan(event, players, nil, Config.HeroReward, Config.AssistReward, true)
check("inactive assistant excluded", plan[6] == nil)
event = { kind = "Hero", teamId = "Red", victimUserId = 3, killer = changed, assists = {} }
plan = Rules.plan(event, players, nil, Config.HeroReward, Config.AssistReward, true)
check("team changed since hit excludes killer", plan[1] == nil)
print("ALL PASS: " .. count .. " reward allocation checks")
