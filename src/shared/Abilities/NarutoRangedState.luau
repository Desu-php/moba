--!strict
-- A0HY/A0HZ raw audit, 2026-11-02. Pure command planner; no runtime grants or targets.
export type Point = {x: number, z: number}
export type Grant = {ownerId: string, round: number, life: number, abilityId: string,
 expiresAt: number, form: string, kcmRank: number, heroLevel: number, hagoromo: boolean}
export type Cast = {id: number, ownerId: string, round: number, life: number, abilityId: string,
 phase: string, startedAt: number, releaseAt: number, unpauseAt: number, helperAt: number,
 released: boolean, unpaused: boolean, helpersRemoved: boolean, sequence: number,
 origin: Point, target: Point, direction: Point, center: Point, travelled: number,
 nextTickAt: number, tick: number, explosionTick: number, pulseCounter: number,
 radius: number, scale: number, motionStep: number, pulses: number}
export type State = {ownerId: string, round: number, life: number, serial: number,
 lastRequest: number, clock: number, closed: boolean, cooldowns: {[string]: number}, casts: {[number]: Cast}}
export type Balance = {serial: number,cooldowns: {[string]: number}}
export type Event = {kind: string, id: number, sequence: number, ownerId: string, round: number,
 life: number, abilityId: string, at: number, center: Point, radius: number, scale: number,
 explosionTick: number, pulse: number, visualCount: number, filter: string?,
 damage: number?, displacement: number?, reason: string?}
local R = {}
R.ManaCost=1800; R.Cooldown=60; R.RangeWarcraft=2000
R.LegacyHYExcludedGroups=table.freeze({216,221,220,219,217,218})
local function finite(n: number): boolean return n==n and math.abs(n)<math.huge end
local function integer(n: number): boolean return finite(n) and n%1==0 end
local function validPoint(p: Point): boolean return finite(p.x) and finite(p.z) end
local function copy(p: Point): Point return {x=p.x,z=p.z} end
local function distance(a: Point,b: Point): number return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
function R.new(ownerId: string,round: number,life: number,now: number,balance: Balance?): State
 assert(ownerId~="" and integer(round) and integer(life) and finite(now))
 if balance then
  assert(integer(balance.serial) and balance.serial>=0)
  for id,deadline in balance.cooldowns do assert((id=="A0HY" or id=="A0HZ") and finite(deadline)) end
 end
 return {ownerId=ownerId,round=round,life=life,serial=if balance then balance.serial else 0,lastRequest=0,clock=now,
  closed=false,cooldowns=if balance then table.clone(balance.cooldowns) else {},casts={}}
end
function R.balance(s: State): Balance return {serial=s.serial,cooldowns=table.clone(s.cooldowns)} end
function R.current(s: State,c: Cast): boolean
 return not s.closed and s.casts[c.id]==c and c.ownerId==s.ownerId and c.round==s.round and c.life==s.life
end
local function emit(events: {Event},c: Cast,at: number,kind: string,filter: string?,damage: number?,step: number?,reason: string?)
 c.sequence+=1
 table.insert(events,{kind=kind,id=c.id,sequence=c.sequence,ownerId=c.ownerId,round=c.round,life=c.life,
  abilityId=c.abilityId,at=at,center=copy(c.center),radius=c.radius,scale=c.scale,
  explosionTick=c.explosionTick,pulse=c.pulses,visualCount=if c.abilityId=="A0HY" then 7 else 9,
  filter=filter,damage=damage,displacement=step,reason=reason})
end
function R.cancel(s: State,c: Cast): boolean
 if not R.current(s,c) then return false end
 c.phase="Cancelled";s.casts[c.id]=nil;return true
end
function R.newLife(s: State,round: number,life: number): {Event}
 assert(integer(round) and integer(life))
 local events: {Event}={}
 for _,c in s.casts do
  emit(events,c,s.clock,"Cancelled",nil,nil,nil,"Lifecycle")
  c.phase="Cancelled"
 end
 table.clear(s.casts);s.round=round;s.life=life
 return events -- Cooldowns and request/serial high-water marks deliberately survive death.
