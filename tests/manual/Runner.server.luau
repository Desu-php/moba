assert(game:GetService("RunService"):IsStudio(), "Manual fixture is Studio-only")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match = require(services.MatchService)
repeat task.wait(.1) until Match.GetState() and Match.GetState().phase == "InProgress"
local state = Match.GetState(); state.startedAt = workspace:GetServerTimeNow()+10000; state.nextWaveAt = workspace:GetServerTimeNow()+10000
require(RS.Shared.Config.TowerConfig).Range = 0
require(services.TowerService).CancelAll()
local AI = require(services.MinionAIService); AI.SetRunning(false); for model in AI.GetAll() do AI.Remove(model) end
for index,p in Players:GetPlayers() do
 repeat task.wait(.1) until p.Character and p.Character:GetAttribute("HeroAppearanceVersion")
 local native=require(services.NarutoAbilityService).Get(p); assert(native)
 for _,child in p.Character:GetChildren() do if child:IsA("Script") and child.Name=="Health" then child:Destroy() end end -- Isolate level healing from default passive regeneration.
 local beforeMana=native.pool.mana; local beforeHealth=p.Character.Humanoid.Health
 require(services.HeroProgressionService).AddXP(p,450)
 local deadline=os.clock()+1; repeat task.wait(.01) until native.pool.maximum==1555 or os.clock()>=deadline
 assert(math.abs(native.pool.mana-beforeMana)<1 and native.pool.maximum==1555,"Level-up unexpectedly refilled mana")
 assert(p.Character.Humanoid.Health==math.min(p.Character.Humanoid.MaxHealth,beforeHealth+30),"Unexpected HP level-up healing")
 print("[LearningGrowth] PASS HP/MP capacity update without refill",p.Name,beforeMana,native.pool.mana,p.Character.Humanoid.Health,p.Character.Humanoid.MaxHealth)
 local c=p.Character; c:PivotTo(CFrame.new((index-1)*12,36,0)); c.HumanoidRootPart:SetNetworkOwner(p)
 local t=Instance.new("Model"); t.Name="ManualEnemy"..p.Name
 local r=Instance.new("Part"); r.Name="HumanoidRootPart"; r.Size=Vector3.new(4,5,3); r.Anchored=true; r.Color=Color3.new(1,.2,.2); r.CFrame=CFrame.new((index-1)*12,36,-5); r.Parent=t
 local h=Instance.new("Humanoid"); h.MaxHealth=10000; h.Health=10000; h.Parent=t; t.PrimaryPart=r
 t:SetAttribute("TeamId",if p:GetAttribute("TeamId")=="Blue" then "Red" else "Blue"); t:SetAttribute("EntityKind","Minion"); t:SetAttribute("RoundId",state.roundId); t.Parent=workspace
 require(services.FighterStateService).GetOrCreate(t)
end
local participants=Players:GetPlayers()
local a,b=participants[1],participants[2]
assert(a and b)
local learning=require(services.AbilityLearningService)
local profile=require(services.HeroProgressionService).Get(b); assert(profile)
local before=profile.SkillPoints
local c=b.Character; local life=c:GetAttribute("LifeId")
local ok,reason=learning.HandleRequest(b,1,c,life,"Rasengan",state.roundId,9999)
assert(not ok and reason=="Malformed","Client extra fields must fail")
ok,reason=learning.HandleRequest(b,2,a.Character,a.Character:GetAttribute("LifeId"),"ShadowClones",state.roundId)
assert(not ok and reason=="StaleLife","Other hero must fail")
ok,reason=learning.HandleRequest(b,3,c,life,"ShadowClones",state.roundId-1)
assert(not ok and reason=="StaleLife","Stale epoch must fail")
ok,reason=learning.HandleRequest(b,4,c,life,"Fake",state.roundId)
assert(not ok and reason=="UnknownAbility","Unknown line must fail")
ok,reason=learning.HandleRequest(b,5,c,life,"ShadowClones",state.roundId)
assert(not ok and reason=="RateLimited" and profile.SkillPoints==before and next(profile.Learned)==nil,"Flood cannot mutate progression")
print("[LearningAdmission] ALL PASS: 5 boundary checks; use Player1 for physical learning controls")
print("[ManualUI] Ready: press Q/1, walk with W, use2 for clones and F/HUD command")
