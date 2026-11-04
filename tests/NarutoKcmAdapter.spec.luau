--!strict
local Config=require("../src/shared/Abilities/NarutoKcmConfig")
local Domain=require("../src/shared/Abilities/NarutoKcmState").configure(Config)
local Adapter=require("../src/shared/Abilities/NarutoKcmAdapter")
local count=0
local function check(name: string, ok: boolean) assert(ok,name); count+=1 end
local function snapshot(): Adapter.Snapshot
 return {life=1,epoch=1,eligible=true,canCast=true,
  context={level=20,rank=2,hagoromo=false,alive=true,fullKurama=false,kuramaCooldown=false,
   sageRemaining=0,sageAuraPresent=false},
  allowed={kcm=true,gamakichi=true,sage=true,dash=true,sharing=true,fullKurama=true}}
end
local function fixture(enabled: boolean?)
 local time=0
 local snapshots: {[string]: Adapter.Snapshot}={a=snapshot(),b=snapshot()}
 local output: {[number]: {chakra: number,mask: Adapter.Availability,cooldownAt: number}}={}
 local effects: {[number]: {[string]: number}}={}
 local applied: {[number]: number}={}; local removed: {[number]: number}={}
 local reapply: {[number]: number}={}; local mana: {[number]: number}={}
 local revoked: {[number]: number}={}; local faults: {[string]: number}={}
 local behavior={apply=true,throwApply=false,throwRemove=false}
 local hook: (() -> ())?=nil
 local ports: Adapter.Ports={
  now=function() return time end,
  read=function(owner) return snapshots[owner] end,
  publish=function(token,chakra,mask,cooldownAt) output[token.serial]={chakra=chakra,mask=mask,cooldownAt=cooldownAt} end,
  effect=function(token,kind,_id)
   local e=effects[token.serial] or {}; effects[token.serial]=e; e[kind]=(e[kind] or 0)+1
  end,
  reapplySage=function(token) reapply[token.serial]=(reapply[token.serial] or 0)+1 end,
  restoreMana=function(token,amount) mana[token.serial]=(mana[token.serial] or 0)+amount end,
  revokeSharing=function(token) revoked[token.serial]=(revoked[token.serial] or 0)+1 end,
  fault=function(_token,reason) faults[reason]=(faults[reason] or 0)+1 end,
 }
 local policy: Adapter.MorphPolicy={enabled=enabled~=false,
  apply=function(token,_rank)
   applied[token.serial]=(applied[token.serial] or 0)+1
   if hook then hook() end
   if behavior.throwApply then error("partial apply") end
   return behavior.apply
  end,
  remove=function(token,_rank)
   removed[token.serial]=(removed[token.serial] or 0)+1
   if behavior.throwRemove then error("cleanup failure") end
  end,
 }
 return {a=Adapter.configure(Domain,ports,policy),ports=ports,policy=policy,snapshots=snapshots,output=output,
  effects=effects,applied=applied,removed=removed,reapply=reapply,mana=mana,revoked=revoked,
  faults=faults,behavior=behavior,time=function(at: number) time=at end,
  hook=function(nextHook: (() -> ())?) hook=nextHook end}
