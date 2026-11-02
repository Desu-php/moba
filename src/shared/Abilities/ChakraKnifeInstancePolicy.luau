--!strict
-- Roblox adaptation of the paired-region predicate. No WC3 coordinates or teleport.
export type Identity={id: string,eligible: boolean}
export type Attempt={caster: Identity?,readyAt: number,resolved: boolean}
local P={}
local function finite(n: number): boolean return n==n and math.abs(n)<math.huge end
local function snapshot(value: Identity?): Identity?
 if not value or value.id=="" or not value.eligible then return nil end
 return {id=value.id,eligible=true}
end
function P.begin(now: number,caster: Identity?): Attempt?
 if not finite(now) then return nil end
 return {caster=snapshot(caster),readyAt=now+.01,resolved=false}
end
function P.resolve(attempt: Attempt,now: number,targetAfterDelay: Identity?): (boolean,string)
 if not finite(now) then return false,"Clock" end
 if attempt.resolved then return false,"Replay" end
 if now<attempt.readyAt then return false,"Early" end
 attempt.resolved=true
 local caster=attempt.caster;local target=snapshot(targetAfterDelay)
 if not caster or not target then return false,"OutsideInstance" end
 return caster.id==target.id,if caster.id==target.id then "Accepted" else "CrossInstance"
end
return table.freeze(P)
