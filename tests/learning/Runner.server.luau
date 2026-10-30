--!strict
assert(game:GetService("RunService"):IsStudio())
local Players=game:GetService("Players")
local Replicated=game:GetService("ReplicatedStorage")
local services=game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match=require(services.MatchService)
local Progression=require(services.HeroProgressionService)
local Stats=require(services.CharacterStatsService)
local Learning=require(services.AbilityLearningService)
local Ability=require(services.AbilityService)
local Combat=require(services.CombatService)
local Damage=require(services.DamageService)
local Fighters=require(services.FighterStateService)
local remote=Instance.new("RemoteEvent"); remote.Name="LearningTestDriver"; remote.Parent=Replicated
local replies: { [Player]: any }={}
remote.OnServerEvent:Connect(function(player: Player,id: number,data: any) replies[player]={id=id,data=data} end)
local count,serial=0,0
local function check(name: string,value: boolean) assert(value,name); count+=1; print("[LearningTests] PASS: "..name) end
local function waitFor(predicate: () -> boolean,seconds: number,name: string)
	local limit=os.clock()+seconds
	repeat if predicate() then return end; task.wait(.02) until os.clock()>=limit
	error("Timeout: "..name)
end
local function command(player: Player,mode: string,line: string?): any
	serial+=1; local id=serial; remote:FireClient(player,id,mode,line)
	waitFor(function() return replies[player]~=nil and replies[player].id==id end,4,"client "..mode)
	return replies[player].data
