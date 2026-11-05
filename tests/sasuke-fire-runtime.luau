-- Engine regression; execute in Studio Edit with the production modules synced.
-- Clone isolates the injected context from the live service's require cache.
local module=game.ServerScriptService.Server.Services.SasukeFireService:Clone()
module.Parent=game.ServerScriptService
local Fire=require(module)
local fixture=Instance.new("Folder");fixture.Name="SasukeFireRegression";fixture.Parent=workspace
local obstacles=Instance.new("Folder");obstacles.Parent=fixture
local actors={};local damage={};local events={};local pool={pool={mana=1000},nextPublish=0}
local origin=Vector3.new(0,1000,0);local now=0;local stunned=false
local function actor(name,point,team)
 local m=Instance.new("Model");m.Name=name;m:SetAttribute("Team",team)
 local r=Instance.new("Part");r.Name="HumanoidRootPart";r.Size=Vector3.new(2,2,1);r.Anchored=true;r.Position=point;r.Parent=m
 local h=Instance.new("Humanoid");h.MaxHealth=10000;h.Health=10000;h.Parent=m;m.PrimaryPart=r;m.Parent=fixture
 actors[m]=h;return m
end
local caster=actor("Caster",origin,1);local enemy=actor("Enemy",origin+Vector3.new(0,0,-42),2)
local ally=actor("Ally",enemy.PrimaryPart.Position,1);local tower=actor("Tower",enemy.PrimaryPart.Position,2);tower:SetAttribute("EntityKind","Tower")
local s={model=caster,player={},pendingUntil=0}
Fire.Configure({actors=actors,root=function(m) return m:FindFirstChild("HumanoidRootPart") end,
 canDamage=function(a,b) return a:GetAttribute("Team")~=b:GetAttribute("Team") end,
 valid=function(state) return state.model.Parent~=nil end,
 resource=function() return pool end,fighter=function() return {logic={mode=if stunned then "Stunned" else "Idle"}} end,
 terrain=function() local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances={obstacles};return p end,
 hurt=function(_,target,amount) damage[target]=(damage[target] or 0)+amount end,
 emit=function(_,id,point,radius,duration,extra) table.insert(events,{id=id,point=point,radius=radius,duration=duration,extra=extra,at=now}) end})
local checks=0
local function check(condition,label) assert(condition,label);checks+=1 end
local function reset()
 Fire.Cancel(s,now);Fire.Reset();table.clear(events);table.clear(damage);pool.pool.mana=1000;stunned=false
 caster:PivotTo(CFrame.new(origin));enemy:PivotTo(CFrame.new(origin+Vector3.new(0,0,-42)))
end
local ok,result=xpcall(function()
 Fire.Cast(s,"SasukeFireball",origin+Vector3.new(0,0,-62),5,10,0)
 for tick=1,100 do now=tick*.04;Fire.UpdateCast(s,now) end
 check(math.abs(pool.pool.mana-925)<1e-5,"exact 75 sustained mana")
 check(math.abs(damage[enemy]-455)<1e-4,"one initial hit + 3 seconds of breath")
 check(not damage[ally] and not damage[tower],"allies and structures excluded")
 check(s.fire==nil and caster:GetAttribute("SasukeFireUntil")==0,"channel expires")
 for _,e in events do check(e.id~="Fire" and e.id~="Amaterasu","no impact ground patch") end
 reset();now=10;Fire.Cast(s,"SasukeFireball",origin-Vector3.zAxis*60,5,10,now)
 caster:PivotTo(CFrame.new(origin+Vector3.xAxis*2));now=10.2;Fire.UpdateCast(s,now)
 check(not s.fire and not damage[enemy],"movement interrupts before damage")
 reset();now=20;Fire.Cast(s,"SasukeFireball",origin-Vector3.zAxis*60,5,10,now)
 pool.pool.mana=9;now=21.04;Fire.UpdateCast(s,now)
 check(not s.fire and pool.pool.mana==9,"low chakra terminates without negative balance")
 reset();now=30;Fire.Cast(s,"PhoenixFlowers",origin-Vector3.zAxis*60,5,10,now)
 now=30.19;Fire.UpdateCast(s,now);check(#events==0,"no instant Phoenix volley")
 now=30.2;Fire.UpdateCast(s,now);check(#events==1,"first shot at 0.2s")
 for tick=2,20 do now=30+tick*.2;Fire.UpdateCast(s,now) end
 local count=0;for _,e in events do if e.id=="Projectile" then count+=1
  local d=(e.extra.finish-e.point).Unit;check(math.deg(math.acos(math.clamp(d:Dot(-Vector3.zAxis),-1,1)))<=25.001,"spread bound")
 end end
 check(count==20 and not s.fire,"twenty scheduled shots over four seconds")
 reset();now=40;Fire.Cast(s,"PhoenixFlowers",origin-Vector3.zAxis*60,5,10,now)
 now=40.2;Fire.UpdateCast(s,now);stunned=true;now=40.4;Fire.UpdateCast(s,now)
 check(not s.fire,"stun interrupts burst")
 reset();now=50;Fire.Ignite(s,enemy,900,now);Fire.Ignite(s,enemy,900,now)
 enemy:PivotTo(CFrame.new(origin+Vector3.xAxis*100));now=55;Fire.Update(now)
 check(math.abs(damage[enemy]-450)<1e-5,"burn follows target and does not stack")
 Fire.Extinguish(enemy.PrimaryPart.Position,2);local before=damage[enemy];now=61;Fire.Update(now)
 check(damage[enemy]==before,"extinguish stops attached burn")
 reset();now=70;Fire.Area(s,origin-Vector3.zAxis*20,12,900,now,false,true)
 check(Fire.Steer(s,origin-Vector3.zAxis*40,73.9),"control inside four seconds")
 check(not Fire.Steer(s,origin,74),"control ends at four seconds")
 reset();now=80;Fire.Coat(s,now);Fire.Ignite({model=enemy},caster,900,now);now=81;Fire.Update(now)
 check(not damage[caster],"coating prevents black burn")
 reset();now=90;Fire.Magatama(s,origin-Vector3.zAxis*60,10,now)
 check(#events==8,"eight magatama projectiles")
 return "PASS "..checks.." Sasuke fire engine checks"
end,debug.traceback)
Fire.Reset();fixture:Destroy();module:Destroy()
if not ok then error(result) end
return result
