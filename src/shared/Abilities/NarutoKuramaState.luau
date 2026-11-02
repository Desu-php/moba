--!strict
-- A01F / agr_nar facts from the preserved raw audit; guards/retention are explicit adaptations.
export type Proc={id: number,at: number,x: number,y: number,z: number}
export type Cast={id: number,startedAt: number,expiresAt: number,buff: boolean,removed: boolean,proc: Proc?,threeHead: boolean,externalBuff: boolean}
export type State={owner: string,epoch: number,life: number,serial: number,cooldownAt: number,clock: number,active: Cast?,blockedUntil: number,threeHeadAt: number}
export type Clone={id: string,owner: string,life: number,epoch: number,alive: boolean,mana: number,rawtype: string}
export type Pair={first: string,second: string,ordinaryMana: number,armor: number,attack: number}
export type Context={level: number,alive: boolean,canCast: boolean,kcm: boolean,chakra: number}
export type Event={kind: string,id: number}
export type Balance={cooldownAt: number,threeHeadAt: number}
local F={Cost=2500,Cooldown=160,Duration=30,PollAfter=25,ProcDelay=.2,ProcSuppression=.7,ProcRadius=300}
F.RawEwar=table.freeze({health=2800,armor=20,attack=100,speed=375,mana=1300,range=150,attackCooldown=2})
F.Policy=table.freeze({Retention="EwarBaseDeltaPreserveLedgerV1",Death="ImmediateOwnedCleanup",
 ProcIsolation="PerOwnerLifeEpoch",Damage="ExistingServerMitigation",BuffDuration="Roblox30SecondsOrExplicitRemoval",
 AbilityRetention="PreserveLearnedExceptKcmWhileLocked",FailedAdmission="PreflightNoCooldownDebit",ThreeHeadAdmission="UnknownNativeCostDisabled"})
F.ThreeHead=table.freeze({Cooldown=600,Range=0,CostStatus="InheritedUnknown",RuntimeReady=false})
F.A011=table.freeze({Mana=300,Cooldown=100,Range=2500,RuntimeReady=false,EffectStatus="DownstreamNotCertified"})
local function finite(n: number): boolean return n==n and math.abs(n)<math.huge end
function F.new(owner: string,epoch: number,life: number,now: number,balance: Balance?): State
 assert(finite(now))
 if balance then assert(finite(balance.cooldownAt) and balance.cooldownAt>=0 and finite(balance.threeHeadAt) and balance.threeHeadAt>=0) end
 return {owner=owner,epoch=epoch,life=life,serial=0,cooldownAt=if balance then balance.cooldownAt else 0,clock=now,active=nil,blockedUntil=0,threeHeadAt=if balance then balance.threeHeadAt else 0}
end
function F.balance(s: State): Balance return {cooldownAt=s.cooldownAt,threeHeadAt=s.threeHeadAt} end
function F.isActive(s: State): boolean local c=s.active; return c~=nil and c.buff end
function F.isLocked(s: State): boolean return s.active~=nil end
function F.request(s: State,now: number,c: Context): (boolean,string,number)
 if not finite(now) or now<s.clock or not finite(c.level) or not finite(c.chakra) then return false,"Malformed",0 end
 if not c.alive or not c.canCast then return false,"Busy",0 end
 if c.level<21 then return false,"Level",0 end
 if s.active or c.kcm then return false,"Form",0 end
 if now<s.cooldownAt then return false,"Cooldown",0 end
 if c.chakra<F.Cost then return false,"Chakra",0 end
 s.serial+=1; s.clock=now; s.cooldownAt=now+F.Cooldown; s.blockedUntil=0
 s.active={id=s.serial,startedAt=now,expiresAt=now+F.Duration,buff=true,removed=false,proc=nil,threeHead=false,externalBuff=false}
 return true,"Accepted",F.Cost