end
function R.reset(s: State,round: number,life: number): {Event}
 local events=R.newLife(s,round,life);table.clear(s.cooldowns);return events
end
function R.close(s: State): {Event}
 local events=R.newLife(s,s.round,s.life);s.closed=true;return events
end
function R.request(s: State,now: number,requestId: number,id: string,mana: number,origin: Point,target: Point,grant: Grant?,allowed: boolean): (Cast?,string,number)
 if s.closed then return nil,"Closed",0 end
 if not finite(now) or now<s.clock or not integer(requestId) or requestId<1 or not finite(mana) or mana<0
  or not validPoint(origin) or not validPoint(target) then return nil,"Malformed",0 end
 s.clock=now
 if requestId<=s.lastRequest then return nil,"Replay",0 end;s.lastRequest=requestId
 if id~="A0HY" and id~="A0HZ" then return nil,"Unsupported",0 end
 if not allowed then return nil,"Unavailable",0 end
 if not grant or grant.ownerId~=s.ownerId or grant.round~=s.round or grant.life~=s.life
  or grant.abilityId~=id or not finite(grant.expiresAt) or now>=grant.expiresAt
  or grant.form~="Ewrd" or grant.kcmRank~=3 or not grant.hagoromo
  or not integer(grant.heroLevel) or grant.heroLevel<27 or grant.heroLevel>30 then return nil,"Grant",0 end
 if distance(origin,target)>R.RangeWarcraft then return nil,"Range",0 end
 if now<(s.cooldowns[id] or 0) then return nil,"Cooldown",0 end
 if mana<R.ManaCost then return nil,"Mana",0 end
 local length=distance(origin,target)
 -- Coincident points choose heading0, an explicit deterministic geometry adaptation.
 local direction=if length>0 then {x=(target.x-origin.x)/length,z=(target.z-origin.z)/length} else {x=1,z=0}
 s.serial+=1
 local c: Cast={id=s.serial,ownerId=s.ownerId,round=s.round,life=s.life,abilityId=id,
  phase="Preparing",startedAt=now,releaseAt=now+1.3,unpauseAt=now+1.5,helperAt=now+2.5,
  released=false,unpaused=false,helpersRemoved=id=="A0HY",sequence=0,origin=copy(origin),target=copy(target),
  direction=direction,center=copy(origin),travelled=0,nextTickAt=now+1.33,tick=0,explosionTick=0,
  pulseCounter=if id=="A0HY" then 0 else 16,radius=636,scale=if id=="A0HY" then 120 else 200,
  motionStep=5,pulses=0}
 s.casts[c.id]=c;s.cooldowns[id]=now+R.Cooldown
 return c,"Accepted",R.ManaCost
