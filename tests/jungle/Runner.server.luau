--!strict
assert(game:GetService("RunService"):IsStudio())
local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match = require(services.MatchService)
local Jungle = require(services.JungleService)
local Teams = require(services.TeamService)
local Damage = require(services.DamageService)
local Fighters = require(services.FighterStateService)
local Combat = require(services.CombatService)
local Economy = require(services.EconomyService)
local Progression = require(services.HeroProgressionService)
local AI = require(services.MinionAIService)
local Towers = require(services.TowerService)
local Bases = require(services.BaseService)
local Ability = require(services.AbilityService)
local Summons = require(services.NarutoSummonService)
local remote = Instance.new("RemoteEvent"); remote.Name = "JungleTestDriver"; remote.Parent = Replicated
local replies: { [Player]: boolean } = {}
remote.OnServerEvent:Connect(function(player: Player, camps: boolean, hud: boolean) replies[player] = camps and hud end)
local count = 0
local function check(name: string, value: boolean) assert(value, name); count += 1; print("[JungleTests] PASS: " .. name) end
local function waitFor(predicate: () -> boolean, timeout: number, name: string)
	local untilTime = os.clock()+timeout
	repeat if predicate() then return end; task.wait(0.03) until os.clock() >= untilTime
	error("Timeout: " .. name)
end
local function move(player: Player, at: Vector3, face: Vector3?)
	local model = player.Character :: Model
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	for _, item in model:GetChildren() do if item:IsA("ForceField") then item:Destroy() end end
	root.Anchored = false; root:SetNetworkOwner(nil); root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = if face then CFrame.lookAt(at, Vector3.new(face.X,at.Y,face.Z)) else CFrame.new(at)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.AutoRotate = false; humanoid.Health = humanoid.MaxHealth
