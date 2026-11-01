--!strict
-- Isolated engine geometry fixture. It never unlocks a gameplay rank or changes production config.
assert(game:GetService("RunService"):IsStudio())
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local S=game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match=require(S.MatchService)
local Naruto=require(S.NarutoAbilityService)
local Summons=require(S.NarutoSummonService)
local Fighters=require(S.FighterStateService)
local Commands=require(RS.Shared.Abilities.CloneCommands)
local Clone=require(RS.Shared.Abilities.CloneState)
local W=Clone.configure(require(RS.Shared.Abilities.NarutoDefinitions).Clones)
local count=0
local passed:{string}={}
local function check(name:string,ok:boolean) assert(ok,name);count+=1;table.insert(passed,name);print("[NavigationTests] PASS: "..name) end
local function waitFor(fn:()->boolean,seconds:number,name:string)
 local untilAt=os.clock()+seconds
 repeat if fn() then return end;task.wait(.05) until os.clock()>=untilAt
 error("Timeout: "..name)
end
local ok,err=xpcall(function()
 waitFor(function()return #Players:GetPlayers()==2 and Match.GetState()~=nil end,60,"clients")
 local match=Match.GetState();assert(match);match.phase="Preparing";match.preparationEnds=0
 waitFor(function()return match.phase=="InProgress" end,15,"match")
 match.startedAt=workspace:GetServerTimeNow()+10000;match.nextWaveAt=match.startedAt
 require(S.JungleService).Stop();require(RS.Shared.Config.TowerConfig).Range=0;require(S.TowerService).CancelAll()
 local a,b=table.unpack(Players:GetPlayers())
 waitFor(function()return a.Character~=nil and b.Character~=nil and Naruto.Get(a)~=nil and Naruto.Get(b)~=nil end,15,"heroes")
 print("[NavigationTests] READY for server logpoints")
 waitFor(function()return workspace:GetAttribute("NavigationMetricsReady")==true end,45,"MCP runtime logpoints")
 local function part(name:string,size:Vector3,position:Vector3):Part
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position;p.Anchored=true;p.Parent=workspace;return p
 end
 local floor=part("NavigationTestFloor",Vector3.new(180,2,180),Vector3.new(0,999,0))
 for i,p in {a,b} do
  local c=p.Character;assert(c);local r=c:FindFirstChild("HumanoidRootPart");assert(r and r:IsA("BasePart"));r.Anchored=true
  c:PivotTo(CFrame.new(-20,1003,(i-1)*15))
 end
 local target=Instance.new("Model");target.Name="NavigationEnemy"
 local root=part("HumanoidRootPart",Vector3.new(2,2,1),Vector3.new(12,1003,0));root.Parent=target;target.PrimaryPart=root
 local hp=Instance.new("Humanoid");hp.MaxHealth=100000;hp.Health=100000;hp.Parent=target
 target:SetAttribute("TeamId",b:GetAttribute("TeamId"));target:SetAttribute("EntityKind","Minion");target:SetAttribute("RoundId",match.roundId);target.Parent=workspace
 Fighters.GetOrCreate(target)
 local targetId=Summons.EntityId(target)
 local function spawn(p:Player,n:number,z:number):{Model}
  local session=Naruto.Get(p);assert(session);local c=p.Character;assert(c)
  c:PivotTo(CFrame.new(-12,1003,z));session.clones.burst=nil;session.clones.cooldownAt=0
  local now=workspace:GetServerTimeNow();local burst=W.begin(session.clones,now,session.clones.lastRequest+1,n,0);assert(burst)
  local models={}
  for i=1,n do
   local clone=W.spawnOne(session.clones,burst,now+i*.02,true,false);assert(clone)
   local model=Summons.Spawn(p,c,session.clones,clone,session.commands);assert(model);table.insert(models,model)
  end
  assert(Commands.command(session.commands,session.commands.ownerId,match.roundId,session.life,session.commands.lastRequest+1,targetId,true))
  return models
 end
 local wall=part("NavigationWall",Vector3.new(2,8,12),Vector3.new(0,1004,0))
 task.wait(2) -- allow the real navmesh to observe new test-only geometry
 local models=spawn(a,1,0);local model=models[1];local r=model.PrimaryPart;assert(r)
 local before=hp.Health;local crossed=false;local around=false;local peakStep=0;local previous=r.Position
 local started=os.clock()
 repeat
  task.wait(.05);local pos=r.Position;peakStep=math.max(peakStep,(pos-previous).Magnitude);previous=pos
  if math.abs(pos.X)<2.09 and math.abs(pos.Z)<7.09 then crossed=true end
  if math.abs(pos.Z)>7.1 then around=true end
 until hp.Health<before or os.clock()-started>15
 check("wall body never crosses solid footprint",not crossed)
 check("real navmesh routes around wall and reaches combat",around and hp.Health<before)
 check("no recovery teleport",peakStep<3)
 print("[NavigationTests] METRIC wall seconds",os.clock()-started,"maxSampleStep",peakStep)
 root.Position=Vector3.new(12,1003,-12);started=os.clock()
 waitFor(function()return r.Parent~=nil and (r.Position-root.Position).Magnitude<5.2 end,8,"moving target reapproach")
 check("moving target replaces stale approach",(r.Position-root.Position).Magnitude<5.2)
 Summons.Reset();wall:Destroy()
 root.Position=Vector3.new(12,1003,0)
 task.wait(.3)
 local left=part("DoorLeft",Vector3.new(2,8,17.5),Vector3.new(0,1004,-11.25))
 local right=part("DoorRight",Vector3.new(2,8,17.5),Vector3.new(0,1004,11.25)) -- 5-stud opening
 task.wait(1)
 models=spawn(a,8,0);before=hp.Health;crossed=false;local passed=0;started=os.clock()
 repeat
  task.wait(.1);passed=0
  for _,m in models do local p=m.PrimaryPart;if p then if p.Position.X>2.1 then passed+=1 end;if math.abs(p.Position.X)<2.09 and math.abs(p.Position.Z)>1.41 and math.abs(p.Position.Z)<21.09 then crossed=true end end end
 until passed>=4 or os.clock()-started>17
 check("doorway respects wall clearance",not crossed)
 check("eight-clone doorway makes progress without permanent seal",passed>=4 and hp.Health<before)
 print("[NavigationTests] METRIC doorway passed",passed,"seconds",os.clock()-started)
 Summons.Reset();left:Destroy();right:Destroy();task.wait(.3)
 local enclosure={part("BoxLeft",Vector3.new(1,8,13),Vector3.new(6,1004,0)),part("BoxRight",Vector3.new(1,8,13),Vector3.new(18,1004,0)),part("BoxFront",Vector3.new(13,8,1),Vector3.new(12,1004,-6)),part("BoxBack",Vector3.new(13,8,1),Vector3.new(12,1004,6))}
 task.wait(1);models=spawn(a,8,0);before=hp.Health;task.wait(4)
 check("unreachable enclosure prevents through-wall damage",hp.Health==before)
 enclosure[1]:Destroy();task.wait(.5)
 waitFor(function()return hp.Health<before end,9,"unreachable target becomes reachable")
 check("opening enclosure recovers without teleport",hp.Health<before)
 -- Remove a moving clone while requests/results can still be in flight.
 root.Position=Vector3.new(12,1003,22);task.wait(.1)
 for _,m in models do Summons.Remove(m) end;task.wait(.4)
 local removed=true;for _,m in models do if m.Parent then removed=false end end
 check("removed moving clones cannot resume stale paths",removed and Summons.GetCount()==0)
 for _,p in enclosure do p:Destroy() end;root.Position=Vector3.new(12,1003,0);task.wait(.3)
 -- Both owners use their own hostile target; no gameplay mass rank is enabled.
 local second=target:Clone();second.Name="NavigationEnemyBlue";second:SetAttribute("TeamId",a:GetAttribute("TeamId"));second:SetAttribute("AbilityEntityId",nil);second.Parent=workspace
 second:PivotTo(CFrame.new(12,1003,15));Fighters.GetOrCreate(second);local secondRoot=second.PrimaryPart;assert(secondRoot)
 local targetB=Summons.EntityId(second)
 local groupA=spawn(a,30,-8);local groupB=spawn(b,30,23)
 local nb=Naruto.Get(b);assert(nb);assert(Commands.command(nb.commands,nb.commands.ownerId,match.roundId,nb.life,nb.commands.lastRequest+1,targetB,true))
 check("two owned thirty-clone fixtures exist without rank unlock",Summons.GetCount()==60)
 started=os.clock();local reachedA,reachedB=0,0
 repeat
  task.wait(.2);reachedA=0;reachedB=0
  for _,m in groupA do if m.PrimaryPart and (m.PrimaryPart.Position-root.Position).Magnitude<5 then reachedA+=1 end end
  for _,m in groupB do if m.PrimaryPart and (m.PrimaryPart.Position-secondRoot.Position).Magnitude<5 then reachedB+=1 end end
 until reachedA>=4 and reachedB>=4 or os.clock()-started>17
 check("both mass groups fill independent melee positions",reachedA>=4 and reachedB>=4)
 print("[NavigationTests] METRIC mass60 seconds",os.clock()-started,"melee",reachedA,reachedB)
 Summons.Reset();check("reset removes all navigation-driven entities",Summons.GetCount()==0)
 target:Destroy();second:Destroy();floor:Destroy()
 print("[NavigationTests] ALL PASS: "..count.." checks")
 return "passed"
end,function(message)return debug.traceback(tostring(message),2)end)
if not ok then warn("[NavigationTests] FAILED after "..count..": "..tostring(err)) end
local events={}
for _,entry in game:GetService("LogService"):GetLogHistory() do
 if string.find(entry.message,"[NavigationTests]",1,true) or string.find(entry.message,"[NavPath",1,true) then table.insert(events,{message=entry.message,timestamp=entry.timestamp}) end
end
game:GetService("StudioTestService"):EndTest({suite="Navigation",ok=ok,count=count,passed=passed,events=events,error=if ok then nil else err})
