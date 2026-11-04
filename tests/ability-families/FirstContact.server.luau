--!nocheck
-- Run as a normal Script in a disposable Studio Play session; no timing overrides.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Dev=require(S.DeveloperCommandService)
local Match=require(S.MatchService)
local Fighters=require(S.FighterStateService)
local Combat=require(S.CombatService)
local Naruto=require(S.NarutoAbilityService)
local Damage=require(S.DamageService)
local Hitboxes=require(S.HitboxService)
local Variants=require(game.ReplicatedStorage.Shared.Abilities.RasenganVariants)
local results={}
local function check(name,ok) assert(ok,name);table.insert(results,name);workspace:SetAttribute("FamilyQAResults",game.HttpService:JSONEncode(results)) end
local function waitFor(test,seconds,name)
 local deadline=os.clock()+seconds
 repeat if test() then return end;task.wait(.02) until os.clock()>deadline
 error("Timeout: "..name)
end
local ok,err=xpcall(function()
 waitFor(function() return #game.Players:GetPlayers()==1 and Match.GetState() end,20,"player")
 local p=game.Players:GetPlayers()[1];Dev.Execute(p,"solo")
 waitFor(function() return Match.GetState().phase=="InProgress" and p.Character and Fighters.Get(p.Character) end,30,"match")
 Match.GetState().nextWaveAt=workspace:GetServerTimeNow()+10000;require(S.JungleService).Stop()
 assert(Dev.Execute(p,"level 30"));assert(Dev.Execute(p,"learnall"));assert(Dev.Execute(p,"nocd on"));Dev.Execute(p,"refresh")
 local c=p.Character;local f=Fighters.Get(c);local root=f.root
 local floor=Instance.new("Part");floor.Name="FamilyQAFloor";floor.Anchored=true;floor.Size=Vector3.new(150,2,150);floor.Position=Vector3.new(600,34,600);floor.Parent=workspace
 c:PivotTo(CFrame.new(600,38,600));task.wait(.5)
 local shield=c:FindFirstChildOfClass("ForceField");if shield then shield:Destroy() end
 local target=Instance.new("Model");target.Name="FamilyQATarget";target:SetAttribute("TeamId",if c:GetAttribute("TeamId")=="Blue" then "Red" else "Blue");target:SetAttribute("RoundId",Match.GetState().roundId);target:SetAttribute("EntityKind","Minion")
 local tr=Instance.new("Part");tr.Name="HumanoidRootPart";tr.Size=Vector3.new(2,4,2);tr.Anchored=true;tr.CanCollide=false;tr.Parent=target
 local th=Instance.new("Humanoid");th.MaxHealth=10000;th.Health=10000;th.Parent=target;target.PrimaryPart=tr;target.Parent=workspace;Fighters.GetOrCreate(target)
 check("removed sleep cannot be invoked",not Naruto.TryCast(p,"ShadowSleep",1,workspace:GetServerTimeNow(),target))
 check("targeted clones cannot bypass removed sleep",not Naruto.TryCast(p,"ShadowClones",2,workspace:GetServerTimeNow(),target))
 local lockDistance=5.8
 local tracking=game:GetService("RunService").Heartbeat:Connect(function() if lockDistance then tr.CFrame=root.CFrame*CFrame.new(0,0,-lockDistance) end end)
 local hits={};local conn=Damage.Applied.Event:Connect(function(a,v,amount) if a==c and v==target then table.insert(hits,amount) end end)
 local serial=1000
 for _,variant in {"Rasengan","Odama","Rasenshuriken"} do
  task.wait(2);Dev.Execute(p,"refresh");table.clear(hits);th.Health=10000
  c:PivotTo(CFrame.new(600,38,600));task.wait(.2);tr.CFrame=root.CFrame*CFrame.new(0,0,-5.8)
  check(variant.." target inside M1 but outside old spell gate",table.find(Hitboxes.GetTargets(c,root,f.profile),th)~=nil and (tr.Position-root.Position).Magnitude>5.125)
  serial+=1;local admitted,reason=Naruto.TryCast(p,"Rasengan",serial,workspace:GetServerTimeNow(),nil);assert(admitted,reason)
  if variant~="Rasengan" then serial+=1;local accepted,why=Naruto.TryCast(p,variant,serial,workspace:GetServerTimeNow(),nil);assert(accepted,why) end
  serial+=1;check(variant.." cannot leak ordinary damage during preparation",Combat.TryAttack(p,serial,c)=="Rejected" and #hits==0)
  waitFor(function() return c:GetAttribute("RasenganPhase")=="Holding" and f.logic.mode=="Idle" and workspace:GetServerTimeNow()>(c:GetAttribute("NarutoPausedUntil") or 0) end,6,"prepared")
  serial+=1;check(variant.." first attack starts",Combat.TryAttack(p,serial,c)=="Started")
  waitFor(function() return c:GetAttribute("RasenganPhase")=="Consumed" end,3,"first contact")
  check(variant.." first contact consumes spell without basic damage",#hits==0 and th.Health==10000)
  waitFor(function() return #hits>0 end,3,"spell damage")
  local level,strength=Naruto.GetStats(p)
  local expected=if variant=="Rasenshuriken" then Variants.pulse(strength) else Variants.damage(variant,level,strength)
  check(variant.." first damage equals spell formula",math.abs(hits[1]-expected)<.01)
  if variant=="Rasenshuriken" then task.wait(5) else check(variant.." damage occurs once",#hits==1) end
 end
 task.wait(2);Dev.Execute(p,"refresh");lockDistance=9;tr.CFrame=root.CFrame*CFrame.new(0,0,-9)
 serial+=1;assert(Naruto.TryCast(p,"Rasengan",serial,workspace:GetServerTimeNow(),nil))
 waitFor(function() return c:GetAttribute("RasenganPhase")=="Holding" and f.logic.mode=="Idle" end,5,"miss preparation")
 serial+=1;assert(Combat.TryAttack(p,serial,c)=="Started");task.wait(1)
 check("miss preserves charge",c:GetAttribute("RasenganHeld")==true and c:GetAttribute("RasenganPhase")=="Holding")
 lockDistance=5.8;tr.CFrame=root.CFrame*CFrame.new(0,0,-5.8)
 serial+=1;assert(Combat.TryAttack(p,serial,c)=="Started")
 waitFor(function() return c:GetAttribute("RasenganPhase")=="Consumed" end,3,"retry contact")
 check("first contact after miss consumes charge",true)
 task.wait(2);conn:Disconnect();tracking:Disconnect();target:Destroy()
 workspace:SetAttribute("FamilyQAStatus","PASS")
end,debug.traceback)
if not ok then workspace:SetAttribute("FamilyQAStatus","FAIL");workspace:SetAttribute("FamilyQAError",tostring(err));warn(err) end
