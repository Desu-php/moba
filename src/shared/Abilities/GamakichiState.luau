--!strict
-- A005 object facts. Policy below is a bounded Roblox adaptation, not native parity.
export type Profile = { read health: number, read regen: number, read armor: number, read speed: number, read mana: number, read rawDamage: number, read adult: boolean }
export type Cast = { id: number, rank: number, expiresAt: number, profile: Profile }
export type State = { serial: number, lastRequest: number, cooldownAt: number, active: Cast? }
local G = {}
G.Policy = table.freeze({ FirstLevel=1, LevelSkip=2, AttackInterval=2, DamagePoint=.5,
 FollowDistance=10, SpawnOffset=8, CancelOnOwnerDeath=true })
local early: Profile = table.freeze({health=500,regen=2,armor=7,speed=350,mana=500,rawDamage=41,adult=false})
local adult: Profile = table.freeze({health=1500,regen=5,armor=15,speed=400,mana=1000,rawDamage=101,adult=true})
function G.rank(rank: number): (number?, number?, number?, Profile?)
 if rank~=rank or rank%1~=0 or rank<1 or rank>10 then return nil,nil,nil,nil end
 return if rank<=4 then 50 elseif rank<=8 then 150 else 300, if rank<=5 then 60 else 150, 5+5*rank, if rank<=5 then early else adult
end
function G.new(): State return {serial=0,lastRequest=0,cooldownAt=0,active=nil} end
function G.request(state: State, now: number, request: number, rank: number, mana: number): (Cast?, string, number)
 if request~=request or request<1 or request%1~=0 or request==math.huge then return nil,"Malformed",0 end
 if request<=state.lastRequest then return nil,"Replay",0 end
 state.lastRequest=request
 local cost,cd,duration,profile=G.rank(rank)
 if not cost or not cd or not duration or not profile then return nil,"Unlearned",0 end
 if now<state.cooldownAt then return nil,"Cooldown",0 end
 if mana<cost then return nil,"Mana",0 end
 state.serial+=1
 local cast: Cast={id=state.serial,rank=rank,expiresAt=now+duration,profile=profile}
 state.active=cast; state.cooldownAt=now+cd
 return cast,"Accepted",cost
end
function G.live(state: State, cast: Cast, now: number): boolean return state.active==cast and now<cast.expiresAt end
function G.cancel(state: State) state.active=nil end
function G.expire(state: State, now: number): boolean
 local cast=state.active
 if cast and now>=cast.expiresAt then G.cancel(state); return true end
 return false
end
return G
