--!strict
-- Explicit object overrides + separately named Roblox native-policy adaptations.
local S={}
S.Oil=table.freeze({Range=750,Radius=150,Duration=6,Cooldown=25,Mana=0,ProjectileSpeed=900,Arc=.05,MissChance=.3,MoveReduction=.4})
S.Chopping=table.freeze({Range=250,Radius=400,Waves=4,Damage=120,WaveCap=750,CastTime=.5,Cooldown=30,Mana=0})
S.NativePolicy=table.freeze({WaveInterval=1,FirstWaveAfterPreparation=true,RefreshNonStacking=true,
 AttackSpeedReductionImplemented=false,UnverifiedNsi4=.4,ClearOnSourceRemoval=true})
export type Flight={id: number,at: number}
export type Channel={id: number,nextAt: number,wave: number}
export type State={serial: number,lastRequest: number,oilReady: number,chopReady: number,flight: Flight?,channel: Channel?}
function S.new(): State return {serial=0,lastRequest=0,oilReady=0,chopReady=0,flight=nil,channel=nil} end
function S.request(state: State,id: string,now: number,request: number,adult: boolean,travel: number): (boolean,string)
 if request~=request or request%1~=0 or request<1 or request==math.huge then return false,"Malformed" end
 if request<=state.lastRequest then return false,"Replay" end
 state.lastRequest=request
 if id~="GamakichiOil" and id~="GamakichiChop" then return false,"Unsupported" end
 if id=="GamakichiChop" and not adult then return false,"Rank" end
 if state.flight or state.channel then return false,"Busy" end
 if now<(if id=="GamakichiOil" then state.oilReady else state.chopReady) then return false,"Cooldown" end
 if travel~=travel or travel<0 or travel==math.huge then return false,"Malformed" end
 state.serial+=1
 if id=="GamakichiOil" then
  state.oilReady=now+S.Oil.Cooldown; state.flight={id=state.serial,at=now+travel}
 else
  state.chopReady=now+S.Chopping.Cooldown; state.channel={id=state.serial,nextAt=now+S.Chopping.CastTime,wave=0}
 end
 return true,"Accepted"
end
function S.claimOil(state: State,now: number): boolean
 if not state.flight or now<state.flight.at then return false end
 state.flight=nil; return true
end
function S.claimWave(state: State,now: number): number?
 local c=state.channel; if not c or now<c.nextAt then return nil end
 c.wave+=1; local wave=c.wave
 c.nextAt+=S.NativePolicy.WaveInterval
 if wave>=S.Chopping.Waves then state.channel=nil end
 return wave
end
function S.cancel(state: State) state.flight=nil; state.channel=nil end
-- Grant IDs preserve independent casters; refresh, never multiply slow/miss chance.
export type Debuff={grants: {[string]: number}}
function S.debuff(): Debuff return {grants={}} end
function S.apply(d: Debuff,key: string,now: number) d.grants[key]=now+S.Oil.Duration end
function S.clear(d: Debuff,key: string) d.grants[key]=nil end
function S.untilAt(d: Debuff,now: number): number
 local ends=0
 for key,t in d.grants do if t<=now then d.grants[key]=nil else ends=math.max(ends,t) end end
 return ends
end
function S.movement(d: Debuff,now: number): number return if S.untilAt(d,now)>now then 1-S.Oil.MoveReduction else 1 end
function S.misses(d: Debuff,now: number,roll: number): boolean
 return roll==roll and roll>=0 and roll<1 and S.untilAt(d,now)>now and roll<S.Oil.MissChance
end
-- Deterministic equal split is the selected cap policy; not a certified Blizzard allocation order.
function S.waveDamage(targetCount: number): number
 return if targetCount>0 then math.min(S.Chopping.Damage,S.Chopping.WaveCap/targetCount) else 0
end
return S
