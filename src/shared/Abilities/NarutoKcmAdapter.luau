--!strict
-- Headless, server-owned adapter. No Instances, scheduling, remotes, UI or implicit morph policy.
export type Context = {level: number, rank: number, hagoromo: boolean, alive: boolean,
 fullKurama: boolean, kuramaCooldown: boolean, sageRemaining: number, sageAuraPresent: boolean}
export type Availability = {kcm: boolean, gamakichi: boolean, sage: boolean, dash: boolean,
 sharing: boolean, fullKurama: boolean}
export type Snapshot = {life: number, epoch: number, eligible: boolean, canCast: boolean,
 context: Context, allowed: Availability}
export type Token = {read owner: string, read life: number, read epoch: number, read serial: number}
export type Event = {kind: string, id: number?, rank: number?, reason: string?, amount: number?}
export type Balance = {chakra: number, cooldownAt: number}
export type Rules<S> = {
 clearCooldown: (S)->(),
 new: (number, Balance?) -> S, balance: (S) -> Balance, spend: (S,number) -> boolean,
 update: (S, number, Context) -> {Event}, close: (S, Context) -> {Event},
 canEnter: (S, Context) -> (boolean,string), enter: (S, Context) -> (boolean,string,{Event}),
 cancel: (S, number) -> boolean, buffRemoved: (S, number) -> boolean,
 convert: (S, Context) -> (boolean,string,{Event}), availability: (S, Context) -> Availability,
}
export type Ports = {
 now: () -> number, read: (string) -> Snapshot?, kuramaPulse: ((Token)->())?,
 publish: (Token, number, Availability, number) -> (), -- domain-owned cooldown deadline
 effect: (Token, string, number) -> (), -- Entered / DashReady / Exited, cast-scoped.
 reapplySage: (Token) -> (), restoreMana: (Token, number) -> (),
 revokeSharing: (Token) -> (), fault: (Token, string) -> (),
}
export type MorphPolicy = {
 enabled: boolean, apply: (Token, number) -> boolean, remove: (Token, number) -> (),
}
local Adapter = {}
local function finite(n: number): boolean return n==n and math.abs(n)<math.huge end
local function identity(s: Snapshot): boolean
 local c=s.context
 return finite(s.life) and s.life%1==0 and finite(s.epoch) and s.epoch%1==0
  and finite(c.level) and c.level%1==0 and c.level>=1 and c.level<=30
  and finite(c.rank) and c.rank%1==0 and c.rank>=0 and c.rank<=3
  and finite(c.sageRemaining) and c.sageRemaining>=0
