--!strict
-- Pure domain. Runtime owns Instances, authoritative learned rank, mana and Sage layer.
export type Context = {level: number, rank: number, hagoromo: boolean, alive: boolean,
 fullKurama: boolean, kuramaCooldown: boolean, sageRemaining: number, sageAuraPresent: boolean}
export type Balance = {chakra: number, cooldownAt: number}
export type Active = {id: number, rank: number, nextDrainAt: number, dashAt: number,
 dashReady: boolean, cancelPresent: boolean, buffPresent: boolean}
export type State = {chakra: number, clock: number, nextResourceAt: number, cooldownAt: number,
 serial: number, closed: boolean, sharedUnits: number, active: Active?}
export type Event = {kind: string, id: number?, rank: number?, reason: string?, amount: number?}
export type Config = {read InitialChakra: number, read EntryCost: number, read DrainPerSecond: number,
 read IdleRegenPerSecond: number, read Cooldown: number, read DashDelay: number, read ResourcePeriod: number,
 read MinimumLevels: {read number}, read SharingCostPerUnit: number, read ConversionLevel: number,
 read ConversionCost: number, read ConversionMana: number, read MaxAdvance: number}
local M = {}
local function finite(n: number): boolean return n == n and math.abs(n) < math.huge end
local function integer(n: number): boolean return finite(n) and n % 1 == 0 end
local function valid(c: Context): boolean
 return integer(c.level) and c.level>=1 and c.level<=30 and integer(c.rank) and c.rank>=0 and c.rank<=3
  and finite(c.sageRemaining) and c.sageRemaining>=0