end
local function profile(player: Player) local p=Progression.Get(player); assert(p); return p end
local ok,failure=xpcall(function()
	waitFor(function() return #Players:GetPlayers()==2 and Match.GetState()~=nil end,90,"two clients")
	local state=Match.GetState(); assert(state); state.phase="Preparing"; state.preparationEnds=0
	waitFor(function() return state.phase=="InProgress" end,15,"match start")
	state.startedAt=workspace:GetServerTimeNow()+10000; state.nextWaveAt=workspace:GetServerTimeNow()+10000
	require(services.JungleService).Stop(); require(Replicated.Shared.Config.TowerConfig).Range=0; require(services.TowerService).CancelAll()
	local a,b=table.unpack(Players:GetPlayers())
	waitFor(function() return a.Character~=nil and b.Character~=nil and a.Character:GetAttribute("LifeId")~=nil and b.Character:GetAttribute("LifeId")~=nil end,20,"characters")
	task.wait(.3)
	local first=command(a,"inspect")
	check("HUD shows initial point and learn affordance",first.points==1 and first.plus and first.cloneRank==0)
	check("unlearned ability unavailable",first.unlearned~=nil and not Ability.TryCast(a,1,a.Character,"ShadowClones"))
	check("source starting attributes and HP",Stats.Get(a).Strength==16 and Stats.Get(a).Agility==15 and Stats.Get(a).Intelligence==14 and Stats.Get(a).MaxHealth==620)
	local model=a.Character :: Model; local hp=model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local before=hp.Health
	check("derived armor mitigates actual damage",math.abs(Damage.Apply(b.Character :: Model,hp,103)-100)<.001 and math.abs(before-hp.Health-100)<.001)
	local denied,reason=Learning.HandleRequest(b,1,b.Character,(b.Character :: Model):GetAttribute("LifeId"),"Rasengan",state.roundId)
	check("level gate without debit",not denied and reason=="Level" and profile(b).SkillPoints==1)
	local learned=command(a,"learn","ShadowClones")
	check("client controller learns through real remote",learned.cloneRank==1 and learned.points==0)
	check("other Naruto independent",profile(b).SkillPoints==1 and next(profile(b).Learned)==nil)
	local replay,why=Learning.HandleRequest(a,1,a.Character,model:GetAttribute("LifeId"),"ShadowClones",state.roundId)
	check("replayed request never spends twice",not replay and why=="Replay" and profile(a).SkillPoints==0)
	local noForm,formReason=Learning.HandleRequest(b,2,b.Character,(b.Character :: Model):GetAttribute("LifeId"),"KCM",state.roundId)
	check("unimplemented forms cannot consume points",not noForm and formReason=="NotImplemented" and profile(b).SkillPoints==1)
	Progression.AddXP(a,450); task.wait(.2)
	check("multi-level XP grants three points once",profile(a).Level==4 and profile(a).SkillPoints==3)
	check("level-derived health and armor",Stats.Get(a).MaxHealth==700 and math.abs(Stats.Get(a).Defense-3.6)<.001)
	learned=command(a,"learn","Rasengan")
	check("Q learned at level4 via client",learned.qRank==1 and learned.points==2)
	Progression.AddXP(a,100000); local points=profile(a).SkillPoints; Progression.AddXP(a,100000)
	check("cap30 and no duplicate points at cap",profile(a).Level==30 and points==28 and profile(a).SkillPoints==points)
	check("cap primary source growth",Stats.Get(a).Strength==56 and Stats.Get(a).Agility==46 and Stats.Get(a).Intelligence==43 and Stats.Get(a).MaxHealth==1420)
	local changed=command(a,"inspect")
	check("desktop stats text and points replicate",changed.points==28 and string.find(changed.stats,"STR",1,true)~=nil)
	local target=Instance.new("Model"); target.Name="LearningImpactFixture"
	local root=Instance.new("Part"); root.Name="HumanoidRootPart"; root.Anchored=true; root.Size=Vector3.new(2,4,2); root.Position=Vector3.new(0,36,-4); root.Parent=target
	local victim=Instance.new("Humanoid"); victim.MaxHealth=1000; victim.Health=1000; victim.Parent=target
	target.PrimaryPart=root; target:SetAttribute("TeamId",b:GetAttribute("TeamId")); target:SetAttribute("RoundId",state.roundId); target:SetAttribute("EntityKind","Minion"); target.Parent=workspace; Fighters.GetOrCreate(target)
	local ownRoot=model:FindFirstChild("HumanoidRootPart") :: BasePart
	ownRoot:SetNetworkOwner(nil); ownRoot.CFrame=CFrame.new(0,36,0); ownRoot.AssemblyLinearVelocity=Vector3.zero; hp.AutoRotate=false
	check("learned Q admitted",Ability.HandleRequest(a,2,model,"Rasengan",state.roundId))
	waitFor(function() return model:GetAttribute("RasenganPhase")=="Holding" end,3,"Q hold")
	check("explicit attack activates Q",Combat.TryAttack(a,1,model)=="Started")
	task.wait(.2); model:SetAttribute("StrengthBonus",2)
	waitFor(function() return victim.Health<1000 end,2,"Q impact")
	check("impact reads CURRENT level30 STR58",math.abs(victim.Health-(1000-478))<.01)
	check("current bonus updates derived max HP",hp.MaxHealth==1460)
	Fighters.Remove(target); target:Destroy()
	local old=model; local oldLife=model:GetAttribute("LifeId"); hp.Health=0
	waitFor(function() return a.Character~=nil and a.Character~=old and a.Character:GetAttribute("LifeId")~=nil end,12,"respawn")
	check("death preserves level ranks and points",profile(a).Level==30 and profile(a).Learned.Rasengan==1 and profile(a).Learned.ShadowClones==1 and profile(a).SkillPoints==28)
	task.wait(.6)
	local stale,staleReason=Learning.HandleRequest(a,3,old,oldLife,"Rasengan",state.roundId)
	check("old character cannot spend after respawn",not stale and staleReason=="StaleLife" and profile(a).SkillPoints==28)
	local bPoints=profile(b).SkillPoints; state.phase="Finished"
	local stopped=Learning.HandleRequest(b,3,b.Character,(b.Character :: Model):GetAttribute("LifeId"),"ShadowClones",state.roundId)
	check("terminal learning rejected",not stopped and profile(b).SkillPoints==bPoints)
	print("[LearningTests] ALL PASS: "..count.." integration checks"); return "passed"
end,function(message) return debug.traceback(tostring(message),2) end)
if not ok then warn("[LearningTests] FAILED after "..count..": "..tostring(failure)) end