end
function Adapter.configure<S>(rules: Rules<S>, ports: Ports, policy: MorphPolicy?)
 type Record = {token: Token, state: S, context: Context, clock: number, busy: boolean,
  morphRank: number?, castId: number?, failed: boolean}
 local records: {[string]: Record}={}
 local saved: {[string]: {epoch: number, balance: Balance}}={}
 local quarantine: {[string]: {epoch: number, life: number}}={}
 local serial=0
 local A={}
 local function same(r: Record, s: Snapshot?): boolean
  return s~=nil and identity(s) and s.life==r.token.life and s.epoch==r.token.epoch
 end
 local function cleanup(r: Record)
  local rank=r.morphRank; r.morphRank=nil -- Clear ownership before any callback, exactly once.
  if rank and policy then
   local ok=pcall(policy.remove,r.token,rank)
   if not ok then
    r.failed=true; quarantine[r.token.owner]={epoch=r.token.epoch,life=r.token.life}
    ports.fault(r.token,"MorphRemoveFailed")
   end
  end
  local id=r.castId; r.castId=nil
  if id then ports.effect(r.token,"Exited",id) end
 end
 local function detach(r: Record)
  records[r.token.owner]=nil
  saved[r.token.owner]={epoch=r.token.epoch,balance=rules.balance(r.state)}
  rules.close(r.state,r.context); cleanup(r); ports.revokeSharing(r.token)
  local balance=rules.balance(r.state)
  ports.publish(r.token,balance.chakra,
   {kcm=false,gamakichi=false,sage=false,dash=false,sharing=false,fullKurama=false},balance.cooldownAt)
 end
 local function publish(r: Record, s: Snapshot)
  local mask=rules.availability(r.state,s.context)
  -- Intersect with current authoritative learned/unlock/phase restrictions, never blindly enable.
  mask.kcm=mask.kcm and s.allowed.kcm and s.context.alive and s.eligible
  mask.gamakichi=mask.gamakichi and s.allowed.gamakichi and s.context.alive and s.eligible
  mask.sage=mask.sage and s.allowed.sage and s.context.alive and s.eligible
  mask.dash=mask.dash and s.allowed.dash and s.context.alive and s.eligible
  mask.sharing=mask.sharing and s.allowed.sharing and s.context.alive and s.eligible
  mask.fullKurama=mask.fullKurama and s.allowed.fullKurama and s.context.alive and s.eligible
  local balance=rules.balance(r.state)
  ports.publish(r.token,balance.chakra,mask,balance.cooldownAt)
 end
 local function events(r: Record, list: {Event}, s: Snapshot)
  local reapply=false
  for _,e in list do
   if e.kind=="Exited" then cleanup(r)
   elseif e.kind=="DashReady" and e.id==r.castId and rules.availability(r.state,s.context).dash then
    ports.effect(r.token,"DashReady",e.id :: number)
   elseif e.kind=="ReapplySage" then reapply=true
   elseif e.kind=="KuramaPulse" then local pulse=ports.kuramaPulse; if pulse then pulse(r.token) end
   elseif e.kind=="RestoreOrdinaryMana" then ports.restoreMana(r.token,e.amount :: number)
   elseif e.kind=="RevokeSharing" then ports.revokeSharing(r.token)
   elseif e.kind=="ClockGap" then ports.fault(r.token,"ClockGap") end
  end
  if reapply and not r.failed and s.context.alive and s.context.sageRemaining>1 and s.context.sageAuraPresent then
   ports.reapplySage(r.token)
  end
 end
 -- Returns a locked record. All port functions must be synchronous/non-yielding.
 local function acquire(token: Token): (Record?,Snapshot?,string)
  local r=records[token.owner]
  if not r or r.token~=token then return nil,nil,"Stale" end
  if r.busy then return nil,nil,"Busy" end
  r.busy=true
  if not policy or not policy.enabled then detach(r); return nil,nil,"Disabled" end
  local s=ports.read(token.owner)
  if not same(r,s) or not s or not s.eligible or not s.context.alive then
   detach(r); return nil,nil,"InvalidState"
  end
  local now=ports.now()
  if not finite(now) or now<r.clock then r.busy=false; return nil,nil,"Clock" end
  -- Freeze instead of replaying across an unknowable interval. No further casts on this session.
  if now-r.clock>60 then
   ports.fault(token,"ClockGap"); detach(r); return nil,nil,"ClockGap"
  end
  -- Old context applies to elapsed time; current context applies only at the observed transition.
  events(r,rules.update(r.state,now,r.context),s)
  events(r,rules.update(r.state,now,s.context),s)
  if r.failed then detach(r); return nil,nil,"PortFault" end
  r.context=table.clone(s.context); r.clock=now
  return r,s,"Ready"
 end
 function A.Bind(owner: string): (Token?,string)
  if not policy or not policy.enabled then return nil,"Disabled" end
  local prior=records[owner]
  if prior and prior.busy then return nil,"Busy" end
  local s=ports.read(owner); local now=ports.now()
  if not s or not identity(s) or not s.eligible or not s.context.alive or not finite(now) then return nil,"InvalidState" end
  local blocked=quarantine[owner]
  if blocked and blocked.epoch==s.epoch and blocked.life==s.life then return nil,"PortFault" end
  quarantine[owner]=nil
  if prior then
   if same(prior,s) then return prior.token,"Bound" end
   detach(prior)
  end
  serial+=1
  local token: Token=table.freeze({owner=owner,life=s.life,epoch=s.epoch,serial=serial})
  local previous=saved[owner]
  local balance=if previous and previous.epoch==s.epoch then previous.balance else nil
  local r: Record={token=token,state=rules.new(now,balance),context=table.clone(s.context),clock=now,
   busy=true,morphRank=nil,castId=nil,failed=false}
  records[owner]=r; saved[owner]=nil; publish(r,s); r.busy=false
  return token,"Bound"
 end
 function A.Enter(token: Token): (boolean,string)
  if not policy or not policy.enabled then return false,"Disabled" end
  local r,s,reason=acquire(token); if not r or not s then return false,reason end
  if not s.canCast or not s.allowed.kcm then publish(r,s); r.busy=false; return false,"InvalidState" end
  local ok,why=rules.canEnter(r.state,s.context)
  if not ok then publish(r,s); r.busy=false; return false,why end
  r.morphRank=s.context.rank -- Own partial application too; failed apply is always removed.
  local worked,applied=pcall(policy.apply,token,s.context.rank)
  local current=ports.read(token.owner)
  if not worked or not applied or not same(r,current) or not current or not current.eligible
   or not current.context.alive or not current.canCast or not current.allowed.kcm then
   cleanup(r)
   if r.failed or not same(r,current) or not current or not current.eligible or not current.context.alive then
    detach(r)
   else publish(r,current); r.busy=false end
   return false,"MorphRejected"
  end
  -- Revalidate after policy apply; a different learned rank needs a fresh transaction.
  local admitted,admissionReason=rules.canEnter(r.state,current.context)
  if not admitted or current.context.rank~=r.morphRank then
   cleanup(r); if r.failed then detach(r) else publish(r,current); r.busy=false end
   return false,if admitted then "MorphRejected" else admissionReason
  end
  local accepted,detail,list=rules.enter(r.state,current.context)
  if not accepted then
   cleanup(r); if r.failed then detach(r) else publish(r,current); r.busy=false end
   return false,detail
  end
  r.context=table.clone(current.context)
  for _,e in list do if e.kind=="Entered" then r.castId=e.id; ports.effect(token,"Entered",e.id :: number) end end
  events(r,list,current); publish(r,current); r.busy=false
  return true,"Accepted"
 end
 function A.ResetCooldown(token: Token): boolean
  local clear=rules.clearCooldown
  local r,s=acquire(token);if not r or not s then return false end
  clear(r.state);publish(r,s);r.busy=false;return true
 end
 function A.Chakra(token: Token): number?
  local r=records[token.owner]; return if r and r.token==token then rules.balance(r.state).chakra else nil
 end
 function A.SpendChakra(token: Token,amount: number): boolean
  local r,s=acquire(token); if not r or not s then return false end
  local ok=s.canCast and rules.spend(r.state,amount); publish(r,s); r.busy=false; return ok
 end
 function A.ActiveRank(token: Token): number
  local r=records[token.owner]; if not r or r.token~=token then return 0 end
  local s=ports.read(token.owner)
  return if s and same(r,s) and s.eligible and s.context.alive then r.morphRank or 0 else 0
 end
 function A.IsActive(token: Token): boolean
  local r=records[token.owner]; if not r or r.token~=token then return false end
  local s=ports.read(token.owner)
  return s~=nil and same(r,s) and s.eligible and s.context.alive and rules.availability(r.state,s.context).sharing
 end
 function A.ActiveCast(token: Token): (number?,number?)
  if not A.IsActive(token) then return nil,nil end
  local r=records[token.owner];if not r or r.token~=token then return nil,nil end
  return r.morphRank,r.castId -- Actual admitted morph, never a newly learned rank or replicated attribute.
 end
 function A.IsDashReady(token: Token): boolean
  local r=records[token.owner]; if not r or r.token~=token then return false end
  local s=ports.read(token.owner)
  return s~=nil and same(r,s) and s.eligible and s.context.alive and s.allowed.dash and rules.availability(r.state,s.context).dash
 end
 function A.Update(token: Token): (boolean,string)
  local r,s,reason=acquire(token); if not r or not s then return false,reason end
  publish(r,s); r.busy=false; return true,"Updated"
 end
 function A.Cancel(token: Token, castId: number): (boolean,string)
  local r,s,reason=acquire(token); if not r or not s then return false,reason end
  local ok=rules.cancel(r.state,castId); publish(r,s); r.busy=false
  return ok,if ok then "Pending" else "StaleCast"
 end
 function A.BuffRemoved(token: Token, castId: number): (boolean,string)
  local r,s,reason=acquire(token); if not r or not s then return false,reason end
  local ok=rules.buffRemoved(r.state,castId); publish(r,s); r.busy=false
  return ok,if ok then "Pending" else "StaleCast"
 end
 function A.Convert(token: Token): (boolean,string)
  local r,s,reason=acquire(token); if not r or not s then return false,reason end
  if not s.canCast then r.busy=false; return false,"InvalidState" end
  local ok,why,list=rules.convert(r.state,s.context)
  events(r,list,s); publish(r,s); r.busy=false; return ok,why
 end
 function A.Remove(token: Token): (boolean,string)
  local r=records[token.owner]
  if not r or r.token~=token then return false,"Stale" end
  if r.busy then return false,"Busy" end
  r.busy=true; detach(r); return true,"Removed"
 end
 -- Call at end of epoch; removes any live sessions and all retained owner balances.
 function A.Reset(): (boolean,string)
  for _,r in records do if r.busy then return false,"Busy" end end
  for _,r in records do r.busy=true; detach(r) end
  table.clear(saved); return true,"Reset" -- Quarantine clears only after a new life/epoch, never by retry.
 end
 return A
end
return Adapter
