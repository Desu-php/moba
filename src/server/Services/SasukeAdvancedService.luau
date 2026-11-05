--!strict
-- Timed source mechanics. Context keeps server authority in SasukeAbilityService.
local Units=require(game.ReplicatedStorage.Shared.Abilities.WorldUnits)
local A={}
local ctx:any
local waves:{any}={}
function A.Configure(context:any) ctx=context end
local function combatant(s:any,target:Model):boolean
 local kind=target:GetAttribute("EntityKind")
 return kind~="Tower" and kind~="Core" and kind~="Structure" and not target:FindFirstChildOfClass("ForceField") and ctx.canDamage(s.model,target)
end
local function push(s:any,target:Model,delta:Vector3)
 local r=ctx.root(target);if not r or delta.Magnitude<.001 then return end
 local wall=workspace:Blockcast(r.CFrame,r.Size*.8,delta,ctx.terrain(s,target))
 if wall then delta=delta.Unit*math.max(0,wall.Distance-.1) end
 local f=ctx.fighter(target);if f then ctx.lease(f,workspace:GetServerTimeNow()+.15) end
 target:PivotTo(target:GetPivot()+delta)
end
function A.Cancel(s:any)
 if s.advanced then
  ctx.emit(s,"KirinCancel",s.model:GetPivot().Position,0,.1)
  s.advanced=nil;s.pendingUntil=0
  s.model:SetAttribute("SasukeCastPoseUntil",0)
  local f=ctx.fighter(s.model);if f then ctx.lock(f,0) end
 end
end
function A.Kirin(s:any,target:Model,amount:number,now:number)
 s.advanced={id="Kirin",target=target,life=s.model:GetAttribute("LifeId"),round=s.model:GetAttribute("RoundId"),targetLife=target:GetAttribute("LifeId"),at=now,damage=amount,pulse=0}
 s.pendingUntil=now+2.5
 local f=ctx.fighter(s.model);if f then ctx.lock(f,s.pendingUntil) end
 ctx.emit(s,"KirinWarning",ctx.root(target).Position,Units.toStuds(550),1.5,{target=target})
end
function A.Pull(s:any,now:number,agility:number)
 local origin=ctx.root(s.model).Position;local targets={}
 for target in ctx.actors do local r=ctx.root(target)
  if r and combatant(s,target) and (r.Position-origin).Magnitude<=Units.toStuds(500) then table.insert(targets,target) end
 end
 s.advanced={id="EntonPull",at=now,life=s.model:GetAttribute("LifeId"),round=s.model:GetAttribute("RoundId"),damage=650+3*agility,hit=false,last=now,targets=targets}
 s.pendingUntil=now+2.8
 local f=ctx.fighter(s.model);if f then ctx.lock(f,s.pendingUntil) end
 ctx.emit(s,"EntonGather",s.model:GetPivot().Position,Units.toStuds(500),.8,{follow=true})
end
function A.UpdateCast(s:any,now:number)
 local c=s.advanced;if not c then return end
 local f=ctx.fighter(s.model)
 if not ctx.valid(s) or not f or f.logic.mode=="Stunned" or (f.sleep and f.sleep.active) or c.life~=s.model:GetAttribute("LifeId") or c.round~=s.model:GetAttribute("RoundId") then A.Cancel(s);return end
 if c.id=="EntonPull" then
  local point=ctx.root(s.model).Position;local dt=math.clamp(now-c.last,0,.1);c.last=now
  if now<c.at+.8 then
   for _,target in c.targets do local r=ctx.root(target)
    if r and combatant(s,target) then local delta=point-r.Position;local length=delta.Magnitude
     if length>.01 then push(s,target,delta.Unit*math.min(length,Units.toStuds(if length>=Units.toStuds(134) then 400 else 50)*dt)) end
    end
   end
  elseif not c.hit then
   c.hit=true
   for target in ctx.actors do local r=ctx.root(target)
    if r and combatant(s,target) and (r.Position-point).Magnitude<=Units.toStuds(550) then ctx.hurt(s,target,c.damage,2) end
   end
   ctx.emit(s,"EntonPull",point,Units.toStuds(550),1)
  end
  if now>=s.pendingUntil then s.advanced=nil end
  return
 end
 if not c.point and now>=c.at+1.5 then
  local tr=if c.target.Parent then ctx.root(c.target) else nil
  if not tr or not combatant(s,c.target) or c.targetLife~=c.target:GetAttribute("LifeId") then A.Cancel(s);return end
  c.point=tr.Position
  ctx.emit(s,"Kirin",c.point,Units.toStuds(550),1)
 end
 if c.point then
  while c.pulse<10 and now+1e-5>=c.at+1.6+c.pulse*.1 do
   c.pulse+=1
   local weight=if c.pulse==1 then .5 elseif c.pulse==10 then .1 else .05
   for target in ctx.actors do local r=ctx.root(target)
    if r and combatant(s,target) and (r.Position-c.point).Magnitude<=Units.toStuds(550) then ctx.hurt(s,target,c.damage*weight) end
   end
  end
  if c.pulse==10 then s.advanced=nil end
 end
end
function A.Nagashi(s:any,now:number)
 if not s.nagashiUntil or now>=s.nagashiUntil then return end
 local previous=s.nagashiTick or now;s.nagashiTick=now
 if previous>now then s.nagashiTick=previous;return end
 local dt=math.clamp(now-previous,0,.1);local r=ctx.root(s.model);if not r then return end
 for target in ctx.actors do local tr=ctx.root(target)
  if tr and combatant(s,target) then local delta=tr.Position-r.Position
   if delta.Magnitude<=Units.toStuds(400) then
    ctx.hurt(s,target,ctx.stats(s.player).Agility*dt/0.96)
    local flat=delta*Vector3.new(1,0,1);if flat.Magnitude>.01 then push(s,target,flat.Unit*Units.toStuds(100)*dt) end
   end
  end
 end
end
function A.Wave(s:any,target:Model,now:number)
 if s.form<3 or (s.waveUntil or 0)>now or math.random()>0.2 then return end
 local r,tr=ctx.root(s.model),ctx.root(target);if not r or not tr then return end
 local flat=(tr.Position-r.Position)*Vector3.new(1,0,1);local dir=if flat.Magnitude>.01 then flat.Unit else r.CFrame.LookVector
 -- Source's 30 updates execute on alternate 0.02-second ticks: 1.2 seconds.
 local point=r.Position+dir*Units.toStuds(250);local duration=1.2
 s.waveUntil=now+duration
 table.insert(waves,{s=s,point=point,dir=dir,at=now,last=now,ends=now+duration,seen={},damage=150+ctx.stats(s.player).Agility})
 ctx.emit(s,"SusanooWave",point,Units.toStuds(500),duration,{finish=point+dir*Units.toStuds(990)})
end
function A.Update(now:number)
 for i=#waves,1,-1 do local w=waves[i]
  if not ctx.valid(w.s) or w.s.form<3 or now>=w.ends then table.remove(waves,i);continue end
  local dt=math.clamp(now-w.last,0,.1);w.last=now
  w.point+=w.dir*Units.toStuds(825)*dt
  for target in ctx.actors do local tr=ctx.root(target)
   if tr and combatant(w.s,target) and (tr.Position-w.point).Magnitude<=Units.toStuds(500) then
    if not w.seen[target] then w.seen[target]=true;ctx.hurt(w.s,target,w.damage) end
    push(w.s,target,w.dir*Units.toStuds(275)*dt)
   end
  end
 end
end
function A.Reset() table.clear(waves) end
return A
