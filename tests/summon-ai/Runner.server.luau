--!nocheck
-- Single-player Studio integration fixture. Run as a normal Script, not MCP require.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Dev=require(S.DeveloperCommandService)
local Match=require(S.MatchService)
local N=require(S.NarutoAbilityService)
local G=require(S.GamakichiService)
local F=require(S.FighterStateService)
local D=require(S.DamageService)
local C=require(S.CombatService)
local results={}
local function check(name,ok) assert(ok,name);table.insert(results,name);workspace:SetAttribute("SummonSwipeResults",game.HttpService:JSONEncode(results)) end
local function waitFor(fn,seconds,name) local deadline=os.clock()+seconds;repeat if fn() then return end;task.wait(.02) until os.clock()>deadline;error("Timeout "..name) end
local ok,err=xpcall(function()
 waitFor(function() return #game.Players:GetPlayers()==1 and Match.GetState() end,20,"player")
 local p=game.Players:GetPlayers()[1];Dev.Execute(p,"solo")
 waitFor(function() return Match.GetState().phase=="InProgress" and p.Character and F.Get(p.Character) end,25,"match")
 Dev.Execute(p,"level 30");Dev.Execute(p,"learnall");Dev.Execute(p,"refresh");Dev.Execute(p,"nocd off")
 require(S.JungleService).Stop();Match.GetState().nextWaveAt=workspace:GetServerTimeNow()+10000
 local c=p.Character;local f=F.Get(c);local root=f.root;local enemyTeam=if c:GetAttribute("TeamId")=="Blue" then "Red" else "Blue"
 local floor=Instance.new("Part");floor.Name="SummonQA_Grass";floor.Anchored=true;floor.Material=Enum.Material.Grass;floor.Size=Vector3.new(160,2,160);floor.Position=Vector3.new(600,34,600);floor.Parent=workspace
 c:PivotTo(CFrame.new(600,38,600));task.wait(.3)
 local shield=c:FindFirstChildOfClass("ForceField");if shield then shield:Destroy() end
 local wall=Instance.new("Part");wall.Name="SummonQA_SpawnWall";wall.Size=Vector3.new(4,14,5);wall.Anchored=true;wall.CFrame=root.CFrame*CFrame.new(8,0,0);wall.Parent=workspace
 assert(N.TryCast(p,"Gamakichi",1,workspace:GetServerTimeNow(),nil));local g=G.Get(p);assert(g)
 local over=OverlapParams.new();over.FilterType=Enum.RaycastFilterType.Include;over.FilterDescendantsInstances={wall,floor}
 check("spawn avoids wall and grass floor overlap",#workspace:GetPartBoundsInBox(g.root.CFrame,Vector3.new(7,4.2,7),over)==0)
 check("skinned Blender toad instantiated",g.model:FindFirstChild("GamakichiSkin"):IsA("MeshPart") and g.model:GetAttribute("GamakichiVisualVersion")==3)
 wall:Destroy();local before=g.root.Position;c:PivotTo(c:GetPivot()+Vector3.new(22,0,0))
 waitFor(function() return (g.root.Position-before).Magnitude>3 end,5,"grass siege")
 check("toad moves on grass toward enemy tower",true)
 local session=N.Get(p)
 assert(N.TryCast(p,"CloneCommand",2,workspace:GetServerTimeNow(),"Hold"))
 local priorY=g.root.Position.Y;g.model:PivotTo(g.model:GetPivot()+Vector3.new(0,12,0))
 waitFor(function() return math.abs(g.root.Position.Y-priorY)<.15 end,4,"gravity while holding")
 check("airborne Hold settles on ground",g.model:GetAttribute("SummonGrounded")==true)
 local models={}
 local function dummy(name,pos,team)
  local m=Instance.new("Model");m.Name=name;m:SetAttribute("TeamId",team or enemyTeam);m:SetAttribute("EntityKind","Minion");m:SetAttribute("RoundId",Match.GetState().roundId)
  local r=Instance.new("Part");r.Name="HumanoidRootPart";r.Size=Vector3.new(2,4,2);r.Anchored=true;r.CanCollide=false;r.Position=pos;r.Parent=m
  local h=Instance.new("Humanoid");h.MaxHealth=10000;h.Health=10000;h.Parent=m;m.PrimaryPart=r;m.Parent=workspace;F.GetOrCreate(m);table.insert(models,m);return m,h,r
 end
 local target,h,tr=dummy("AutoSpellEnemy",g.root.Position+Vector3.new(0,0,-18))
 task.wait(.4);check("Hold prevents autonomous spells",g.spells.serial==0 and h.Health==10000)
 assert(N.TryCast(p,"CloneCommand",3,workspace:GetServerTimeNow(),"Follow"))
 waitFor(function() return (target:GetAttribute("OilUntil") or 0)>workspace:GetServerTimeNow() end,10,"autonomous oil")
 check("autonomous oil slows enemy",target:GetAttribute("OilMoveMultiplier")==.6)
 waitFor(function() return h.Health<10000 end,8,"autonomous chop")
 check("adult casts chopping after oil",g.spells.chopReady>workspace:GetServerTimeNow())
 assert(N.TryCast(p,"CloneCommand",4,workspace:GetServerTimeNow(),"Hold"));task.wait(.15);local hp=h.Health;task.wait(1.2)
 check("Hold interrupts remaining channel waves",h.Health==hp and not g.spells.channel)
 local admitted,reason=G.TrySpell(p,"GamakichiOil",1,workspace:GetServerTimeNow(),target)
 check("AI does not consume manual request sequence",not admitted and reason=="Cooldown")
 local _,replay=G.TrySpell(p,"GamakichiOil",1,workspace:GetServerTimeNow(),target)
 check("manual replay still rejected",replay=="Replay")
 local struck=false;local hitWatch=D.Applied.Event:Connect(function(source,victim,amount) if source==g.model and victim==target and math.abs(amount-101)<.01 then struck=true end end)
 assert(N.TryCast(p,"CloneCommand",5,workspace:GetServerTimeNow(),"Follow"))
 waitFor(function() return struck end,8,"autonomous basic attack during spell cooldown")
 check("toad uses basic attacks between spells",struck);hitWatch:Disconnect()
 G.Remove(p);for _,m in models do m:Destroy() end;table.clear(models)
 Dev.Execute(p,"rikudo");assert(require(S.NarutoKcmService).TryCast(p,"KcmCancel",1001,workspace:GetServerTimeNow(),nil))
 waitFor(function() return require(S.NarutoKcmService).MeditationForm(p)=="Ordinary" end,4,"KCM exit tick")
 local K=require(S.NarutoKuramaService)
 assert(K.TryCast(p,1002,workspace:GetServerTimeNow(),nil))
 assert(K.ObserveBuff(p,c:GetAttribute("LifeId"),Match.GetState().roundId,c:GetAttribute("KuramaCastId"),true))
 c:PivotTo(CFrame.new(600,38,600));task.wait(.4)
 local grid={}
 for _,x in {-12,-8,-4,0,4,8,12} do for _,z in {-4,-8,-12,-16} do
  local m,hu=dummy("Swipe_"..x.."_"..z,(root.CFrame*CFrame.new(x,0,z)).Position);grid[m]=hu
 end end
 local behind,bh=dummy("Behind",(root.CFrame*CFrame.new(0,0,18)).Position)
 local far,fh=dummy("TooFar",(root.CFrame*CFrame.new(0,0,-32)).Position)
 local ally,ah=dummy("Ally",(root.CFrame*CFrame.new(4,0,-8)).Position,c:GetAttribute("TeamId"))
 local protected,ph=dummy("Shielded",(root.CFrame*CFrame.new(8,0,-8)).Position);Instance.new("ForceField",protected)
 local stats=require(S.CharacterStatsService).Get(p);local expected=f.profile.Damage*stats.AttackDamageMultiplier+stats.AttackDamageBonus
 local counts={};local connection=D.Applied.Event:Connect(function(a,v,amount) if a==c and math.abs(amount-expected)<.01 then counts[v]=(counts[v] or 0)+1 end end)
 check("giant sweep starts",C.TryAttack(p,9001,c)=="Started")
 task.wait(1.5)
 local n=0;for m,count in counts do check("one hit per touched target "..m.Name,count==1);check("confirmed paw reaction "..m.Name,typeof(m:GetAttribute("PawHitAt"))=="number");n+=1 end
 workspace:SetAttribute("KuramaSweepVictims",n)
 check("one paw swing damages multiple enemies",n>=3)
 check("sweep excludes behind far allies and shields",not counts[behind] and not counts[far] and not counts[ally] and not counts[protected])
 -- Verify terrain occlusion independently of the ordinary front box.
 local Sweep=require(S.KuramaSwipeService);local shape=require(game.ReplicatedStorage.Shared.Config.KuramaAvatarConfig)
 local block=Instance.new("Part");block.Size=Vector3.new(60,35,1);block.Anchored=true;block.CFrame=root.CFrame*CFrame.new(0,0,-2);block.Parent=workspace
 check("solid wall blocks swept contact",#Sweep.Targets(c,root.CFrame,root.CFrame,shape.SwipeStart,shape.SwipeEnd,1,workspace:GetServerTimeNow())==0);block:Destroy()
 for _,m in models do m:Destroy() end;connection:Disconnect()
 workspace:SetAttribute("SummonSwipeStatus","PASS")
end,debug.traceback)
if not ok then workspace:SetAttribute("SummonSwipeStatus","FAIL");workspace:SetAttribute("SummonSwipeError",tostring(err));warn(err) end
