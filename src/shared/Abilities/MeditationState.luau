--!strict
-- forms contract JASS 44774-44826, 44227-44296. No Roblox dependencies.
local M = {}
export type Form = "Ordinary" | "KCM" | "Kurama"
export type Clone = {id: number, owner: string, round: number, life: number, mana: number, maximum: number, regen: number, updatedAt: number, expiresAt: number, settled: boolean}
export type State = {owner: string, round: number, life: number, serial: number, clones: {[number]: Clone}}
-- Native initial mana for nmdr/nmcf is omitted; zero is explicit safe policy.
M.Policy = table.freeze({OrdinaryInitialMana=0, InitialManaProvisional=true, Lifetime=35, OwnerInvalidationTransfers=false, RecallCost=0, RecallCostProvisional=true, RecallCooldown=5})
local function finite(n: number): boolean return n==n and math.abs(n)<math.huge end
function M.new(owner: string, round: number, life: number): State
 return {owner=owner,round=round,life=life,serial=0,clones={}}
end
function M.plan(rank: number, level: number, form: Form): (number,number,number)
 if not finite(rank) or rank%1~=0 or rank<1 or rank>3 or not finite(level) or level%1~=0 or level<1 or level>30 then return 0,0,0 end
 if form=="Kurama" then return 2,2000,100 end
 if form~="Ordinary" and form~="KCM" then return 0,0,0 end
 local two = rank==3 and (if form=="KCM" then level>18 else level>=18)
 return if two then 2 else 1,500,20
end
function M.spawn(state: State, now: number, rank: number, level: number, form: Form): {Clone}
 if not finite(now) then return {} end
 local count,maximum,regen=M.plan(rank,level,form)
 local result: {Clone}={}
 for _=1,count do
  state.serial+=1
  local clone: Clone={id=state.serial,owner=state.owner,round=state.round,life=state.life,mana=M.Policy.OrdinaryInitialMana,maximum=maximum,regen=regen,updatedAt=now,expiresAt=now+M.Policy.Lifetime,settled=false}
  state.clones[clone.id]=clone; table.insert(result,clone)
 end
 return result
end
function M.live(state: State, clone: Clone): boolean
 return state.clones[clone.id]==clone and not clone.settled and state.owner==clone.owner and state.round==clone.round and state.life==clone.life
end
function M.update(state: State, clone: Clone, now: number)
 if not M.live(state,clone) or not finite(now) then return end
 local at=math.max(clone.updatedAt,math.min(now,clone.expiresAt))
 clone.mana=math.min(clone.maximum,clone.mana+(at-clone.updatedAt)*clone.regen); clone.updatedAt=at
end
-- Claim before calling adapters: concurrent Died/expiration/recall can pay only once.
function M.restore(state: State, clone: Clone, now: number, amount: number): boolean
 if not M.live(state,clone) or not finite(now) or now<clone.updatedAt or now>=clone.expiresAt
  or not finite(amount) or amount<=0 then return false end
 M.update(state,clone,now)
 clone.mana=math.min(clone.maximum,clone.mana+amount)
 return true
end
function M.settle(state: State, clone: Clone, now: number, ownerValid: boolean): number
 if not M.live(state,clone) or not finite(now) then return 0 end
 M.update(state,clone,now); clone.settled=true; state.clones[clone.id]=nil
 return if ownerValid then clone.mana else 0
end
function M.invalidate(state: State, round: number, life: number)
 for _,clone in state.clones do clone.settled=true end
 state.clones={}; state.round=round; state.life=life
end
return M
