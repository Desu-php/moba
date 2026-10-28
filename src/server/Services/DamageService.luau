--!strict
local Teams = require(script.Parent.TeamService)
local Stats = require(script.Parent.CharacterStatsService)
local Life = require(script.Parent.CombatLifeService)
local Structures = require(script.Parent.StructureService)
local TowerRewards = require(script.Parent.TowerRewardService)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Game.ProgressionRules).configure(require(Shared.Config.ProgressionConfig), require(Shared.Config.ItemConfig).Items)
local DamageService = { Applied = Instance.new("BindableEvent") }
local enabled = true
function DamageService.SetEnabled(value: boolean) enabled = value end
function DamageService.CanAct(model: Model): boolean
	if not enabled or model:GetAttribute("CombatDisabled") == true or not model:IsDescendantOf(workspace) then return false end
	local state = Teams.GetState()
	local player = game:GetService("Players"):GetPlayerFromCharacter(model)
	if state and player and not Teams.IsParticipant(player) then return false end
	if state and (state.phase ~= "InProgress" or model:GetAttribute("RoundId") ~= state.roundId or not Teams.IsActive(Teams.GetId(model))) then return false end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end
function DamageService.CanDamage(attacker: Model, target: Model): boolean
	return DamageService.CanAct(attacker) and DamageService.CanAct(target) and Teams.IsEnemy(attacker, target)
		and target:GetAttribute("EntityKind") ~= "Summon"
		and target:GetAttribute("IsDestroyed") ~= true
		and Structures.CanReceive(target)
end
function DamageService.Apply(attacker: Model, humanoid: Humanoid, amount: number): number
	local target = humanoid.Parent
	if not target or not target:IsA("Model") or not DamageService.CanDamage(attacker, target) then return 0 end
	if amount ~= amount or amount <= 0 or amount == math.huge then return 0 end
	local before = humanoid.Health
	local stats = Stats.GetForModel(target)
	if stats then amount = Rules.mitigate(amount, stats.Defense) end
	Life.Register(target)
	humanoid:TakeDamage(math.min(amount, before))
	local dealt = math.max(0, before - humanoid.Health)
	if dealt > 0 then
		TowerRewards.Confirmed(attacker, target)
		Life.Record(attacker, target)
		local match = Teams.GetState()
		DamageService.Applied:Fire(attacker, target, dealt, if match then match.roundId else nil)
	end
	return dealt
end
return DamageService
