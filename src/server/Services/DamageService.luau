--!strict
local Teams = require(script.Parent.TeamService)
local Stats = require(script.Parent.CharacterStatsService)
local Life = require(script.Parent.CombatLifeService)
local Structures = require(script.Parent.StructureService)
local TowerRewards = require(script.Parent.TowerRewardService)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Game.ProgressionRules).configure(require(Shared.Config.ProgressionConfig), require(Shared.Config.ItemConfig).Items)
local DamageService = { Applied = Instance.new("BindableEvent"), AttackAttempt = Instance.new("BindableEvent") }
local enabled = true
local aodaGuards:{[Model]:{source:Model,untilAt:number}}={}
function DamageService.SetAodaGuard(target:Model,source:Model,untilAt:number)
 aodaGuards[target]={source=source,untilAt=untilAt};target:SetAttribute("AodaGuardUntil",untilAt)
end
function DamageService.ClearAodaGuard(source:Model)
 for target,guard in aodaGuards do if guard.source==source then target:SetAttribute("AodaGuardUntil",nil);aodaGuards[target]=nil end end
end
local incoming:{[string]:(Model,number,string?)->number}={}
function DamageService.RegisterIncoming(id:string,handler:(Model,number,string?)->number) incoming[id]=handler end
local Oil=require(script.Parent.OilStatusService)
function DamageService.SetEnabled(value: boolean) enabled = value end
function DamageService.CanAct(model: Model): boolean
	if not enabled or model:GetAttribute("CombatDisabled") == true or not model:IsDescendantOf(workspace) then return false end
	local state = Teams.GetState()
	local player = game:GetService("Players"):GetPlayerFromCharacter(model)
	if state and player and not Teams.IsParticipant(player) then return false end
	if state and (state.phase ~= "InProgress" or model:GetAttribute("RoundId") ~= state.roundId or not (Teams.IsNeutral(model) or Teams.IsActive(Teams.GetId(model)))) then return false end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end
function DamageService.CanDamage(attacker: Model, target: Model): boolean
return DamageService.CanAct(attacker) and DamageService.CanAct(target) and Teams.IsEnemy(attacker, target)
		and (target:GetAttribute("EntityKind") ~= "Summon" or target:GetAttribute("NativeNarutoClone") == true or target:GetAttribute("NativeGamakichi")==true or target:GetAttribute("NativeMeditationClone")==true or target:GetAttribute("NativeAoda")==true)
		and target:GetAttribute("IsDestroyed") ~= true
		and Structures.CanReceive(target)
end
function DamageService.Apply(attacker: Model, humanoid: Humanoid, amount: number, kind:string?): number
	local target = humanoid.Parent
	if not target or not target:IsA("Model") or not DamageService.CanDamage(attacker, target) then return 0 end
	if amount ~= amount or amount <= 0 or amount == math.huge then return 0 end
 local guard=aodaGuards[target]
 if guard then
  if workspace:GetServerTimeNow()>=guard.untilAt or not DamageService.CanAct(guard.source) then target:SetAttribute("AodaGuardUntil",nil);aodaGuards[target]=nil
  elseif kind~="Attack" and kind~="Pure" then amount*=.7 end
 end
	local modifier=incoming[tostring(target:GetAttribute("HeroId"))];if modifier then amount=modifier(target,amount,kind) end
	local before = humanoid.Health
	if attacker:GetAttribute("NativeNarutoClone") == true then amount *= (attacker:GetAttribute("OutgoingDamageMultiplier") :: number) end
	if target:GetAttribute("NativeNarutoClone") == true then amount *= (target:GetAttribute("IncomingDamageMultiplier") :: number) end
	local stats = Stats.GetForModel(target)
	if kind=="Pure" then -- Source pure damage bypasses armor.
 elseif stats then local poison=(target:GetAttribute("SnakePoisonUntil") or 0) :: number;amount = Rules.mitigate(amount, stats.Defense-(if poison>workspace:GetServerTimeNow() then (target:GetAttribute("SnakePoisonArmor") or 0) :: number else 0))
	elseif target:GetAttribute("NativeGamakichi")==true or target:GetAttribute("NativeAoda")==true then amount=Rules.mitigate(amount,(target:GetAttribute("SummonArmor") or 0) :: number) end
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
function DamageService.NotifyAttackAttempt(attacker: Model,target: Model)
 if DamageService.CanDamage(attacker,target) then
  local untilAt=(target:GetAttribute("SasukeGenjutsuUntil") or 0) :: number
  local sleeping=(target:GetAttribute("SleepUntil") or 0) :: number
  -- Consume before firing callbacks: attack start and contact cannot award twice.
  local bonus=untilAt>workspace:GetServerTimeNow() and sleeping>workspace:GetServerTimeNow()
  if bonus then target:SetAttribute("SasukeGenjutsuUntil",nil) end
  DamageService.AttackAttempt:Fire(attacker,target)
  local humanoid=target:FindFirstChildOfClass("Humanoid")
  if bonus and humanoid then DamageService.Apply(attacker,humanoid,50,"Pure") end
 end
end
function DamageService.ApplyAttack(attacker: Model,humanoid: Humanoid,amount: number): number
 local target=humanoid.Parent
 if target and target:IsA("Model") then DamageService.NotifyAttackAttempt(attacker,target) end
 if target and target:GetAttribute("NativeAoda")==true and math.random()<.3 then return 0 end
 if Oil.MissesAttack(attacker) then return 0 end
 return DamageService.Apply(attacker,humanoid,amount,"Attack")
end
return DamageService
