--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.ProgressionConfig)
local Rules = require(Shared.Game.RewardRules)
local Life = require(script.Parent.CombatLifeService)
local Teams = require(script.Parent.TeamService)
local Progression = require(script.Parent.HeroProgressionService)
local Economy = require(script.Parent.EconomyService)
local Reward = {}
local started = false
local nextPassive = 0
-- Match scoreboard projection survives individual profile removal/reconnect.
local teamKills: { [string]: number } = {}
function Reward.GetTeamKills(id: string): number return teamKills[id] or 0 end
local awarded: { [Model]: number } = setmetatable({}, { __mode = "k" })
local function death(event: Life.Death)
 if awarded[event.model] == event.lifeId then return end
 awarded[event.model] = event.lifeId
 local state = Teams.GetState()
 if not state or event.roundId ~= state.roundId or state.phase ~= "InProgress" or not Teams.IsActive(event.teamId) then return end
 -- Elimination and match shutdown never turn into bounty events.
 if event.killer and not Teams.IsActive(event.killer.teamId) then event.killer = nil end
 local samples: { Rules.PlayerSample } = {}
 local recipients: { [number]: Player } = {}
 for _, player in Players:GetPlayers() do
  recipients[player.UserId] = player
  local model = player.Character
  local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
  local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
  table.insert(samples, { userId = player.UserId, teamId = tostring(player:GetAttribute("TeamId") or ""),
   active = Economy.IsEligible(player), alive = humanoid ~= nil and humanoid.Health > 0,
   inRange = root ~= nil and root:IsA("BasePart") and (root.Position - event.position).Magnitude <= Config.XPRange })
 end
 local minion = (Config.MinionRewards :: { [string]: Rules.Reward })[event.minionType]
 local plan = Rules.plan(event, samples, minion, Config.HeroReward, Config.AssistReward, true)
 for id, grant in plan do
  local player = recipients[id]
  if grant.XP > 0 then Progression.AddXP(player, grant.XP) end
  if grant.Gold > 0 then Economy.AddGold(player, grant.Gold, if grant.Assists > 0 then "Assist" else "Kill") end
  if grant.Kills > 0 then
   Progression.Increment(player, "TotalKills")
   local teamId = tostring(player:GetAttribute("TeamId") or "")
   teamKills[teamId] = (teamKills[teamId] or 0) + grant.Kills
  end
  if grant.Deaths > 0 then Progression.Increment(player, "TotalDeaths") end
  if grant.MinionKills > 0 then Progression.Increment(player, "TotalMinionKills") end
  if grant.Assists > 0 then Progression.Increment(player, "Assists") end
 end
end
function Reward.Update(now: number)
 local state = Teams.GetState()
 if not state or state.phase ~= "InProgress" then nextPassive = 0; return end
 if nextPassive == 0 then nextPassive = state.startedAt + Config.PassiveInterval end
 if now < nextPassive then return end
 nextPassive = now + Config.PassiveInterval
 for _, player in Players:GetPlayers() do Economy.AddGold(player, Config.PassiveGold, "Passive") end
end
function Reward.Reset() nextPassive = 0; table.clear(awarded); table.clear(teamKills); Life.ResetHistory() end
function Reward.Start()
 if started then return end; started = true
 Life.Died.Event:Connect(death)
end
return Reward