end
local function tick(s: State,c: Cast,at: number,strengthAt: (number)->number,events: {Event})
 c.tick+=1
 if c.phase=="Travelling" then
  c.travelled+=30
  local virtual={x=c.origin.x+c.direction.x*c.travelled,z=c.origin.z+c.direction.z*c.travelled}
  local arrived=distance(virtual,c.target)<=30
  -- All visuals still move on the arrival tick. HY queries one center projectile.
  c.center=virtual
  emit(events,c,at,"Travel",nil,nil,30,nil)
  if arrived then
   c.phase="Exploding";c.center=if c.abilityId=="A0HY" then virtual else copy(c.target)
   emit(events,c,at,"Arrived",nil,nil,nil,nil)
   if c.abilityId=="A0HY" then
    local old=c.radius;c.radius=500;emit(events,c,at,"ClearDestructibles",nil,nil,nil,nil);c.radius=old
   end
  end
 end
 if c.phase=="Exploding" then -- Independent source block runs on the arrival tick.
  c.explosionTick+=1
  local hy=c.abilityId=="A0HY"
  if not hy then c.radius+=4;c.scale+=2 end
  local due=c.pulseCounter==(if hy then 1 else 16)
  if due then
   local strength=strengthAt(at)
   if not integer(strength) or strength<0 then
    emit(events,c,at,"Cancelled",nil,nil,nil,"InvalidStrength");R.cancel(s,c);return
   end
   local damage=if hy then math.floor((1050+4*strength)/58) else (900+4*strength)/7
   if not finite(damage) then
    emit(events,c,at,"Cancelled",nil,nil,nil,"InvalidStrength");R.cancel(s,c);return
   end
   c.pulseCounter=0;c.pulses+=1
   if hy then c.radius+=4;c.scale+=1 end
   emit(events,c,at,"DamagePulse",if hy then "NonAllyNonStructureNullGroups" else "EnemyNonStructure",damage,if hy then 2 else 8,nil)
  else c.pulseCounter+=1 end
  if not hy and c.pulseCounter<10 then
   if c.motionStep>=0 then c.motionStep-=1;if c.motionStep==0 then c.motionStep=-13 end
   else c.motionStep+=1;if c.motionStep==0 then c.motionStep=13 end end
   emit(events,c,at,"Motion", "NonAllyNonStructure",nil,c.motionStep,nil)
  end
  if (hy and c.pulses==58) or (not hy and c.explosionTick==116) then
   c.phase="Completed";s.casts[c.id]=nil
   -- No executable cripple command: n00A has no evidenced cripple ability.
   emit(events,c,at,"Completed",nil,nil,nil,nil)
  end
 end
 c.nextTickAt=c.releaseAt+(c.tick+1)*.03
end
function R.update(s: State,now: number,strengthAt: (number)->number): ({Event},string)
 if s.closed then return {},"Closed" end
 if not finite(now) or now<s.clock then return {},"Clock" end
 local events: {Event}={}
 local ids: {number}={};for id in s.casts do table.insert(ids,id) end;table.sort(ids)
 for _,id in ids do
  local c=s.casts[id]
  while R.current(s,c) do
   local due=math.min(if c.released then math.huge else c.releaseAt,
    if c.unpaused then math.huge else c.unpauseAt,if c.helpersRemoved then math.huge else c.helperAt,
    if c.released then c.nextTickAt else math.huge)
   if due-now>1e-9 then break end -- Decimal tick boundaries tolerate floating-point roundoff.
   if not c.released and due==c.releaseAt then c.released=true;c.phase="Travelling";emit(events,c,due,"Released",nil,nil,nil,nil)
   elseif not c.unpaused and due==c.unpauseAt then c.unpaused=true;emit(events,c,due,"CasterUnpaused",nil,nil,nil,nil)
   elseif not c.helpersRemoved and due==c.helperAt then c.helpersRemoved=true;emit(events,c,due,"HelpersRemoved",nil,nil,nil,nil)
   else tick(s,c,due,strengthAt,events) end
  end
 end
 table.sort(events,function(a: Event,b: Event): boolean
  if a.at~=b.at then return a.at<b.at end
  return if a.id==b.id then a.sequence<b.sequence else a.id<b.id
 end)
 s.clock=now;return events,"Advanced"
end
-- Target query consumers must explicitly resolve the legacy null-group boundary.
function R.eligible(filter: string,allied: boolean,enemy: boolean,structure: boolean,legacyExcluded: boolean?): (boolean,string)
 if structure then return false,"Structure" end
 if filter=="EnemyNonStructure" then return enemy,"Resolved" end
 if filter=="NonAllyNonStructure" then return not allied,"Resolved" end
 if filter=="NonAllyNonStructureNullGroups" then
  if legacyExcluded==nil then return false,"NullGroupPolicyUnresolved" end
  return not allied and not legacyExcluded,"Resolved"
 end
 return false,"UnknownFilter"
end
return table.freeze(R)
