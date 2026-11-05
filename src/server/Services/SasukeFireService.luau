--!strict
-- Authoritative fire casts and attached black-flame burns. No delayed callbacks survive a life.
local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local F=require(Shared.Abilities.SasukeFireRules)
local U=require(Shared.Abilities.WorldUnits)
local Structures=require(Shared.Game.StructureRules)
local Fire={}
local c:any
local serial=0
local patches:{any}={}
local burns:{any}={}
local missiles:{any}={}
local random=Random.new()
local function nextSerial():number serial+=1;return -serial end
local function flat(v:Vector3):Vector3 return v*Vector3.new(1,0,1) end
local function direction(s:any,point:Vector3):Vector3
 local r=c.root(s.model);local delta=flat(point-r.Position)
 return if delta.Magnitude>.01 then delta.Unit else r.CFrame.LookVector
end
local function mouth(s:any,dir:Vector3):Vector3
 local head=s.model:FindFirstChild("Head")
 return (if head and head:IsA("BasePart") then head.Position else c.root(s.model).Position+Vector3.yAxis*1.5)+dir*.65
end
local function enemy(s:any,m:Model):boolean
 return not Structures.isStructure(m:GetAttribute("EntityKind")) and c.canDamage(s.model,m)
end
local function clearLine(s:any,a:Vector3,b:Vector3):boolean
 return workspace:Raycast(a,b-a,c.terrain(s))==nil
end
function Fire.Configure(context:any) c=context end
function Fire.Cancel(s:any,now:number)
 local cast=s.fire;if not cast then return end
 c.emit(s,"FireEnd",cast.origin,0,.1,{fireSerial=cast.serial})
 s.fire=nil;s.pendingUntil=math.min(s.pendingUntil,now)
 s.model:SetAttribute("SasukeCastPoseUntil",now)
 s.model:SetAttribute("SasukeFireUntil",0)
end
function Fire.Cast(s:any,id:string,point:Vector3,rank:number,agi:number,now:number)
 local dir=direction(s,point);local r=c.root(s.model)
 local cast={id=id,serial=nextSerial(),origin=r.Position,direction=dir,at=now,tick=0,sent=0,rank=rank,agi=agi,seen={}}
 s.fire=cast;s.pendingUntil=now+F.Duration;s.model:SetAttribute("SasukeFireUntil",s.pendingUntil)
 r.CFrame=CFrame.lookAt(r.Position,r.Position+dir)
 if id=="SasukeFireball" then c.emit(s,"FireBreath",mouth(s,dir),U.toStuds(500),F.Duration,{direction=dir,origin=r.Position,fireSerial=cast.serial}) end
end
local function launch(s:any,id:string,from:Vector3,dir:Vector3,rank:number,agi:number,now:number)
 local shot={s=s,id=id,serial=nextSerial(),point=from,origin=c.root(s.model).Position,direction=dir,remaining=U.toStuds(if id=="EntonMagatama" then 1500 else 1000),speed=U.toStuds(750),rank=rank,agi=agi,last=now}
 table.insert(missiles,shot)
 c.emit(s,"Projectile",from,.7,shot.remaining/shot.speed,{finish=from+dir*shot.remaining,spell=id,serial=shot.serial})
