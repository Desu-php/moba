--!strict
-- Wakeable status, independent from rigid stun. No guessed native invulnerability.
export type Status = { untilAt: number, active: boolean }
local Sleep = {}
function Sleep.new(now: number): Status return {untilAt=now+3,active=true} end
function Sleep.wake(s: Status, attack: boolean, dealt: number): boolean
 if not s.active or (not attack and (dealt~=dealt or dealt<=0)) then return false end
 s.active=false; return true
end
function Sleep.update(s: Status, now: number): boolean
 if s.active and now==now and now>=s.untilAt then s.active=false; return true end
 return false
end
return table.freeze(Sleep)
