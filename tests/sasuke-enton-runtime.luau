--!nocheck
-- Isolated timing and geometry checks against the real modules, with synthetic clock.
local services=game.ServerScriptService.Server.Services
local ec=services.SasukeEntonService:Clone();ec.Name="EntonIsolatedQA";ec.Parent=services
local fc=services.SasukeFireService:Clone();fc.Name="FireIsolatedQA";fc.Parent=services
local E=require(ec);local F=require(fc)
local folder=Instance.new("Folder");folder.Name="EntonQAScene";folder.Parent=workspace
local actors={};local fighters={};local events={};local damage={};local count=0
local function body(name,pos,enemy)
 local m=Instance.new("Model");m.Name=name;m:SetAttribute("Enemy",enemy);m:SetAttribute("EntityKind","Minion")
 local r=Instance.new("Part");r.Name="HumanoidRootPart";r.Size=Vector3.new(2,4,2);r.Anchored=true;r.CanCollide=false;r.Position=pos;r.Parent=m;m.PrimaryPart=r
 local h=Instance.new("Humanoid");h.RequiresNeck=false;h.MaxHealth=50000;h.Health=50000;h.Parent=m;m.Parent=folder
 actors[m]=h;fighters[m]={logic={mode="Idle"}};return m
end
local origin=Vector3.new(0,1000,0);local caster=body("Caster",origin,false);local victim=body("Enemy",origin+Vector3.new(0,0,-25),true)
local tower=body("Tower",origin+Vector3.new(0,0,-25),true);tower:SetAttribute("EntityKind","Tower")
local s={model=caster,mode=2,form=0,pendingUntil=0}
local ctx={actors=actors,root=function(m)return m.PrimaryPart end,valid=function()return caster.Parent~=nil end,
 canDamage=function(_,m)return m.Parent~=nil and m:GetAttribute("Enemy")==true end,
 terrain=function()local p=RaycastParams.new();p.FilterDescendantsInstances={folder};p.RespectCanCollide=true;return p end,
 fighter=function(m)return fighters[m] end,lock=function(f,t)f.lock=t end,lease=function()end,
 emit=function(_,id,point,radius,duration,extra)table.insert(events,{id=id,point=point,radius=radius,duration=duration,extra=extra})end,
 hurt=function(_,m,amount,stun)damage[m]=(damage[m] or 0)+amount;return amount end,fire=F}
F.Configure(ctx);E.Configure(ctx)
local function check(name,ok)assert(ok,name);count+=1;print("[EntonQA] PASS "..name)end
local function event(id)for i=#events,1,-1 do if events[i].id==id then return events[i] end end end
local function reset()
 E.Reset();F.Reset();table.clear(events);table.clear(damage);s.mode=2;s.form=0;s.enton=nil;s.pendingUntil=0;s.amaterasuComboUntil=0
 fighters[caster].logic.mode="Idle";caster:SetAttribute("LifeId",1);victim:PivotTo(CFrame.new(origin+Vector3.new(0,0,-25)))
end
local ok,err=xpcall(function()
 reset();E.Cast(s,victim.PrimaryPart.Position,40,100);E.UpdateCast(s,100.19)
 check("weapon has preparation",not event("Projectile") and not damage[victim])
 E.UpdateCast(s,100.2);check("weapon launches",event("Projectile").extra.spell=="EntonWeapon")
 check("weapon starts 150 WC ahead",math.abs((event("Projectile").point-origin).Magnitude-150/16)<.01)
 E.Update(100.5);check("weapon attaches burn",event("BlackBurn")~=nil);check("weapon creates final patch",event("Amaterasu")~=nil)
 check("weapon excludes structures",not damage[tower]);F.Update(101);check("weapon burn does damage",damage[victim]>0)
 reset();s.form=2;E.Cast(s,victim.PrimaryPart.Position,40,200);E.UpdateCast(s,200.2)
 check("Susanoo selects arrow",event("Projectile").extra.spell=="EntonArrow")
 E.Update(200.59);check("arrow waits until .6",not damage[victim])
 E.Update(200.9);check("arrow single direct damage",damage[victim]==420)
 check("arrow transports victim",victim.PrimaryPart.Position.Z<origin.Z-25)
 E.Update(201.8);check("arrow never repeats direct damage",damage[victim]==420)
 local patches=0;for _,e in events do if e.id=="Amaterasu" then patches+=1;check("arrow patch lasts three seconds",e.duration==3)end end
 check("arrow leaves six patches",patches==6);check("arrow excludes tower",not damage[tower])
 reset();s.mode=3;s.amaterasuComboUntil=301;s.amaterasuPoint=victim.PrimaryPart.Position
 F.Area(s,s.amaterasuPoint,12,1000,300,false,true);E.Cast(s,s.amaterasuPoint,40,300.2)
 check("combo selected inside one second",s.enton.kind=="Combo");check("combo consumes base area",event("AreaEnd")~=nil and s.blackArea==nil)
 E.UpdateCast(s,301.19);check("combo has one second preparation",not damage[victim])
 E.UpdateCast(s,302.7);check("combo exactly thirty pulses",math.abs(damage[victim]-30*(26+.17*40))<.001)
 check("combo excludes structures",not damage[tower]);check("combo completes",s.enton==nil)
 reset();s.mode=3;s.amaterasuComboUntil=400;s.amaterasuPoint=victim.PrimaryPart.Position;E.Cast(s,s.amaterasuPoint,40,401)
 check("expired combo becomes weapon",s.enton.kind=="Weapon")
 E.Cancel(s);check("cancel releases cast",s.enton==nil and s.pendingUntil==0)
 reset();E.Cast(s,victim.PrimaryPart.Position,40,500);fighters[caster].logic.mode="Stunned";E.UpdateCast(s,500.3)
 check("stun cancels before launch",not event("Projectile") and s.enton==nil)
 reset();E.Cast(s,victim.PrimaryPart.Position,40,600);E.UpdateCast(s,600.2);caster:SetAttribute("LifeId",2);E.Update(601)
 check("life change prevents projectile damage",not damage[victim] and not event("Amaterasu"))
 reset();s.form=2;E.Cast(s,origin+Vector3.new(0,0,-50),40,700,true);E.UpdateCast(s,700)
 local n=0;for _,e in events do if e.id=="Projectile" then n+=1
  check("magatama source distance",math.abs((e.point-origin).Magnitude-100/16)<.01)
  check("magatama travel range",math.abs((e.extra.finish-e.point).Magnitude-1500/16)<.01)
 end end;check("eight magatama projectiles",n==8)
 F.Update(702.1);check("magatama leave ground flames",event("Amaterasu")~=nil)
 F.Update(711);local last=event("AreaEnd");check("magatama patches expire",last~=nil)
end,debug.traceback)
E.Reset();F.Reset();folder:Destroy();ec:Destroy();fc:Destroy()
assert(ok,err);return {status="PASS",checks=count}