end
function Fire.Magatama(s:any,point:Vector3,agi:number,now:number)
 local aim=CFrame.lookAt(Vector3.zero,direction(s,point))
 for _,angle in {-50,-35,-20,-5,5,20,35,50} do
  local dir=(aim*CFrame.Angles(0,math.rad(angle),0)).LookVector
  local from=c.root(s.model).Position+dir*U.toStuds(100)
  launch(s,"EntonMagatama",from,dir,0,agi,now)
  local shot=missiles[#missiles];shot.remaining=U.toStuds(1500);shot.patchUntil=now+10
 end
end
function Fire.UpdateCast(s:any,now:number)
 local cast=s.fire;if not cast then return end
 local r=c.root(s.model);local fighter=c.fighter(s.model)
 if not c.valid(s) or not r or not fighter or fighter.logic.mode=="Stunned" or (fighter.sleep and fighter.sleep.active)
  or (r.Position-cast.origin).Magnitude>1.5 then Fire.Cancel(s,now);return end
 local age=math.min(F.Duration,now-cast.at)
 if cast.id=="PhoenixFlowers" then
  local due=F.phoenixDue(age)
  while cast.sent<due do
   cast.sent+=1
   local dir=(CFrame.lookAt(Vector3.zero,cast.direction)*CFrame.Angles(0,math.rad(random:NextNumber(-F.PhoenixSpread,F.PhoenixSpread)),0)).LookVector
   launch(s,"PhoenixFlowers",mouth(s,cast.direction),dir,cast.rank,cast.agi,now)
  end
 else
  -- Fixed simulation ticks preserve damage/mana under variable Heartbeat rates.
  local due=math.floor((age+1e-6)/F.Tick)
  while cast.tick<due do
   cast.tick+=1;local t=cast.tick*F.Tick
   local sustained=t>F.Warmup
   if sustained then
    local pool=c.resource(s.player)
    if not pool or pool.pool.mana<F.MinimumMana then Fire.Cancel(s,now);return end
    pool.pool.mana=math.max(0,pool.pool.mana-F.ManaPerSecond*F.Tick);pool.nextPublish=0
   end
   local center=cast.origin+cast.direction*U.toStuds(F.front(t))
   local radius=U.toStuds(F.radius(t))
   for target in c.actors do local tr=c.root(target)
    if tr and enemy(s,target) and math.abs(tr.Position.Y-cast.origin.Y)<radius then
     local delta=flat(tr.Position-cast.origin);local along=delta:Dot(cast.direction)
     local side=(delta-cast.direction*along).Magnitude
     local inside=if sustained then F.inBreath(along*16,side*16) else flat(tr.Position-center).Magnitude<=radius and not cast.seen[target]
     if inside and clearLine(s,mouth(s,cast.direction),tr.Position) then
      if not sustained then cast.seen[target]=true end
      c.hurt(s,target,if sustained then (16*cast.rank+cast.agi)*F.Tick else 35*cast.rank+cast.agi)
     end
    end
   end
  end
 end
 if now>=cast.at+F.Duration then Fire.Cancel(s,now) end
end
local function endBurn(index:number)
 local b=burns[index];c.emit(b.s,"FireEnd",b.target:GetPivot().Position,0,.1,{fireSerial=b.serial});table.remove(burns,index)
end
function Fire.Ignite(s:any,target:Model,total:number,now:number)
 if not enemy(s,target) or ((target:GetAttribute("AmaterasuCoatingUntil") or 0) :: number)>now then return end
 for _,b in burns do if b.s==s and b.target==target then return end end
 local b={s=s,target=target,serial=nextSerial(),damage=total/40,ticks=40,next=now+.25}
 table.insert(burns,b)
 c.emit(s,"BlackBurn",target:GetPivot().Position,1,F.BurnDuration,{target=target,fireSerial=b.serial})
end
function Fire.Area(s:any,point:Vector3,radius:number,total:number,now:number,follow:boolean?,controlled:boolean?,duration:number?)
 local a={s=s,point=point,radius=radius,total=total,serial=nextSerial(),untilAt=now+(duration or 10),last=now,follow=follow,seen={},controlUntil=if controlled then now+4 else 0}
 if controlled then a.activateAt=now+1;a.untilAt+=1 end
 table.insert(patches,a)
 if controlled then s.blackArea=a;s.model:SetAttribute("AmaterasuControlUntil",a.controlUntil) end
 c.emit(s,if controlled then "AmaterasuWarning" else "Amaterasu",point,radius,if controlled then 1 else duration or 10,{follow=follow,areaSerial=a.serial})
 return a
end
function Fire.ConsumeArea(s:any)
 local a=s.blackArea;if not a then return end
 for i=#patches,1,-1 do if patches[i]==a then
  c.emit(s,"AreaEnd",a.point,a.radius,.1,{areaSerial=a.serial});table.remove(patches,i)
 end end
 a.controlUntil=0;s.blackArea=nil;s.model:SetAttribute("AmaterasuControlUntil",0)
end
function Fire.Steer(s:any,point:Vector3,now:number):boolean
 local a=s.blackArea;if not a or now>=a.controlUntil or now>=a.untilAt then return false end
 a.goal=point
 c.emit(s,"AreaMove",a.point,a.radius,(point-a.point).Magnitude/U.toStuds(400),{areaSerial=a.serial,goal=point})
 return true
end
function Fire.Coat(s:any,now:number)
 s.model:SetAttribute("AmaterasuCoatingUntil",now+20)
 c.emit(s,"BlackCoating",s.model:GetPivot().Position,3,20,{target=s.model})
 for i=#burns,1,-1 do if burns[i].target==s.model then endBurn(i) end end
end
function Fire.Extinguish(point:Vector3,radius:number)
 for i=#patches,1,-1 do local a=patches[i]
  if (a.point-point).Magnitude<=radius then
   a.controlUntil=0;c.emit(a.s,"AreaEnd",a.point,a.radius,.1,{areaSerial=a.serial});table.remove(patches,i)
  end
 end
 for i=#burns,1,-1 do if (burns[i].target:GetPivot().Position-point).Magnitude<=radius then endBurn(i) end end
end
function Fire.Update(now:number)
 for i=#patches,1,-1 do local a=patches[i]
  if not c.valid(a.s) or now>=a.untilAt then
   a.controlUntil=0;c.emit(a.s,"AreaEnd",a.point,a.radius,.1,{areaSerial=a.serial});table.remove(patches,i);continue
  end
  local dt=math.max(0,now-a.last);a.last=now
  if a.activateAt then
   if now<a.activateAt then continue end
   a.activateAt=nil;c.emit(a.s,"Amaterasu",a.point,a.radius,math.max(.01,a.untilAt-now),{follow=a.follow,areaSerial=a.serial})
  end
  if a.follow then a.point=a.s.model:GetPivot().Position
  elseif a.goal then local delta=a.goal-a.point
   if delta.Magnitude>.01 then a.point+=delta.Unit*math.min(delta.Magnitude,U.toStuds(400)*dt) end
  end
  for target in c.actors do local tr=c.root(target)
   if tr and not a.seen[target] and (tr.Position-a.point).Magnitude<=a.radius and enemy(a.s,target) then
    a.seen[target]=true;Fire.Ignite(a.s,target,a.total,now)
   end
  end
 end
 for i=#burns,1,-1 do local b=burns[i];local h=b.target:FindFirstChildOfClass("Humanoid")
  if not c.valid(b.s) or not b.target.Parent or not h or h.Health<=0 or b.ticks<=0 then endBurn(i);continue end
  while b.ticks>0 and now>=b.next do b.next+=.25;b.ticks-=1;c.hurt(b.s,b.target,b.damage) end
 end
 for i=#missiles,1,-1 do local shot=missiles[i]
  if not c.valid(shot.s) then c.emit(shot.s,"Impact",shot.point,.7,.1,{spell=shot.id,serial=shot.serial});table.remove(missiles,i);continue end
  local step=math.min(shot.remaining,shot.speed*math.max(0,now-shot.last));shot.last=now
  local wall=workspace:Raycast(shot.point,shot.direction*step,c.terrain(shot.s))
  local finish=if wall then wall.Position else shot.point+shot.direction*step
  local contact:Model?=nil;local first=math.huge;local segment=finish-shot.point
  for target in c.actors do local tr=c.root(target)
   if tr and enemy(shot.s,target) then
    local t=if segment.Magnitude>.001 then math.clamp((tr.Position-shot.point):Dot(segment)/segment:Dot(segment),0,1) else 0
    if (tr.Position-shot.point-segment*t).Magnitude<=(if shot.id=="EntonMagatama" then U.toStuds(100) else 2.2) and t<first then contact=target;first=t end
   end
  end
  if contact then finish=shot.point+segment*first end
  shot.point=finish;shot.remaining-=step
  if contact or wall or shot.remaining<=.01 then
   if contact then
    if shot.id=="EntonMagatama" then Fire.Ignite(shot.s,contact,800+5*shot.agi,now)
    else c.hurt(shot.s,contact,F.phoenixDamage(shot.rank,shot.agi,flat(finish-shot.origin).Magnitude*16)) end
   end
   if shot.id=="EntonMagatama" then Fire.Area(shot.s,finish,U.toStuds(100),800+5*shot.agi,now,false,false,math.max(.01,shot.patchUntil-now)) end
   c.emit(shot.s,"Impact",finish,.7,.5,{spell=shot.id,serial=shot.serial});table.remove(missiles,i)
  end
 end
end
function Fire.Reset()
 for i=#burns,1,-1 do endBurn(i) end
 for _,a in patches do c.emit(a.s,"AreaEnd",a.point,a.radius,.1,{areaSerial=a.serial}) end
 table.clear(patches);table.clear(missiles)
end
return Fire
