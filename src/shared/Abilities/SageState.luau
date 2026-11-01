--!strict
-- A09J direct mode. Native inherited values are separated from explicit fields.
local S={}
S.Mana=25; S.Cooldown=150
S.Source=table.freeze({MinimumLevels={6,10,14},Preparation={10,7,4},ManaRestore={200,350,500},Attack={10,30,50},SpeedWarcraft=105})
S.Policy=table.freeze({RuntimeRanks=2,Armor={3,7},ArmorProvisional=true,Health={150,200},CleanupSeconds=51,AuraSeconds=47,CapacityDoesNotHeal=true,MeditationImplemented=false})
export type Modifier={health: number,armor: number,attack: number,speedWarcraft: number}
export type Cast={id: number,owner: string,round: number,life: number,rank: number,phase: string,readyAt: number,expiresAt: number,auraUntil: number,activated: boolean}
export type State={owner: string,round: number,life: number,serial: number,lastRequest: number,cooldownAt: number,active: Cast?}
local function finite(x: number): boolean return x==x and math.abs(x)<math.huge end
function S.new(owner: string,round: number,life: number): State return {owner=owner,round=round,life=life,serial=0,lastRequest=0,cooldownAt=0,active=nil} end
function S.modifier(rank: number): Modifier?
 if rank%1~=0 or rank<1 or rank>S.Policy.RuntimeRanks then return nil end
 return {health=S.Policy.Health[rank],armor=S.Policy.Armor[rank],attack=S.Source.Attack[rank],speedWarcraft=S.Source.SpeedWarcraft}
end
function S.request(state: State,now: number,request: number,rank: number,level: number,mana: number): (Cast?,string,number)
 if not finite(now) or not finite(request) or request<1 or request%1~=0 then return nil,"Malformed",0 end
 if request<=state.lastRequest then return nil,"Replay",0 end
 state.lastRequest=request
 if not finite(rank) or not S.modifier(rank) then return nil,"NotImplemented",0 end
 if not finite(level) or level<S.Source.MinimumLevels[rank] then return nil,"Level",0 end
 if state.active then return nil,"Busy",0 end
 if now<state.cooldownAt then return nil,"Cooldown",0 end
 if not finite(mana) or mana<S.Mana then return nil,"Mana",0 end
 state.serial+=1; state.cooldownAt=now+S.Cooldown
 local ready=now+S.Source.Preparation[rank]
 local cast: Cast={id=state.serial,owner=state.owner,round=state.round,life=state.life,rank=rank,phase="Preparing",readyAt=ready,expiresAt=ready+S.Policy.CleanupSeconds,auraUntil=ready+S.Policy.AuraSeconds,activated=false}
 state.active=cast; return cast,"Accepted",S.Mana
end
function S.live(state: State,cast: Cast): boolean return state.active==cast and state.owner==cast.owner and state.round==cast.round and state.life==cast.life end
function S.activate(state: State,now: number): Cast?
 if not finite(now) then return nil end
 local cast=state.active
 if not cast or not S.live(state,cast) or cast.activated or now<cast.readyAt or now>=cast.expiresAt then return nil end
 cast.activated=true; cast.phase="Active"; return cast
end
function S.expire(state: State,now: number): boolean
 if not finite(now) then return false end
 if state.active and now>=state.active.expiresAt then state.active=nil; return true end
 return false
end
function S.cancel(state: State): boolean local had=state.active~=nil; state.active=nil; return had end
function S.newLife(state: State,round: number,life: number) state.active=nil; state.round=round; state.life=life end
function S.reset(state: State,round: number,life: number) S.newLife(state,round,life); state.cooldownAt=0; state.lastRequest=0 end
return S
