--!nocheck
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local A=require(S.SasukeAbilityService);local Summons=require(S.SasukeSummonService)
local D=require(S.DamageService);local F=require(S.FighterStateService);local Dev=require(S.DeveloperCommandService)
local Match=require(S.MatchService);local Stats=require(S.CharacterStatsService)
local created={};local count=0;local connection
workspace:SetAttribute("AodaModelQA",nil)
local function now()return workspace:GetServerTimeNow()end
local function check(name,value)assert(value,name);count+=1;print("[AodaModelQA] PASS "..name)end
local function waitFor(fn,seconds)local untilAt=os.clock()+seconds;repeat if fn()then return end;task.wait(.1)until os.clock()>untilAt;error("Wait timed out")end
local ok,err=xpcall(function()
 waitFor(function()return Match.GetState() and #game.Players:GetPlayers()>0 end,20)
 workspace:SetAttribute("DeveloperSoloMode",true);waitFor(function()return Match.GetState().phase=="InProgress" end,45)
 Match.GetState().nextWaveAt=now()+10000;require(S.MinionAIService).Reset();require(S.JungleService).Stop()
 require(game.ReplicatedStorage.Shared.Config.TowerConfig).Range=0;require(S.TowerService).CancelAll()
 local p=game.Players:GetPlayers()[1];p:SetAttribute("HeroId","Sasuke");p:LoadCharacterAsync()
 waitFor(function()return p.Character and string.find(p.Character:GetAttribute("HeroAppearanceVersion") or "","Sasuke") and require(S.NarutoAbilityService).Get(p) end,20)
 Dev.Execute(p,"level 30");Dev.Execute(p,"learnall");Dev.Execute(p,"nocd on");task.wait(.3);Dev.Execute(p,"refresh")
 local m=p.Character;local r=m.HumanoidRootPart
 for _,v in m:GetChildren()do if v:IsA("ForceField")then v:Destroy()end end
 r:SetNetworkOwner(nil);r.CFrame=CFrame.new(-275,36,0);r.AssemblyLinearVelocity=Vector3.zero;task.wait(.4)
 local home=r.CFrame
 local function body(name,offset,allied)
  local t=Instance.new("Model");t.Name=name
  local tr=Instance.new("Part");tr.Name="HumanoidRootPart";tr.Anchored=true;tr.CanCollide=false;tr.Size=Vector3.new(2,4,2);tr.CFrame=home*CFrame.new(offset);tr.Parent=t;t.PrimaryPart=tr
  local h=Instance.new("Humanoid");h.RequiresNeck=false;h.MaxHealth=50000;h.Health=50000;h.Parent=t
  t:SetAttribute("TeamId",if allied then p:GetAttribute("TeamId") else if p:GetAttribute("TeamId")=="Blue" then "Red" else "Blue")
  t:SetAttribute("EntityKind","Minion");t:SetAttribute("RoundId",Match.GetState().roundId);t.Parent=workspace;F.GetOrCreate(t);table.insert(created,t);return t
 end
 local ally=body("AodaQA_Ally",Vector3.new(8,0,0),true);local enemy=body("AodaQA_Enemy",Vector3.new(8,0,-8),false)
 local function cast(id,target)Dev.Execute(p,"refresh");return A.TryCast(p,id,1,now(),target)end
 check("Aoda summoned",Summons.Spawn(m,p,6,r.Position+Vector3.new(8,0,0)))
 local snake=Summons.Get(m);snake.untilAt=now()+1000;snake.target=enemy;snake.nextTarget=math.huge;snake.poisonAt=math.huge;snake.attackAt=now()+.5
 check("single skinned mesh",snake.model:FindFirstChild("AodaSkin") and not snake.model:FindFirstChild("SerpentBody"))
 local bones=0;for _,v in snake.model.AodaSkin:GetDescendants()do if v:IsA("Bone")then bones+=1 end end
 check("31 deform bones",bones==31)
 check("skin cannot block combat",not snake.model.AodaSkin.CanQuery and not snake.model.AodaSkin.CanCollide)
 local health=enemy.Humanoid.Health
 waitFor(function()return snake.pendingBite~=nil end,3)
 check("strike carries visual reach",(snake.model:GetAttribute("AodaStrikeDistance") or 0)>0)
 check("bite windup has no instant damage",enemy.Humanoid.Health==health)
 task.wait(.08);check("bite still winds up",enemy.Humanoid.Health==health)
 task.wait(.22);check("bite impact applies damage",enemy.Humanoid.Health<health)
 snake.attackAt=now()+.2;health=enemy.Humanoid.Health
 waitFor(function()return snake.pendingBite~=nil end,3)
 snake.model:SetAttribute("CombatStunUntil",now()+1)
 task.wait(.3);check("stun cancels pending bite",enemy.Humanoid.Health==health and snake.pendingBite==nil)
 task.wait(.8);snake.attackAt=now()+.2;health=enemy.Humanoid.Health
 waitFor(function()return snake.pendingBite~=nil end,3)
 enemy:PivotTo(enemy.PrimaryPart.CFrame*CFrame.new(0,0,-1000))
 task.wait(.3);check("escaped victim is not hit",enemy.Humanoid.Health==health)
 snake.model:SetAttribute("CombatStunUntil",0);enemy:PivotTo(snake.root.CFrame*CFrame.new(0,0,-7));snake.attackAt=now()+.2
 waitFor(function()return snake.pendingBite~=nil end,3)
 check("guard command accepted",Summons.Command(m,ally,now()))
 check("guard cancels bite windup",snake.pendingBite==nil)
end,debug.traceback)
Summons.Reset();for _,m in created do m:Destroy()end
workspace:SetAttribute("AodaModelQA",if ok then "PASS" else tostring(err));workspace:SetAttribute("AodaModelChecks",count)
print("[AodaModelQA]",if ok then "PASS" else "FAIL",count,err);script:Destroy()