end
function M.configure(config: Config)
 local D = {}
 local function sage(events: {Event}, c: Context)
  if c.sageRemaining>1 and c.sageAuraPresent then table.insert(events,{kind="ReapplySage"}) end
 end
 local function exit(s: State, c: Context, reason: string, events: {Event})
  local a=s.active; if not a then return end
  s.active=nil
  table.insert(events,{kind="Exited",id=a.id,rank=a.rank,reason=reason})
  if c.alive and reason~="Closed" then sage(events,c) end
 end
 function D.new(now: number, balance: Balance?): State
  assert(finite(now),"finite clock required")
  if balance then assert(finite(balance.chakra) and balance.chakra>=0 and finite(balance.cooldownAt),"invalid balance") end
  return {chakra=if balance then balance.chakra else config.InitialChakra,clock=now,nextResourceAt=now+1,
   cooldownAt=if balance then balance.cooldownAt else now,serial=0,
   closed=false,sharedUnits=0,active=nil}
 end
 function D.spend(s: State,amount: number): boolean
  if s.closed or not finite(amount) or amount<0 or amount>s.chakra then return false end
  s.chakra-=amount; return true
 end
 function D.clearCooldown(s: State) s.cooldownAt=0 end
 function D.credit(s: State,amount: number): boolean
  if s.closed or not finite(amount) or amount<0 or not finite(s.chakra+amount) then return false end
  s.chakra+=amount;return true
 end
 function D.balance(s: State): Balance return {chakra=s.chakra,cooldownAt=s.cooldownAt} end
 -- Process elapsed whole ticks. Context must be advanced at each authoritative context change.
 -- On a long gap caller supplies historically correct context or chooses a runtime suspension policy.
 function D.update(s: State, now: number, c: Context): {Event}
  local events: {Event}={}
  if s.closed or not finite(now) or now<s.clock or not valid(c) then return events end
  if now-s.clock>config.MaxAdvance then return {{kind="ClockGap",amount=now-s.clock}} end
  local before=s.chakra
  if not c.alive then exit(s,c,"Death",events) end
  while true do
   local a=s.active
   local nextAt=s.nextResourceAt
   if a then nextAt=math.min(nextAt,a.nextDrainAt,if a.dashReady then math.huge else a.dashAt) end
   if nextAt>now then break end
   if s.nextResourceAt==nextAt then
    -- Strict threshold guard, not a clamp. Sharing also skips at/above threshold.
    if s.chakra<900+100*c.level then
     local current=s.active
     if (not current or not current.buffPresent) and not c.fullKurama then s.chakra+=config.IdleRegenPerSecond end
     local cost=config.SharingCostPerUnit*s.sharedUnits
     if s.chakra>=cost then s.chakra-=cost
     else s.sharedUnits=0; table.insert(events,{kind="RevokeSharing"}) end
     if c.fullKurama then table.insert(events,{kind="KuramaPulse",amount=20}) end
    end
    s.nextResourceAt+=config.ResourcePeriod
    -- Idle saturated resource has no future work before now.
    if not s.active and s.chakra>=900+100*c.level then
     s.nextResourceAt+=math.floor((now-s.nextResourceAt)/config.ResourcePeriod+1)*config.ResourcePeriod
    end
   end
   a=s.active
   if a and a.nextDrainAt==nextAt then
    s.chakra=math.max(0,s.chakra-config.DrainPerSecond); a.nextDrainAt+=1
    if not a.buffPresent or not a.cancelPresent or s.chakra<=0 then
     exit(s,c,if not a.buffPresent then "BuffRemoved" elseif not a.cancelPresent then "Cancelled" else "Depleted",events)
    end
   end
   a=s.active
   if a and not a.dashReady and a.dashAt==nextAt then
    a.dashReady=true; table.insert(events,{kind="DashReady",id=a.id}); sage(events,c)
   end
  end
  s.clock=now
  if before~=s.chakra then table.insert(events,{kind="ChakraChanged",amount=s.chakra-before}) end
  return events
 end
 -- Update first, then issue commands at exactly state.clock; prevents retroactive context/costs.
 function D.canEnter(s: State, c: Context): (boolean,string)
  if s.closed then return false,"Closed" end
  if not valid(c) then return false,"Malformed" end
  if not c.alive then return false,"Dead" end
  if s.active or c.fullKurama then return false,"FormBusy" end
  if c.kuramaCooldown then return false,"KuramaLocked" end
  if c.rank==0 then return false,"Unlearned" end
  if c.level<config.MinimumLevels[c.rank] then return false,"Level" end
  if c.rank==3 and not c.hagoromo then return false,"Hagoromo" end
  if s.clock<s.cooldownAt then return false,"Cooldown" end
  if s.chakra<config.EntryCost then return false,"Chakra" end
  return true,"Accepted"
 end
 function D.enter(s: State, c: Context): (boolean,string,{Event})
  local accepted,reason=D.canEnter(s,c); if not accepted then return false,reason,{} end
  s.serial+=1; s.chakra-=config.EntryCost; s.cooldownAt=s.clock+config.Cooldown
  s.active={id=s.serial,rank=c.rank,nextDrainAt=s.clock+1,dashAt=s.clock+config.DashDelay,
   dashReady=false,cancelPresent=true,buffPresent=true}
  return true,"Accepted",{{kind="Entered",id=s.serial,rank=c.rank},{kind="ChakraChanged",amount=-config.EntryCost}}
 end
 -- Pass the active id captured by the runtime; late callbacks cannot affect a newer cast.
 function D.cancel(s: State, id: number): boolean
  local a=s.active; if s.closed or not a or a.id~=id then return false end
  a.cancelPresent=false; return true
 end
 function D.buffRemoved(s: State, id: number): boolean
  local a=s.active; if s.closed or not a or a.id~=id then return false end
  a.buffPresent=false; return true
 end
 function D.setSharingCount(s: State, count: number): boolean
  if s.closed or not integer(count) or count<0 or count>1000 then return false end
  s.sharedUnits=count; return true -- owned grant creation/expiry belongs to external sharing module.
 end
 function D.convert(s: State, c: Context): (boolean,string,{Event})
  if s.closed then return false,"Closed",{} end
  if not valid(c) then return false,"Malformed",{} end
  if not c.alive then return false,"Dead",{} end
  if c.level<config.ConversionLevel then return false,"Level",{} end
  if s.chakra<config.ConversionCost then return false,"Chakra",{} end
  s.chakra-=config.ConversionCost
  return true,"Converted",{{kind="RestoreOrdinaryMana",amount=config.ConversionMana},
   {kind="ChakraChanged",amount=-config.ConversionCost}}
 end
 -- Call on owner removal/round end/respawn replacement. New session must use new State.
 function D.close(s: State, c: Context): {Event}
  local events: {Event}={}; if s.closed then return events end
  exit(s,c,"Closed",events); s.closed=true
  if s.sharedUnits>0 then s.sharedUnits=0; table.insert(events,{kind="RevokeSharing"}) end
  return events
 end
 function D.availability(s: State, c: Context)
  local active=s.active~=nil and not s.closed
  return {kcm=not s.closed and not active and not c.fullKurama and not c.kuramaCooldown, gamakichi=not s.closed and not active,
   sage=not s.closed, dash=active and s.active~=nil and s.active.dashReady,
   sharing=active, fullKurama=not s.closed and not active and c.level>=21 and not c.kuramaCooldown}
 end
 return D
end
return M