end
local ok, failure = xpcall(function()
	waitFor(function() return #Players:GetPlayers()==2 and Match.GetState()~=nil end, 90, "two players")
	local state = Match.GetState(); assert(state)
	-- Only this test build advances preparation; production settings remain intact.
	state.phase="Preparing"; state.preparationEnds=0
	waitFor(function() return state.phase=="InProgress" and Jungle.GetAll()[1].model~=nil end, 15, "match camps")
	for model in AI.GetAll() do AI.Remove(model) end
	local players=Players:GetPlayers(); local blue=players[1]; local red=players[2]
	if blue:GetAttribute("TeamId")=="Red" then blue,red=red,blue end
	move(blue,Vector3.new(-145,36,10)); move(red,Vector3.new(145,36,-10))
	check("four symmetric camps", #Jungle.GetAll()==4)
	for _, player in players do remote:FireClient(player) end
	waitFor(function() return replies[blue]==true and replies[red]==true end, 8, "both clients camps and HUD")
	check("camp models and desktop HUD replicate to both clients", true)
	local camp=Jungle.GetAll()[1]; local model=camp.model :: Model
	local humanoid=model:FindFirstChildOfClass("Humanoid") :: Humanoid
	check("server registered neutral", Teams.IsNeutral(model) and model:GetAttribute("RoundId")==state.roundId)
	check("both factions can attack neutral", Damage.CanDamage(blue.Character :: Model,model) and Damage.CanDamage(red.Character :: Model,model))
	check("neutral can retaliate both factions", Damage.CanDamage(model,blue.Character :: Model) and Damage.CanDamage(model,red.Character :: Model))
	check("neutral cannot attack neutral", not Damage.CanDamage(model,Jungle.GetAll()[2].model :: Model))
	check("ordinary enemy and ally policy preserved", Damage.CanDamage(blue.Character :: Model,red.Character :: Model) and not Damage.CanDamage(blue.Character :: Model,blue.Character :: Model))
	blue:SetAttribute("Spectating",true)
	check("waiting player cannot interact with neutral", not Damage.CanDamage(blue.Character :: Model,model) and not Damage.CanDamage(model,blue.Character :: Model))
	blue:SetAttribute("Spectating",false)
	local forged=model:Clone(); forged.Parent=workspace
	check("forged neutral attributes not admitted", not Damage.CanAct(forged)); forged:Destroy()
	model:SetAttribute("RoundId",state.roundId-1)
	check("stale neutral epoch rejected", not Damage.CanDamage(blue.Character :: Model,model))
	model:SetAttribute("RoundId",state.roundId)
	local original=model:GetPivot().Position
	move(blue,camp.home+Vector3.new(9,0,0),camp.home)
	waitFor(function() return model:GetAttribute("AIState")=="Chasing" end,3,"aggro")
	check("nearby hero acquires aggro", camp.target==blue.Character)
	local health=(blue.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	local before=health.Health
	waitFor(function() return health.Health<before end,5,"neutral melee")
	check("guardian moves and damages hero", (model:GetPivot().Position-original).Magnitude>1 and health.Health<before)
	move(blue,model:GetPivot().Position+Vector3.new(4.5,0,0),model:GetPivot().Position)
	local hp=humanoid.Health
	check("normal M1 admitted", Combat.TryAttack(blue,1,blue.Character)=="Started")
	waitFor(function() return humanoid.Health<hp end,2,"M1 impact")
	check("normal M1 damages registered camp", humanoid.Health<hp)
	move(blue,camp.home+Vector3.new(40,0,0))
	waitFor(function() return model:GetAttribute("AIState")=="Returning" end,3,"leash")
	check("leash rejects damage during return", Damage.Apply(blue.Character :: Model,humanoid,10)==0)
	waitFor(function() return model:GetAttribute("AIState")=="Idle" end,9,"bounded home return")
	check("return restores full health and clears target", humanoid.Health==humanoid.MaxHealth and camp.target==nil)
	move(blue,camp.home+Vector3.new(10,0,0),camp.home)
	local gold=Economy.GetGold(blue); local profile=Progression.Get(blue); assert(profile)
	local killGold = 0
	local rewardConnection = Economy.GoldChanged.Event:Connect(function(player: Player, _balance: number, delta: number, reason: string)
		if player==blue and reason=="Kill" then killGold += delta end
	end)
	local totalKills=profile.TotalKills
	local xp, minions = profile.CurrentXP, profile.TotalMinionKills
	check("confirmed lethal damage", Damage.Apply(blue.Character :: Model,humanoid,9999)>0)
	waitFor(function() return Economy.GetGold(blue)>=gold+35 end,2,"neutral bounty")
	check("neutral kill grants gold without hero kill", Economy.GetGold(blue)>=gold+35 and profile.TotalKills==totalKills)
	check("neutral grants XP and minion credit", profile.CurrentXP==xp+50 and profile.TotalMinionKills==minions+1)
	check("repeat corpse damage cannot pay twice", Damage.Apply(blue.Character :: Model,humanoid,9999)==0)
	task.wait(0.1); check("exact single bounty excluding passive gold", killGold==35)
	move(blue,Vector3.new(-145,36,10))
	waitFor(function() return camp.model==nil end,3,"corpse cleanup")
	check("corpse unregistered and fighter removed", not Teams.IsNeutral(model) and Fighters.Get(model)==nil)
	waitFor(function() return camp.model~=nil and camp.model~=model end,48,"natural respawn")
	check("natural respawn is fresh full-health life", (camp.model :: Model):GetAttribute("LifeId")~=model:GetAttribute("LifeId"))
	local respawn=camp.model :: Model; local respawnHP=respawn:FindFirstChildOfClass("Humanoid") :: Humanoid
	Progression.AddXP(blue,450)
 local learner=blue.Character :: Model
 for i,id in {"Rasengan","ShadowClones"} do assert(require(services.AbilityLearningService).HandleRequest(blue,i,learner,learner:GetAttribute("LifeId"),id,state.roundId)) end
	move(blue,camp.home+Vector3.new(4.5,0,0),respawn:GetPivot().Position)
	check("Q request against neutral admitted", Ability.HandleRequest(blue,1001,blue.Character,"Rasengan",state.roundId))
	waitFor(function() return (blue.Character :: Model):GetAttribute("RasenganPhase")=="Holding" end,3,"Q hold")
	move(blue,respawn:GetPivot().Position+Vector3.new(4.5,0,0),respawn:GetPivot().Position)
	check("empowered M1 admitted", Combat.TryAttack(blue,2,blue.Character)=="Started")
	task.wait(0.2)
	check("Q stuns neutral before delayed impact", respawnHP.Health>0 and (Fighters.Get(respawn) :: any).logic.mode=="Stunned")
	waitFor(function() return respawnHP.Health==0 end,2,"Q delayed damage")
	check("Q consumes held sphere on neutral", (blue.Character :: Model):GetAttribute("RasenganHeld")~=true)
	local cloneCamp=Jungle.GetAll()[2]; local cloneTarget=cloneCamp.model :: Model
	local cloneHP=cloneTarget:FindFirstChildOfClass("Humanoid") :: Humanoid
	move(blue,cloneCamp.home+Vector3.new(8,0,0),cloneCamp.home)
	task.wait(1.1)
	check("ordinary clones admitted", Ability.HandleRequest(blue,1002,blue.Character,"ShadowClones",state.roundId))
	waitFor(function() return Summons.GetCount()==3 end,2,"clones spawned")
	check("explicit neutral target command admitted", Ability.HandleRequest(blue,1003,blue.Character,"CloneCommand",cloneTarget,state.roundId))
	local cloneBefore=cloneHP.Health
	waitFor(function() return cloneHP.Health<cloneBefore end,5,"clone hits neutral")
	check("clones can damage neutral target", cloneHP.Health<cloneBefore)
	local beforeCloneKill=profile.TotalMinionKills
	cloneHP.Health=1 -- Fixture setup; lethal hit must still be confirmed through DamageService.
	waitFor(function() return cloneHP.Health==0 and profile.TotalMinionKills==beforeCloneKill+1 end,5,"clone owner bounty")
	check("clone last hit credits owner exactly once", profile.TotalMinionKills==beforeCloneKill+1 and killGold==105)
	Summons.Reset(); move(blue,Vector3.new(-145,36,10))
	for _, tower in Towers.GetAll() do
		if tower.structure.teamId=="Red" then Damage.Apply(blue.Character :: Model,tower.structure.humanoid,9999) end
	end
	local base=Bases.Get("Red"); assert(base)
	Damage.Apply(blue.Character :: Model,base.humanoid,9999)
	waitFor(function() return state.phase=="Finished" end,2,"terminal")
	check("throne remains terminal", state.phase=="Finished")
	check("finished camp combat disabled", not Damage.CanAct(Jungle.GetAll()[3].model :: Model))
	local terminalModel=camp.model; Jungle.Update(workspace:GetServerTimeNow()+1000)
	check("no terminal respawn even when overdue", camp.model==terminalModel)
	rewardConnection:Disconnect()
	print("[JungleTests] ALL PASS: " .. count .. " integration checks")
	return "passed"
end,function(message) return debug.traceback(tostring(message),2) end)
if not ok then warn("[JungleTests] FAILED after "..count..": "..tostring(failure)) end