end
local f=fixture(); local t=f.a.Bind("a"); assert(t)
check("bind publishes separate600",f.output[t.serial].chakra==600)
check("no policy defaultdisabled",select(2,Adapter.configure(Domain,f.ports).Bind("a"))=="Disabled")
local disabled=fixture(false); check("explicit disabled",select(2,disabled.a.Bind("a"))=="Disabled")
check("same life binding idempotent",f.a.Bind("a")==t)
local ok,why=f.a.Enter(t); check("authoritative entry",ok and why=="Accepted" and f.output[t.serial].chakra==400)
check("morph once effects once",f.applied[t.serial]==1 and f.effects[t.serial].Entered==1)
check("KCM disables summon while allowing layered Sage",not f.output[t.serial].mask.gamakichi and f.output[t.serial].mask.sage)
check("authoritative active getter",f.a.IsActive(t))
check("private active morph rank",f.a.ActiveCast(t)==2)
f.snapshots.a.context.rank=3;check("learning does not upgrade active morph",f.a.ActiveCast(t)==2);f.snapshots.a.context.rank=2
check("private dash getter initially false",not f.a.IsDashReady(t))
f.time(.5); f.a.Update(t); check("dash exposed at halfsecond",f.effects[t.serial].DashReady==1 and f.output[t.serial].mask.dash)
f.a.Update(t); check("duplicate update no duplicateeffects",f.effects[t.serial].DashReady==1)
check("private dash getter ready",f.a.IsDashReady(t))
f.time(.6); check("cancel markedpending",select(2,f.a.Cancel(t,1))=="Pending" and f.removed[t.serial]==nil)
f.snapshots.a.allowed.gamakichi=false; f.snapshots.a.allowed.fullKurama=false
f.time(1); f.a.Update(t)
check("final40 drain",f.output[t.serial].chakra==360)
check("cleanup each exactlyonce",f.removed[t.serial]==1 and f.effects[t.serial].Exited==1)
check("restores eligible Sage only",f.output[t.serial].mask.sage and not f.output[t.serial].mask.gamakichi and not f.output[t.serial].mask.fullKurama)
f.a.Update(t); check("repeat cleanup no duplicate",f.removed[t.serial]==1)
check("active getter false after exit",not f.a.IsActive(t))
check("private morph absent after exit",f.a.ActiveCast(t)==nil)
check("private dash getter false after exit",not f.a.IsDashReady(t))
f.time(10); f.a.Enter(t); check("secondcast",f.applied[t.serial]==2)
check("stale cast cancellation rejected",select(2,f.a.Cancel(t,1))=="StaleCast")
f.time(10.5); f.a.BuffRemoved(t,2); f.time(11); f.a.Update(t)
check("buff removal ends secondcast",f.removed[t.serial]==2)
local b=f.a.Bind("b"); assert(b); check("owner resource isolation",f.output[b.serial].chakra==600 and f.output[t.serial].chakra~=600)
f.a.Enter(b); f.snapshots.b.context.alive=false; f.time(11.25); ok,why=f.a.Update(b)
check("death closes immediately",not ok and why=="InvalidState" and f.removed[b.serial]==1)
check("death suppresses reenable",not f.output[b.serial].mask.kcm and not f.output[b.serial].mask.sage)
check("dead token cannot cast",select(2,f.a.Enter(b))=="Stale")
f.snapshots.b.context.alive=true; f.snapshots.b.life=2
local respawn=f.a.Bind("b"); assert(respawn)
check("sameepoch respawn preserves pool",f.output[respawn.serial].chakra==400)
check("sameepoch respawn preserves cooldown",select(2,f.a.Enter(respawn))=="Cooldown")
check("old life token rejected",select(2,f.a.BuffRemoved(b,1))=="Stale")
f.snapshots.b.epoch=2; f.snapshots.b.life=3; local nextRound=f.a.Bind("b"); assert(nextRound)
check("newepoch initial600",f.output[nextRound.serial].chakra==600)
f.a.Enter(nextRound); f.snapshots.b.life=4; f.a.Update(nextRound)
check("life mismatch cleanup scoped oldtoken",f.removed[nextRound.serial]==1 and select(2,f.a.Enter(nextRound))=="Stale")
f=fixture(); t=f.a.Bind("a"); assert(t); f.snapshots.a.canCast=false
ok=f.a.Enter(t); check("busy character cannot enter",not ok and f.applied[t.serial]==nil and f.output[t.serial].chakra==600)
f.snapshots.a.canCast=true; f.snapshots.a.context.rank=3; f.snapshots.a.context.level=27
check("Hagoromo gate beforepolicy",select(2,f.a.Enter(t))=="Hagoromo" and f.applied[t.serial]==nil)
f.snapshots.a.context.hagoromo=true; f.snapshots.a.allowed.kcm=false
check("authoritative permissions beforepolicy",select(2,f.a.Enter(t))=="InvalidState" and f.applied[t.serial]==nil)
f.snapshots.a.allowed.kcm=true; f.behavior.apply=false
check("policy rejection returns",select(2,f.a.Enter(t))=="MorphRejected")
check("partial policy rollback once nocharge",f.removed[t.serial]==1 and f.output[t.serial].chakra==600 and f.effects[t.serial]==nil)
f.behavior.apply=true; f.behavior.throwApply=true; f.a.Enter(t)
check("policy exception rollback nocharge",f.removed[t.serial]==2 and f.output[t.serial].chakra==600)
f.behavior.throwApply=false; f.hook(function() f.snapshots.a.context.rank=0 end)
check("revalidates afterpolicy",select(2,f.a.Enter(t))=="Unlearned" and f.output[t.serial].chakra==600 and f.removed[t.serial]==3)
f.hook(nil); f.snapshots.a.context.rank=2; f.snapshots.a.context.level=20
local reentrant=""; f.hook(function() local _,r=f.a.Enter(t :: Adapter.Token); reentrant=r end)
f.a.Enter(t); check("reentrant entry blocked",reentrant=="Busy" and f.applied[t.serial]==4 and f.output[t.serial].chakra==400)
f.hook(nil); f.behavior.throwRemove=true; f.a.Cancel(t,1); f.time(1); ok,why=f.a.Update(t)
check("cleanup exception quarantines session",not ok and why=="PortFault" and f.faults.MorphRemoveFailed==1)
f.a.Update(t); check("failed cleanup not retried automatically",f.removed[t.serial]==4 and select(2,f.a.Enter(t))=="Stale")
check("failed removal blocks same life rebind",select(2,f.a.Bind("a"))=="PortFault")
f.a.Reset(); check("reset cannot bypass quarantined life",select(2,f.a.Bind("a"))=="PortFault")
f.snapshots.a.life=2; check("new life may bind after fault",f.a.Bind("a")~=nil)
f=fixture(); t=f.a.Bind("a"); assert(t); f.hook(function() f.snapshots.a.life=2 end)
check("lifechange during apply refuses cast",select(2,f.a.Enter(t))=="MorphRejected" and f.removed[t.serial]==1)
check("lifechange debits nothing",f.output[t.serial].chakra==600 and not f.output[t.serial].mask.kcm)
f=fixture(); t=f.a.Bind("a"); assert(t)
f.hook(function() f.snapshots.a.context.rank=3; f.snapshots.a.context.level=27; f.snapshots.a.context.hagoromo=true end)
check("valid rank change cannot commit wrong morph",select(2,f.a.Enter(t))=="MorphRejected" and f.output[t.serial].chakra==600 and f.removed[t.serial]==1)
local forged: Adapter.Token={owner=t.owner,life=t.life,epoch=t.epoch,serial=t.serial}
check("token value forgery rejected",select(2,f.a.Enter(forged))=="Stale")
f=fixture(); t=f.a.Bind("a"); assert(t); f.snapshots.a.context.sageRemaining=20; f.snapshots.a.context.sageAuraPresent=true
f.a.Enter(t); f.time(.5); f.a.Update(t)
check("Sage reapply on morph",f.reapply[t.serial]==1 and f.snapshots.a.context.sageRemaining==20)
f.a.Cancel(t,1); f.time(1); f.a.Update(t)
check("Sage reapply on exit without resetting",f.reapply[t.serial]==2 and f.snapshots.a.context.sageRemaining==20)
f.time(10); f.a.Enter(t); f.snapshots.a.context.sageRemaining=0; f.time(10.5); f.a.Update(t)
check("expired Sage not revived",f.reapply[t.serial]==2)
f.snapshots.a.context.alive=false; f.a.Update(t); check("death no Sage callback",f.reapply[t.serial]==2)
f=fixture(); t=f.a.Bind("a"); assert(t); f.a.Convert(t)
check("conversion applied once",f.output[t.serial].chakra==400 and f.mana[t.serial]==200)
f.a.Convert(t); f.a.Convert(t); ok=f.a.Convert(t)
check("insufficient conversion no mana",not ok and f.mana[t.serial]==600 and f.output[t.serial].chakra==0)
f=fixture(); t=f.a.Bind("a"); assert(t); f.a.Enter(t); f.time(-1)
check("rollback clock rejected",select(2,f.a.Update(t))=="Clock" and f.output[t.serial].chakra==400)
f.time(0/0); check("NaN clock rejected",select(2,f.a.Update(t))=="Clock")
f.time(61); check("clockgap quarantines",select(2,f.a.Update(t))=="ClockGap" and f.faults.ClockGap==1 and f.removed[t.serial]==1)
f=fixture(); t=f.a.Bind("a"); assert(t); f.a.Enter(t); f.a.Remove(t); f.a.Remove(t)
check("remove idempotently cleans once",f.removed[t.serial]==1 and f.effects[t.serial].Exited==1)
local again=f.a.Bind("a"); assert(again); check("remove rebind sameepoch no refill",f.output[again.serial].chakra==400)
f.a.Reset(); again=f.a.Bind("a"); assert(again); check("reset clears retained balances",f.output[again.serial].chakra==600)
f=fixture(); t=f.a.Bind("a"); assert(t); f.a.Enter(t); f.policy.enabled=false
check("disabling policy tears down live form",select(2,f.a.Update(t))=="Disabled" and f.removed[t.serial]==1 and not f.output[t.serial].mask.kcm)
f=fixture(); f.snapshots.a.context.level=0/0
check("invalid snapshot cannot bind",select(2,f.a.Bind("a"))=="InvalidState")
f=fixture(); t=f.a.Bind("a"); assert(t); f.a.Enter(t); f.snapshots.a.eligible=false
check("match invalidstate closes",select(2,f.a.Update(t))=="InvalidState" and f.removed[t.serial]==1)
f=fixture(); t=f.a.Bind("a"); assert(t); f.a.Enter(t)
check("publish domain entry deadline",f.output[t.serial].cooldownAt==10 and f.output[t.serial].chakra==400)
f.a.Remove(t); f.time(2); f.snapshots.a.life=2
local rejoined=f.a.Bind("a"); assert(rejoined)
check("reconnect publishes retained deadline and chakra",f.output[rejoined.serial].cooldownAt==10 and f.output[rejoined.serial].chakra==400)
check("reconnect cooldown rejects without debit",select(2,f.a.Enter(rejoined))=="Cooldown" and f.output[rejoined.serial].chakra==400)
check("stale token cannot change rejoin publication",select(2,f.a.Update(t))=="Stale" and f.output[rejoined.serial].cooldownAt==10)
f.time(10); check("rejoin enters at retained deadline",f.a.Enter(rejoined))
check("publish next domain deadline",f.output[rejoined.serial].cooldownAt==20)
f.snapshots.a.epoch=2; f.snapshots.a.life=3
local epochToken=f.a.Bind("a"); assert(epochToken)
check("new epoch publishes fresh pool and deadline",f.output[epochToken.serial].chakra==600 and f.output[epochToken.serial].cooldownAt==10)
f=fixture(); t=f.a.Bind("a"); assert(t)
check("externalcost ledgerprivate",f.a.Chakra(t)==600 and f.a.SpendChakra(t,200) and f.a.Chakra(t)==400)
check("externalcost cannot overdraw or refund",not f.a.SpendChakra(t,401) and not f.a.SpendChakra(t,-1) and f.a.Chakra(t)==400)
f.snapshots.a.context.rank=3; f.snapshots.a.context.level=27; f.snapshots.a.context.hagoromo=true
f.a.Enter(t); check("active rank3 marker distinct fromunlock",f.a.ActiveRank(t)==3)
f.a.Cancel(t,1); f.time(1); f.a.Update(t)
check("rank3 marker clears whileunlock remains",f.a.ActiveRank(t)==0 and f.snapshots.a.context.hagoromo)
f.snapshots.a.context.fullKurama=true; f.time(2); f.a.Update(t)
check("Kurama nativeflag blocks KCM entry",select(2,f.a.Enter(t))=="FormBusy")
f.snapshots.a.context.fullKurama=false; f.snapshots.a.context.kuramaCooldown=true; f.time(3); f.a.Update(t)
check("postbuff scriptlock blocks KCM",select(2,f.a.Enter(t))=="KuramaLocked")
print("ALL PASS: "..count.." NarutoKcm adapter fake-port checks; no Roblox/native morph certification")

-- Developer reset changes only this owned cooldown; active form/resources survive.
do
 local g=fixture();local a=g.a.Bind("a");local b=g.a.Bind("b");assert(a and b)
 assert(g.a.Enter(a));assert(g.a.Enter(b))
 local chakra=g.a.Chakra(a);local rank,cast=g.a.ActiveCast(a);local other=g.output[b.serial].cooldownAt
 assert(g.a.ResetCooldown(a));assert(g.output[a.serial].cooldownAt==0)
 assert(g.a.Chakra(a)==chakra and g.a.ActiveCast(a)==rank and select(2,g.a.ActiveCast(a))==cast)
 assert(g.output[b.serial].cooldownAt==other)
 g.snapshots.a.life=2;assert(not g.a.ResetCooldown(a))
 print("PASS KCM cooldown reset: active form/chakra preserved, owner and life isolated")
end
