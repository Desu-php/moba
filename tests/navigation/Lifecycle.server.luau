--!strict
-- Test-only mass fixture: production ranks, lifetime and request guards stay unchanged.
assert(game:GetService("RunService"):IsStudio())
local P=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local S=game.ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local N=require(S.NarutoAbilityService)
local U=require(S.NarutoSummonService)
local F=require(S.FighterStateService)
local C=require(RS.Shared.Abilities.CloneCommands)
local W=require(RS.Shared.Abilities.CloneState).configure(require(RS.Shared.Abilities.NarutoDefinitions).Clones)
local checks:{string}={}
local function check(name:string,value:boolean)assert(value,name);table.insert(checks,name);print("[NavigationLifecycle] PASS",name)end
local function waitFor(fn:()->boolean,seconds:number)
 local finish=os.clock()+seconds;repeat if fn()then return end;task.wait(.03)until os.clock()>finish;error("Fixture timeout")
end
local metrics:{[string]:number}={}
local ok,err=xpcall(function()
 local M=require(S.MatchService)
 waitFor(function()return #P:GetPlayers()==2 and M.GetState()~=nil end,60)
 local match=M.GetState();assert(match);match.phase="Preparing";match.preparationEnds=0
 waitFor(function()return match.phase=="InProgress"end,15)
 match.nextWaveAt=workspace:GetServerTimeNow()+10000;match.startedAt=match.nextWaveAt
 require(S.JungleService).Stop();require(RS.Shared.Config.TowerConfig).Range=0;require(S.TowerService).CancelAll()
 local a,b=table.unpack(P:GetPlayers());waitFor(function()return a.Character~=nil and b.Character~=nil and N.Get(a)~=nil and N.Get(b)~=nil end,15)
 local floor=Instance.new("Part");floor.Anchored=true;floor.Size=Vector3.new(180,2,180);floor.Position=Vector3.new(0,999,0);floor.Parent=workspace
 local function target(name:string,team:any,z:number):Model
  local t=Instance.new("Model");t.Name=name;local r=Instance.new("Part");r.Name="HumanoidRootPart";r.Size=Vector3.new(2,2,1);r.Position=Vector3.new(12,1003,z);r.Anchored=true;r.Parent=t;t.PrimaryPart=r
  local h=Instance.new("Humanoid");h.MaxHealth=100000;h.Health=100000;h.Parent=t
  t:SetAttribute("TeamId",team);t:SetAttribute("RoundId",match.roundId);t:SetAttribute("EntityKind","Minion");t.Parent=workspace;F.GetOrCreate(t);return t
 end
 local ta=target("MassTargetA",b:GetAttribute("TeamId"),-18)
 local tb=target("MassTargetB",a:GetAttribute("TeamId"),18)
 local function spawn(p:Player,n:number,z:number,t:Model):{Model}
  local s=N.Get(p);assert(s);local c=p.Character;assert(c);c:PivotTo(CFrame.new(-12,1003,z));local r=c.PrimaryPart;assert(r);r.Anchored=true
  s.clones.burst=nil;s.clones.cooldownAt=0;local now=workspace:GetServerTimeNow();local burst=W.begin(s.clones,now,s.clones.lastRequest+1,n,0);assert(burst)
  local result={};for i=1,n do local clone=W.spawnOne(s.clones,burst,now+i*.02,true,false);assert(clone);local model=U.Spawn(p,c,s.clones,clone,s.commands);assert(model);table.insert(result,model)end
  assert(C.command(s.commands,s.commands.ownerId,match.roundId,s.life,s.commands.lastRequest+1,U.EntityId(t),true));return result
 end
 task.wait(1)
 local ga,gb=spawn(a,30,-18,ta),spawn(b,30,18,tb)
 local frames:{number}={};local connection=game:GetService("RunService").Heartbeat:Connect(function(dt)table.insert(frames,dt)end)
 local first=ga[1];local root=first.PrimaryPart;assert(root);local fighter=F.Get(first);assert(fighter)
 task.wait(.2);F.StunSpell(fighter,.6);task.wait(.05);local frozen=root.Position;task.wait(.3)
 check("stunned moving clone does not resume pending path",(root.Position-frozen).Magnitude<.001)
 task.wait(15.5);connection:Disconnect()
 check("two owners retain sixty production lifetime clones",U.GetCount()==60)
 local minimum=math.huge
 local groups:{{Model}}={ga,gb}
 for _,group in groups do for i=1,#group do for j=i+1,#group do
  local x,y=group[i].PrimaryPart,group[j].PrimaryPart;assert(x and y);minimum=math.min(minimum,(x.Position-y.Position).Magnitude)
 end end end
 check("thirty-clone crowds separate rather than persistent overlap",minimum>=2.25)
 table.sort(frames);metrics.minimumCloneSpacing=minimum;metrics.samples=#frames;metrics.p95HeartbeatMs=frames[math.max(1,math.ceil(#frames*.95))]*1000;metrics.maxHeartbeatMs=(frames[#frames]or 0)*1000
 local sa=N.Get(a);assert(sa);for _,record in sa.clones.clones do record.expiresAt=workspace:GetServerTimeNow() end
 waitFor(function()return U.GetCount()==30 end,1)
 check("expiry removes only owned entities and routes",U.GetCount()==30)
 -- Fresh eight-clone group for follow/assist and owner lifecycle checks.
 U.Reset();gb=spawn(b,8,18,tb);local sb=N.Get(b);assert(sb);C.invalidateTarget(sb.commands,U.EntityId(tb));C.assist(sb.commands,U.EntityId(tb),true)
 check("assist intent uses actual shared commands",C.resolve(sb.commands).mode=="Assist")
 local h=tb:FindFirstChildOfClass("Humanoid");assert(h);h.Health=0;task.wait(.2)
 check("invalid enemy falls back to owner follow",C.resolve(sb.commands).mode=="Follow")
 local character=b.Character;assert(character);local bh=character:FindFirstChildOfClass("Humanoid");assert(bh);bh.Health=0;task.wait(.2)
 local positions:{[Model]:Vector3}={};for _,model in gb do if model.PrimaryPart then positions[model]=model.PrimaryPart.Position end end;task.wait(.3)
 local stopped=true;for model,pos in positions do if model.Parent and model.PrimaryPart and (model.PrimaryPart.Position-pos).Magnitude>.001 then stopped=false end end
 check("owner death leaves no moving orphan route",stopped)
 local bases=require(S.BaseService).GetAll();local team=b:GetAttribute("TeamId");assert(typeof(team)=="string");local base=bases[team];assert(base)
 base.humanoid.Health=0
 waitFor(function()return match.phase=="Finished" and U.GetCount()==0 end,2)
 check("terminal clears all remaining navigation agents",U.GetCount()==0)
 return "passed"
end,function(message)return debug.traceback(tostring(message),2)end)
game:GetService("StudioTestService"):EndTest({suite="NavigationLifecycle",ok=ok,checks=checks,metrics=metrics,error=if ok then nil else err})
