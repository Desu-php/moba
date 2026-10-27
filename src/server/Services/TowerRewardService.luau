--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Game.TowerRules)
local Config = require(Shared.Config.TowerConfig)
local Economy = require(script.Parent.EconomyService)
local Teams = require(script.Parent.TeamService)
local Structures = require(script.Parent.StructureService)
local Reward = {}
local ledger: { [Model]: Rules.State } = setmetatable({}, { __mode = "k" })
-- Called synchronously after confirmed damage, before a same-frame core kill can finish the match.
function Reward.Confirmed(attacker: Model, target: Model)
	local record = Structures.GetAll()[target]
	if not record or record.kind ~= "Tower" or record.humanoid.Health > 0 then return end
	local attackingTeam = tostring(attacker:GetAttribute("TeamId"))
	local match = Teams.GetState()
	if not match or match.phase ~= "InProgress" or not Teams.IsActive(attackingTeam) then return end
	local state = ledger[target]
	if not state then state = Rules.new(); Rules.destroy(state); ledger[target] = state end
	if not Rules.claimReward(state, attackingTeam ~= record.teamId) then return end
	for _, player in Players:GetPlayers() do
		if Rules.recipient(attackingTeam, tostring(player:GetAttribute("TeamId")), player.Parent == Players,
			Economy.IsEligible(player), player:GetAttribute("Eliminated") == true) then
			Economy.AddGold(player, Config.TeamGold, "TowerDestroyed")
		end
	end
end
return Reward