end
function F.observeBuff(s: State,id: number,present: boolean): boolean
 local c=s.active; if not c or c.id~=id or c.removed then return false end
 c.externalBuff=true; c.buff=present; if not present then c.proc=nil end; return true
end
function F.buffRemoved(s: State,id: number): boolean
 local c=s.active; if not c or c.id~=id then return false end; c.buff=false; c.proc=nil; return true
end
function F.update(s: State,now: number,alive: boolean): {Event}
 local out: {Event}={}; if not finite(now) or now<s.clock then return out end; s.clock=now
 local c=s.active; if not c then return out end
 if not alive or (not c.externalBuff and now>=c.expiresAt) then c.buff=false; c.proc=nil end
 if not c.buff and not c.removed then c.removed=true; table.insert(out,{kind="Exited",id=c.id}) end
 if not alive or (not c.buff and now>=c.startedAt+F.PollAfter) then
  s.active=nil; table.insert(out,{kind="Released",id=c.id})
 end
 return out
end
function F.newLife(s: State,epoch: number,life: number,now: number): {Event}
 local out=F.update(s,math.max(now,s.clock),false)
 if epoch~=s.epoch then s.cooldownAt=0; s.threeHeadAt=0 end
 s.epoch=epoch; s.life=life; s.blockedUntil=0; return out
end
function F.attackStart(s: State,now: number,roll: number,illusion: boolean,hasTarget: boolean,x: number,y: number,z: number): boolean
 local c=s.active
 if not c or not c.buff or (not c.externalBuff and now>=c.expiresAt) or not finite(now) or now<s.clock or now<s.blockedUntil
  or c.proc~=nil or not finite(roll) or roll<1 or roll>100 or roll>12 or illusion or not hasTarget
  or not finite(x) or not finite(y) or not finite(z) then return false end
 s.blockedUntil=now+F.ProcSuppression; c.proc={id=c.id,at=now+F.ProcDelay,x=x,y=y,z=z}; return true
end
function F.claimProc(s: State,now: number,currentMaxHealth: number): (Proc?,number?)
 local c=s.active; local p=if c then c.proc else nil
 if not c or not c.buff or not p or p.id~=c.id or not finite(now) or now<s.clock or now<p.at
  or (not c.externalBuff and now>=c.expiresAt) or not finite(currentMaxHealth) or currentMaxHealth<=0 then return nil,nil end
 c.proc=nil; return p,currentMaxHealth/25
end
-- Headless plan only. No world ability is exposed while inherited native cost remains unknown.
function F.consumeThreeHead(s: State,now: number,pair: {Clone},mana: number,policyCost: number?): (boolean,string,number,Pair?)
 if policyCost==nil then return false,"NativeCostUnknown",0,nil end
 local c=s.active
 if not finite(now) or now<s.clock or not finite(mana) or not finite(policyCost) or policyCost<0 then return false,"Malformed",0,nil end
 if not c or not c.buff or (not c.externalBuff and now>=c.expiresAt) then return false,"Form",0,nil end
 if c.threeHead or now<s.threeHeadAt then return false,"Cooldown",0,nil end
 if #pair~=2 or pair[1].id==pair[2].id then return false,"Pair",0,nil end
 for _,clone in pair do
  if clone.rawtype~="nmbg" or not clone.alive or clone.owner~=s.owner or clone.life~=s.life or clone.epoch~=s.epoch
   or not finite(clone.mana) or clone.mana<0 then return false,"Pair",0,nil end
 end
 if mana<policyCost then return false,"Mana",0,nil end
 c.threeHead=true; s.threeHeadAt=now+600
 return true,"PolicyAccepted",policyCost,{first=pair[1].id,second=pair[2].id,ordinaryMana=pair[1].mana+pair[2].mana,armor=10,attack=80}
end
function F.modifier(): {health: number,armor: number,attack: number,speedWarcraft: number}
 return {health=2500,armor=20,attack=90,speedWarcraft=105} -- Ewar minus Hpal raw bases, selected adaptation.
end
return F
