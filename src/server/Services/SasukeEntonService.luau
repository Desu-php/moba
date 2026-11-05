--!strict
-- Naruto Legend: delayed flame weapon, carrying arrow and Amaterasu combination.
local U=require(game.ReplicatedStorage.Shared.Abilities.WorldUnits)
local E={}
local c:any
local shots:{any}={}
local serial=0
function E.Configure(context:any) c=context end
local function enemy(s:any,m:Model):boolean
 local h=m:FindFirstChildOfClass("Humanoid");local kind=m:GetAttribute("EntityKind")
 return h~=nil and h.MaxHealth>200 and kind~="Tower" and kind~="Core" and kind~="Structure" and not m:FindFirstChildOfClass("ForceField") and c.canDamage(s.model,m)
end
local function valid(s:any,record:any):boolean
 return not not (c.valid(s) and s.mode>=2 and s.model:GetAttribute("LifeId")==record.life and s.model:GetAttribute("RoundId")==record.round)
end
function E.Cancel(s:any)
 if not s.enton then return end
 s.enton=nil;s.pendingUntil=0;s.model:SetAttribute("SasukeCastPoseUntil",0)
 local f=c.fighter(s.model);if f then c.lock(f,0) end
 c.emit(s,"EntonCancel",s.model:GetPivot().Position,0,.1)
end
function E.Cast(s:any,point:Vector3,agi:number,now:number,magatama:boolean?)
 local r=c.root(s.model);local delta=(point-r.Position)*Vector3.new(1,0,1)
 local dir=if delta.Magnitude>.01 then delta.Unit else r.CFrame.LookVector
 local combo=not magatama and s.mode==3 and s.amaterasuComboUntil and now<s.amaterasuComboUntil
  and s.amaterasuPoint and (point-s.amaterasuPoint).Magnitude<=U.toStuds(150)
 local kind=if combo then "Combo" elseif magatama then "Magatama" elseif s.form>=2 then "Arrow" else "Weapon"
 if combo then c.fire.ConsumeArea(s);s.amaterasuComboUntil=0 end
 local duration=if combo then 2.5 elseif magatama then 1 else .6
 s.enton={kind=kind,point=point,dir=dir,agi=agi,at=now,pulse=0,launched=false,life=s.model:GetAttribute("LifeId"),round=s.model:GetAttribute("RoundId")}
 s.pendingUntil=now+duration
 local f=c.fighter(s.model);if f then c.lock(f,s.pendingUntil) end
 r.CFrame=CFrame.lookAt(r.Position,r.Position+dir)
 if combo then c.emit(s,"EntonComboWarning",point,U.toStuds(350),1) end
end
function E.UpdateCast(s:any,now:number)
 local cast=s.enton;if not cast then return end
 local f=c.fighter(s.model)
 if not valid(s,cast) or not f or f.logic.mode=="Stunned" or (f.sleep and f.sleep.active) then E.Cancel(s);return end
 local age=now-cast.at
 if cast.kind=="Combo" then
  if age>=1 and not cast.launched then cast.launched=true;c.emit(s,"EntonCombo",cast.point,U.toStuds(350),1.5) end
  while cast.pulse<30 and age+1e-6>=1.05+cast.pulse*.05 do
   cast.pulse+=1
   for m in c.actors do local r=c.root(m);local kind=m:GetAttribute("EntityKind")
    if r and kind~="Tower" and kind~="Core" and kind~="Structure" and c.canDamage(s.model,m) and (r.Position-cast.point).Magnitude<=U.toStuds(350) then c.hurt(s,m,26+.17*cast.agi) end
   end
  end
 elseif not cast.launched and age+1e-6>= (if cast.kind=="Magatama" then 0 else .2) then
  cast.launched=true
  if cast.kind=="Magatama" then c.fire.Magatama(s,cast.point,cast.agi,now)
  else
   local arrow=cast.kind=="Arrow";local from=c.root(s.model).Position+cast.dir*U.toStuds(if arrow then 60 else 150)
   serial+=1
   local distance=if arrow then math.min(U.toStuds(1550),(cast.point-from).Magnitude+U.toStuds(550)) else U.toStuds(1000)
   local shot={s=s,kind=cast.kind,point=from,dir=cast.dir,agi=cast.agi,remaining=distance,seen={},contact=false,serial=-100000-serial,
    next=cast.at+(if arrow then .62 else .22),life=cast.life,round=cast.round}
   table.insert(shots,shot)
   c.emit(s,"Projectile",from,1,distance/U.toStuds(if arrow then 1500 else 1000)+(if arrow then .4 else 0),
    {finish=from+cast.dir*distance,spell=if arrow then "EntonArrow" else "EntonWeapon",serial=shot.serial,delay=if arrow then .4 else 0})
  end
 end
 if now>=s.pendingUntil then s.enton=nil end
end
local function finish(shot:any,now:number,patch:boolean)
 c.emit(shot.s,"Impact",shot.point,1,.5,{spell=if shot.kind=="Arrow" then "EntonArrow" else "EntonWeapon",serial=shot.serial})
 if patch then
  if shot.kind=="Arrow" then
   for i=1,6 do local a=i*math.pi/3;c.fire.Area(shot.s,shot.point+Vector3.new(math.cos(a),0,math.sin(a))*U.toStuds(100),U.toStuds(100),800+5*shot.agi,now,false,false,3) end
  else c.fire.Area(shot.s,shot.point,U.toStuds(100),800+5*shot.agi,now) end
 end
end
function E.Update(now:number)
 for i=#shots,1,-1 do local shot=shots[i]
  if not valid(shot.s,shot) then finish(shot,now,false);table.remove(shots,i);continue end
  local ended=false
  while now+1e-6>=shot.next and not ended do
   shot.next+=.02
   local step=math.min(shot.remaining,U.toStuds(if shot.kind=="Arrow" then 30 else 20))
   local wall=workspace:Raycast(shot.point,shot.dir*step,c.terrain(shot.s))
   local point=if wall then wall.Position else shot.point+shot.dir*step
   for target in c.actors do local tr=c.root(target)
    if tr and enemy(shot.s,target) and (tr.Position-shot.point).Magnitude<=U.toStuds(150) then
     c.fire.Ignite(shot.s,target,800+5*shot.agi,now)
     if shot.kind=="Arrow" then
      if not shot.seen[target] then
       shot.seen[target]=true;c.hurt(shot.s,target,300+3*shot.agi,1)
       if not shot.contact then shot.contact=true;shot.remaining=math.min(shot.remaining,U.toStuds(550)) end
      end
      local delta=(point-tr.Position)*Vector3.new(1,0,1)
      local block=if delta.Magnitude>.01 then workspace:Blockcast(tr.CFrame,tr.Size*.8,delta,c.terrain(shot.s,target)) else nil
      if not block then
       local f=c.fighter(target);if f then c.lease(f,now+.15) end
       target:PivotTo(target:GetPivot()+delta)
      end
     elseif not shot.contact then shot.contact=true;shot.remaining=math.min(shot.remaining,U.toStuds(100)) end
    end
   end
   shot.point=point;shot.remaining-=step
   if wall or shot.remaining<=.001 then ended=true;finish(shot,now,true) end
  end
  if ended then table.remove(shots,i) end
 end
end
function E.Reset()
 for _,shot in shots do finish(shot,workspace:GetServerTimeNow(),false) end
 table.clear(shots)
end
return E
