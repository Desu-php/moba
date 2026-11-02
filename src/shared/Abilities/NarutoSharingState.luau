--!strict
-- Source A0JW facts; not wired to a remote. Native cost/range and raw ability effects remain unresolved.
export type Admission={mana: number,range: number}
export type Target={id: string,life: number,epoch: number,alive: boolean,ally: boolean,hero: boolean,
 structure: boolean,illusion: boolean,rawtype: string,excludedIdentity: boolean,susanoo: boolean,distance: number}
export type Grant={id: string,target: string,life: number,epoch: number,hero: boolean}
export type Event={kind: string,target: string,grant: string?,strength: number?,agility: number?,amount: number?}
export type State={owner: string,life: number,epoch: number,serial: number,clock: number,cooldownAt: number,
 expiresAt: number,selfLockUntil: number,selfAt: number?,selfTicks: number,grants: {[string]: Grant},cancelAt: number,nextBillAt: number,closed: boolean,session: number}
local S={Cooldown=1,Radius=200,Duration=100,SelfLockout=61,DrainPerUnit=4}
S.Native=table.freeze({A0FTParent="AIsr",A0FT_isr2=.35,A092Parent="Aasl",A092_aare=10,A092_Slo1=.10,
 Asp5="RawAbilityIdentityNoInventedResistance",AmaterasuBuffs="Bapl/B04J",AmaterasuUnits="opeo/nina/nmtw/nmsn/nbzw/nehy"})
S.Policy=table.freeze({Admission="DefaultDisabledUnknownCostRange",Timer="OnePerOwnerWholeGroupRefresh100s",
 Removal="AllOwnedAbilitiesIncludingA0FT",Stats="HeroOnlyOwned15Str15Agi",Cleanse="RawSpecificNeverGeneric",
 Lifecycle="OwnerLifeEpochInvalidatesGrants",RecipientDeath="RemoveExactlyOwnedGrant"})
local serial=0
local function finite(n: number): boolean return n==n and math.abs(n)<math.huge end
function S.new(owner: string,life: number,epoch: number,now: number): State
 serial+=1; assert(finite(now))
 return {owner=owner,life=life,epoch=epoch,serial=0,clock=now,cooldownAt=0,expiresAt=0,
 selfLockUntil=0,selfAt=nil,selfTicks=0,grants={},cancelAt=0,nextBillAt=now+1,closed=false,session=serial}
end
function S.eligible(t: Target): boolean
 return finite(t.life) and t.life%1==0 and finite(t.epoch) and t.epoch%1==0 and t.alive and t.ally and not t.structure and not t.illusion and t.rawtype~="Hpb2" and t.rawtype~="Huth"
  and not t.excludedIdentity and not t.susanoo and finite(t.distance) and t.distance>=0 and t.distance<=S.Radius
end
local function remove(s: State,key: string,out: {Event})
 local g=s.grants[key]; if not g then return end; s.grants[key]=nil
 table.insert(out,{kind="RemoveA0FT_A092_Asp5",target=key,grant=g.id,strength=if g.hero then -15 else 0,agility=if g.hero then -15 else 0})
end
function S.revoke(s: State,target: string,life: number,epoch: number): {Event}
 local out: {Event}={}; local g=s.grants[target]
 if g and g.life==life and g.epoch==epoch then remove(s,target,out) end; return out
end
function S.clear(s: State): {Event}
 local out: {Event}={}; for key in s.grants do remove(s,key,out) end; s.expiresAt=0; return out
end
function S.request(s: State,now: number,kcm: boolean,mana: number,castRange: number,targets: {Target},policy: Admission?): (boolean,string,number,{Event})
 if s.closed then return false,"Closed",0,{} end
 if not policy then return false,"NativeAdmissionUnknown",0,{} end
 if not finite(now) or now<s.clock or not finite(mana) or not finite(castRange) or castRange<0
  or not finite(policy.mana) or policy.mana<0 or not finite(policy.range) or policy.range<0 then return false,"Malformed",0,{} end
 if not kcm then return false,"Form",0,{} end
 if now<s.cooldownAt then return false,"Cooldown",0,{} end
 if castRange>policy.range then return false,"Range",0,{} end
 if mana<policy.mana then return false,"Mana",0,{} end
 local out: {Event}={}; if now>=s.expiresAt then out=S.clear(s) end
 s.clock=now; s.cooldownAt=now+1; s.expiresAt=now+S.Duration
 for _,t in targets do
  if S.eligible(t) and t.epoch==s.epoch then
   if t.id==s.owner then
    if t.life==s.life and now>=s.selfLockUntil then
     s.selfLockUntil=now+S.SelfLockout; s.selfAt=now+1; s.selfTicks=0
     table.insert(out,{kind="SelfHeal",target=s.owner,amount=350})
     table.insert(out,{kind="RemoveAmaterasuRawWithin25",target=s.owner})
    end
   else
    local old=s.grants[t.id]
    if old and (old.life~=t.life or old.epoch~=t.epoch) then remove(s,t.id,out); old=nil end
    if not old then
     s.serial+=1
     local g: Grant={id=s.owner..":"..s.epoch..":"..s.life..":"..s.session..":"..s.serial,target=t.id,life=t.life,epoch=t.epoch,hero=t.hero}
     s.grants[t.id]=g
     table.insert(out,{kind="GrantA0FT_A092_Asp5",target=t.id,grant=g.id,strength=if t.hero then 15 else 0,agility=if t.hero then 15 else 0})
    end
   end
  end
 end
 return true,"PolicyAccepted",policy.mana,out
end
-- Caller supplies current authoritative recipient life/epoch/liveness; nil entries are invalid.
function S.update(s: State,now: number,ownerAlive: boolean,current: {[string]: Target}): {Event}
 if s.closed or not finite(now) or now<s.clock then return {} end; s.clock=now
 if not ownerAlive then return S.close(s) end
 local out: {Event}={}
 for key,g in s.grants do
  local t=current[key]
  if now>=s.expiresAt or not t or not t.alive or t.life~=g.life or t.epoch~=g.epoch then remove(s,key,out) end
 end
 while s.selfAt and now>=s.selfAt and s.selfTicks<2 do
  s.selfTicks+=1; table.insert(out,{kind="SelfHeal",target=s.owner,amount=350})
  if s.selfTicks==2 then s.selfAt=nil else s.selfAt+=1 end
 end
 return out
end
-- Called on the resource owner's1s phase, not once per cast. At/above threshold skips the entire bill.
function S.pay(s: State,now: number,chakra: number,threshold: number): (number,{Event})
 if s.closed or not finite(now) or now<s.clock or now<s.nextBillAt or not finite(chakra) or chakra<0 or not finite(threshold) then return 0,{} end
 s.nextBillAt+=math.floor(now-s.nextBillAt)+1
 if chakra>=threshold then return 0,{} end
 local count=0; for _ in s.grants do count+=1 end
 local cost=count*S.DrainPerUnit
 if chakra<cost then return 0,S.clear(s) end
 return cost,{}
end
function S.cancel(s: State,now: number): (boolean,{Event})
 if s.closed or not finite(now) or now<s.clock or now<s.cancelAt then return false,{} end
 s.cancelAt=now+2; return true,S.clear(s)
end
function S.close(s: State): {Event} s.closed=true; s.selfAt=nil; s.selfLockUntil=0; return S.clear(s) end
return S
