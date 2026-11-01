--!strict
-- Studio-only preparation and observation. All attacks MUST come from real MCP input.
assert(game:GetService("RunService"):IsStudio(), "BasicAttack manual fixture is Studio-only")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local services=game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match=require(services.MatchService)
local Combat=require(services.CombatService)
local Damage=require(services.DamageService)
local Fighters=require(services.FighterStateService)
local Stats=require(services.CharacterStatsService)
local Progression=require(services.HeroProgressionService)
local Rule=require(RS.Shared.Combat.BasicAttackRules)
repeat task.wait(.05) until #Players:GetPlayers()==2 and Match.GetState()
local match=Match.GetState(); assert(match)
match.phase="Preparing"; match.preparationEnds=0
repeat task.wait(.05) until match.phase=="InProgress"
match.startedAt=workspace:GetServerTimeNow()+10000; match.nextWaveAt=workspace:GetServerTimeNow()+10000
require(RS.Shared.Config.TowerConfig).Range=0; require(services.TowerService).CancelAll()
local AI=require(services.MinionAIService); AI.SetRunning(false); for model in AI.GetAll() do AI.Remove(model) end
local player=Players:GetPlayers()[1]
repeat task.wait(.05) until player.Character and player.Character:GetAttribute("HeroAppearanceVersion")
local model=player.Character; assert(model)
local root=model:FindFirstChild("HumanoidRootPart") :: BasePart
local human=model:FindFirstChildOfClass("Humanoid"); assert(human)
for _,child in model:GetChildren() do
 if child:IsA("ForceField") or (child:IsA("Script") and child.Name=="Health") then child:Destroy() end
end
local objects: {Instance}={}
local prepared=0
local function target(name: string,at: Vector3,ally: boolean?): Model
 local t=Instance.new("Model"); t.Name=name
 local r=Instance.new("Part"); r.Name="HumanoidRootPart"; r.Size=Vector3.new(2,4,2); r.Anchored=true; r.Position=at; r.Color=if ally then Color3.new(.2,.5,1) else Color3.new(1,.2,.2); r.Parent=t
 local h=Instance.new("Humanoid"); h.MaxHealth=10000; h.Health=10000; h.Parent=t; t.PrimaryPart=r
 t:SetAttribute("BasicAttackFixture",true); t:SetAttribute("TeamId",if ally then player:GetAttribute("TeamId") else if player:GetAttribute("TeamId")=="Blue" then "Red" else "Blue")
 t:SetAttribute("EntityKind","Minion"); t:SetAttribute("RoundId",match.roundId); t.Parent=workspace
 Fighters.GetOrCreate(t); table.insert(objects,t); return t
end
local function prepare()
 prepared+=1
 for _,object in objects do object:Destroy() end; table.clear(objects)
 root.Anchored=false; root.CFrame=CFrame.new(0,36,0); root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero; root:SetNetworkOwner(player); human.AutoRotate=true
 local case=tostring(workspace:GetAttribute("BasicAttackCase") or "Front")
 local at=if case=="Behind" then Vector3.new(0,36,4) elseif case=="Side" then Vector3.new(4,36,0) elseif case=="Range" then Vector3.new(0,36,-9) else Vector3.new(0,36,-4)
 local main=target("M1_Main",at)
 if case=="Front" then target("M1_Further",Vector3.new(0,36,-4.8)); target("M1_Ally",Vector3.new(0,36,-2),true) end
 if case=="ForceField" then Instance.new("ForceField").Parent=main end
 if case=="Wall" then
  local wall=Instance.new("Part"); wall.Name="M1_SolidWall"; wall.Anchored=true; wall.Size=Vector3.new(8,8,.5); wall.Position=Vector3.new(0,36,-2); wall.Parent=workspace; table.insert(objects,wall)
 end
 print("[M1Manual] READY",case,"player",player.Name,"generation",prepared,"M1 must be physical MCP input")
end
workspace:SetAttribute("BasicAttackCase","Front")
workspace:GetAttributeChangedSignal("BasicAttackCase"):Connect(prepare)
prepare()
local hits: {[number]: {Model}}={}
local lastStarted=0
Damage.Applied.Event:Connect(function(attacker: Model,victim: Model,amount: number)
 if workspace:GetAttribute("BasicAttackCase")=="Abilities" then return end -- Rasengan is observed separately, not counted as a physical basic hit.
 if attacker~=model or victim:GetAttribute("BasicAttackFixture")~=true then return end
 local fighter=Fighters.Get(model); assert(fighter and fighter.logic.active,"Damage must have a live attack")
 local attack=fighter.logic.active; assert(attack)
 assert(workspace:GetServerTimeNow()>=attack.hitAt,"Damage before windup")
 local list=hits[attack.id]; assert(list,"Unobserved attack")
 assert(#list==0,"One M1 damaged multiple targets")
 table.insert(list,victim)
 print("[M1Manual] DAMAGE",attack.id,victim.Name,amount,"after",workspace:GetServerTimeNow()-attack.startedAt)
end)
Combat.AttackStarted.Event:Connect(function(fighter: Fighters.Fighter)
 if workspace:GetAttribute("BasicAttackCase")=="Abilities" then return end
 if fighter.character~=model then return end
 local attack=fighter.logic.active; assert(attack and attack.step==1,"Escalating combo returned")
 local speed=Rule.speed(fighter.profile,Stats.Get(player).Agility)
 assert(attack.startedAt+0.002>=lastStarted+fighter.profile.AttackCooldown/speed,"Attack rate bypass")
 lastStarted=attack.startedAt; hits[attack.id]={}
 local epoch=prepared; local case=workspace:GetAttribute("BasicAttackCase")
 print("[M1Manual] START",attack.id,"windup",attack.hitAt-attack.startedAt,"interval",fighter.profile.AttackCooldown/speed)
 task.delay(attack.endsAt-attack.startedAt+.05,function()
  if epoch~=prepared then return end
  local list=hits[attack.id]; assert(list)
  if case=="Front" then assert(#list==1 and list[1].Name=="M1_Main","Expected nearest valid aimed enemy")
  elseif case=="Wall" or case=="Behind" or case=="Side" or case=="Range" or case=="ForceField" then assert(#list==0,"Blocked/invalid target was hit") end
  print("[M1Manual] PASS",case,attack.id,"hits",#list)
 end)
end)
-- Optional case: set BasicAttackCase to HighAgility, then use real M1 and compare logs.
workspace:GetAttributeChangedSignal("BasicAttackCase"):Connect(function()
 if workspace:GetAttribute("BasicAttackCase")=="HighAgility" then Progression.AddXP(player,100000) end
end)
-- Combined UI fixture setup only: no attacks/casts/learning are manufactured here.
workspace:GetAttributeChangedSignal("CombinedLearningSetup"):Connect(function()
 if workspace:GetAttribute("CombinedLearningSetup")~=true then return end
 local rules=require(RS.Shared.Game.ProgressionRules).configure(require(RS.Shared.Config.ProgressionConfig),require(RS.Shared.Config.ItemConfig).Items)
 for index,p in Players:GetPlayers() do
  local profile=Progression.Get(p);assert(profile)
  while profile.Level<(if p==player then 10 else 6) do Progression.AddXP(p,rules.required(profile.Level))end
  if p~=player and p.Character then p.Character:PivotTo(CFrame.new(12,36,-12))end
 end
 print("[M1Manual] READY combined learning; use real Ctrl4/2, ability/learn icons and F")
end)
