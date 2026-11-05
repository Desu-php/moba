--!nocheck
-- Run in Studio Edit: isolated module and scene, deterministic simulation clock.
local clone=game.ServerScriptService.Server.Services.SasukeAdvancedService:Clone()
clone.Name="AdvancedMechanicsQA";clone.Parent=game.ServerScriptService
local scene=Instance.new("Folder");scene.Name="AdvancedMechanicsQA";scene.Parent=workspace
local count=0
local function check(name,ok) assert(ok,name);count+=1 end
local ok,result=xpcall(function()
 local A=require(clone);local actors={};local damage={};local events={}
 local function body(name,x,z,kind)
  local m=Instance.new("Model");m.Name=name;m:SetAttribute("EntityKind",kind or "Minion")
  local r=Instance.new("Part");r.Name="HumanoidRootPart";r.Anchored=true;r.CanCollide=false;r.Size=Vector3.new(2,4,2);r.Position=Vector3.new(x,1000,z);r.Parent=m;m.PrimaryPart=r;m.Parent=scene
  actors[m]=true;damage[m]=0;return m
 end
 local owner=body("Owner",0,0);local target=body("Target",0,-15);local bystander=body("Bystander",0,-16);local structure=body("Structure",0,-15,"Tower")
 local s={model=owner,player={},form=3,alive=true,pendingUntil=0}
 local fighter={logic={mode="Idle"}};local lock=0
 local function root(m) return m:FindFirstChild("HumanoidRootPart") end
 A.Configure({actors=actors,valid=function(state) return state.alive end,root=root,stats=function() return {Agility=56} end,
  canDamage=function(a,b) return a~=b end,fighter=function() return fighter end,lease=function() end,lock=function(_,untilAt) lock=untilAt end,
  hurt=function(_,m,amount) damage[m]+=amount;return amount end,
  emit=function(_,id,point,radius,duration,extra) events[id]={point=point,radius=radius,duration=duration,extra=extra} end,
  terrain=function() local p=RaycastParams.new();p.FilterDescendantsInstances={owner,target,bystander,structure};p.RespectCanCollide=true;return p end})
 A.Kirin(s,target,1000,100);check("Kirin locks 2.5 seconds",lock==102.5)
 A.UpdateCast(s,101.49);check("Kirin has no early damage",damage[target]==0)
 root(target).Position+=Vector3.new(60,0,0);root(structure).Position=root(target).Position
 A.UpdateCast(s,101.5);check("Kirin locks current target position",events.Kirin.point==root(target).Position)
 A.UpdateCast(s,101.6);check("Kirin first pulse is fifty percent",damage[target]==500)
 check("Kirin abandoned location is safe",damage[bystander]==0)
 check("Kirin excludes structures",damage[structure]==0)
 A.UpdateCast(s,101.7);check("Kirin second pulse is five percent",math.abs(damage[target]-550)<.001)
 for i=2,9 do A.UpdateCast(s,101.6+i*.1) end
 check("Kirin ten pulses total exactly full damage",math.abs(damage[target]-1000)<.001 and s.advanced==nil)
 A.UpdateCast(s,110);check("Kirin cannot repeat after completion",damage[target]==1000)
 A.Kirin(s,target,1000,120);fighter.logic.mode="Stunned";A.UpdateCast(s,120.1)
 check("control cancels Kirin and unlocks caster",s.advanced==nil and lock==0 and events.KirinCancel~=nil)
 fighter.logic.mode="Idle";A.UpdateCast(s,125);check("cancelled Kirin has no delayed hit",damage[target]==1000)
 A.Kirin(s,target,1000,130);s.alive=false;A.UpdateCast(s,131.6);check("death cancels pending Kirin",damage[target]==1000 and s.advanced==nil);s.alive=true
 root(target).Position=Vector3.new(0,1000,-10);root(bystander).Position=Vector3.new(0,1000,-80);root(structure).Position=root(target).Position
 damage[target]=0;s.nagashiUntil=204;s.nagashiTick=200.05
 A.Nagashi(s,200.01);check("Nagashi waits initial 0.05 seconds",damage[target]==0)
 local p=root(target).Position;A.Nagashi(s,200.1)
 check("Nagashi continuous damage follows source rate",math.abs(damage[target]-56*.05/.96)<.001)
 check("Nagashi pushes outward",root(target).Position.Z<p.Z)
 check("Nagashi excludes structures",damage[structure]==0)
 local before=damage[target];A.Nagashi(s,205);check("Nagashi expires",damage[target]==before)
 damage[target]=0;root(target).Position=Vector3.new(0,1000,-20)
 A.Pull(s,210,56);A.UpdateCast(s,210.1)
 check("Enton attracts before hitting",root(target).Position.Z> -20 and damage[target]==0)
 A.UpdateCast(s,210.79);check("Enton has no early damage",damage[target]==0)
 A.UpdateCast(s,210.8);check("Rinnegan Enton adds source 300 bonus",damage[target]==650+3*56)
 A.UpdateCast(s,212.8);check("Enton finishes and cannot repeat",s.advanced==nil and damage[target]==818)
 check("Enton excludes structures",damage[structure]==0)
 root(target).Position=Vector3.new(0,1000,-20);root(bystander).Position=Vector3.new(4,1000,-20);damage[target]=0;damage[bystander]=0
 for _=1,200 do A.Wave(s,target,220) end
 check("Susanoo emits wave",events.SusanooWave~=nil and events.SusanooWave.duration==1.2)
 A.Update(220.02);check("wave damages both enemies once",damage[target]==206 and damage[bystander]==206)
 check("wave excludes structures",damage[structure]==0)
 A.Update(220.04);check("wave does not repeat damage",damage[target]==206 and damage[bystander]==206)
 check("wave pushes enemies along travel",root(target).Position.Z< -20)
 s.form=0;A.Update(220.06);A.Update(220.1);check("exiting Susanoo ends its wave",damage[target]==206)
 A.Reset();return {status="PASS",checks=count}
end,debug.traceback)
scene:Destroy();clone:Destroy()
if not ok then error(result) end
return result
