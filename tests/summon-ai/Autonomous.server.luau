--!nocheck
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Dev=require(S.DeveloperCommandService)
local Match=require(S.MatchService)
local G=require(S.GamakichiService)
local F=require(S.FighterStateService)
local Structures=require(S.StructureService)
local Shared=game.ReplicatedStorage.Shared
local Domain=require(Shared.Abilities.GamakichiState)
local Commands=require(Shared.Abilities.CloneCommands)
local results={}
local function check(name,ok) assert(ok,name);table.insert(results,name);workspace:SetAttribute("GamaAutonomyResults",game.HttpService:JSONEncode(results)) end
local function waitFor(fn,seconds,name) local untilAt=os.clock()+seconds;repeat if fn() then return end;task.wait(.03) until os.clock()>untilAt;error("Timeout "..name) end
local ok,err=xpcall(function()
 waitFor(function() return #game.Players:GetPlayers()==1 and Match.GetState() end,20,"player")
 local p=game.Players:GetPlayers()[1];Dev.Execute(p,"solo")
 waitFor(function() return Match.GetState().phase=="InProgress" and p.Character and F.Get(p.Character) end,25,"match")
 require(S.JungleService).Stop();Match.GetState().nextWaveAt=workspace:GetServerTimeNow()+10000
 Dev.Execute(p,"level 30");Dev.Execute(p,"learnall");Dev.Execute(p,"nocd off");Dev.Execute(p,"refresh")
 local c=p.Character;local enemyTeam=if c:GetAttribute("TeamId")=="Blue" then "Red" else "Blue"
 local floor=Instance.new("Part");floor.Name="AutonomyGrass";floor.Anchored=true;floor.Size=Vector3.new(340,2,340);floor.Position=Vector3.new(600,34,600);floor.Material=Enum.Material.Grass;floor.Parent=workspace
 c:PivotTo(CFrame.new(600,38,600));task.wait(.3)
 local shield=c:FindFirstChildOfClass("ForceField");if shield then shield:Destroy() end
 local state=Domain.new();local cast=assert(Domain.request(state,workspace:GetServerTimeNow(),1,10,10000));cast.expiresAt=workspace:GetServerTimeNow()+600
 local commands=Commands.new(tostring(p.UserId),c:GetAttribute("RoundId"),c:GetAttribute("LifeId"))
 G.Spawn(p,c,state,cast,commands);local g=G.Get(p);g.spells.oilReady=math.huge;g.spells.chopReady=math.huge
 local function dummy(name,pos,kind,team)
  local m=Instance.new("Model");m.Name=name;m:SetAttribute("EntityKind",kind);m:SetAttribute("TeamId",team or enemyTeam);m:SetAttribute("RoundId",c:GetAttribute("RoundId"))
  local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.CanCollide=false;root.Size=Vector3.new(4,4,4);root.Position=pos;root.Parent=m
  local h=Instance.new("Humanoid");h.RequiresNeck=false;h.MaxHealth=10000;h.Health=10000;h.Parent=m;m.PrimaryPart=root;m.Parent=workspace
  if kind=="Tower" then Structures.Register(m) else F.GetOrCreate(m) end
  return m,h
 end
 local tower,th=dummy("AutonomyTower",g.root.Position+Vector3.new(0,0,-24),"Tower")
 local skin=g.model:FindFirstChild("GamakichiSkin")
 check("Blender mesh replaces primitive model",skin and skin:IsA("MeshPart") and g.model:GetAttribute("GamakichiVisualVersion")==3)
 local count=0;for _,b in skin:GetDescendants() do if b:IsA("Bone") then count+=1 end end
 check("complete 16-bone rig",count==16)
 c:PivotTo(CFrame.new(700,38,660))
 waitFor(function() return g.model:GetAttribute("SummonBehavior")=="Siege" end,4,"tower choice")
 check("tower chosen independently of distant owner",g.model:GetAttribute("SummonTarget")==tower.Name and not g.returning)
 waitFor(function() return th.Health<10000 end,6,"tower hit")
 check("tower receives summon basic damage",math.abs(10000-th.Health-101)<.01)
 check("tower never receives unit spells",g.spells.serial==0)
 local unit,uh=dummy("AutonomyUnit",g.root.Position+Vector3.new(7,0,0),"Minion")
 waitFor(function() return g.model:GetAttribute("SummonTarget")==unit.Name end,2,"unit priority")
 check("nearby unit preempts tower",g.model:GetAttribute("SummonBehavior")=="Attack")
 waitFor(function() return uh.Health<10000 end,5,"unit hit")
 local face=(unit.PrimaryPart.Position-g.root.Position)*Vector3.new(1,0,1)
 check("faces enemy instead of Naruto",g.root.CFrame.LookVector:Dot(face.Unit)>.95)
 F.Remove(unit);unit:Destroy()
 waitFor(function() return g.model:GetAttribute("SummonTarget")==tower.Name end,2,"siege resumes")
 check("returns to tower after enemy dies",true)
 assert(Commands.order(commands,commands.ownerId,commands.round,commands.life,1,"Hold"));task.wait(.3)
 local before=g.root.Position;local hp=th.Health;task.wait(1)
 check("Hold stops movement and attacks",(g.root.Position-before).Magnitude<.1 and th.Health==hp)
 c:PivotTo(CFrame.new(g.root.Position+Vector3.new(20,2,12)))
 assert(Commands.order(commands,commands.ownerId,commands.round,commands.life,2,"Follow"))
 waitFor(function() return g.returning end,1,"explicit recall")
 waitFor(function() return not g.returning end,6,"recall completes")
 check("explicit recall ends and autonomy resumes",true)
 g.spells.oilReady=0;g.spells.chopReady=0
 Dev.Execute(p,"nocd on")
 local casts={GamakichiOil={},GamakichiChop={}}
 local connection=g.model:GetAttributeChangedSignal("SummonSpellAt"):Connect(function()
  local id=g.model:GetAttribute("SummonSpell")
  if casts[id] then table.insert(casts[id],g.model:GetAttribute("SummonSpellAt")) end
 end)
 local caster,ch=dummy("AutonomySpellTarget",g.root.Position+Vector3.new(0,0,-15),"Minion")
 waitFor(function() return (caster:GetAttribute("OilUntil") or 0)>workspace:GetServerTimeNow() end,6,"automatic oil")
 waitFor(function() return ch.Health<10000 end,8,"automatic chop")
 check("autonomous oil and chopping remain functional",g.spells.chopReady>workspace:GetServerTimeNow())
 local oilReady,chopReady=g.spells.oilReady,g.spells.chopReady
 task.wait(1)
 check("hero nocd preserves summon cooldowns and HUD",g.spells.oilReady==oilReady and g.spells.chopReady==chopReady
  and c:GetAttribute("Ready_GamakichiOil")==oilReady and c:GetAttribute("Ready_GamakichiChop")==chopReady)
 waitFor(function() return #casts.GamakichiOil>=2 and #casts.GamakichiChop>=2 end,35,"second normal spell cycle")
 check("automatic oil waits at least 25 seconds",casts.GamakichiOil[2]-casts.GamakichiOil[1]>=25)
 check("automatic chopping waits at least 30 seconds",casts.GamakichiChop[2]-casts.GamakichiChop[1]>=30)
 connection:Disconnect()
 Dev.Execute(p,"refresh")
 check("explicit refresh still resets summon spells once",g.spells.oilReady==0 and g.spells.chopReady==0)
 Dev.Execute(p,"nocd off")
 workspace:SetAttribute("GamaAutonomyStatus","PASS")
end,debug.traceback)
if not ok then workspace:SetAttribute("GamaAutonomyStatus","FAIL");workspace:SetAttribute("GamaAutonomyError",err);warn(err) end
