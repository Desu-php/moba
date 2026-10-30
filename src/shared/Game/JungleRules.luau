--!strict
-- Engine-independent camp lifecycle; all time and distances supplied by application.
export type Camp = { mode: string, respawnAt: number }
local Rules = {}
function Rules.new(): Camp return { mode = "Idle", respawnAt = 0 } end
function Rules.hostile(aNeutral: boolean, bNeutral: boolean, aActive: boolean, bActive: boolean): boolean
	return (aNeutral and not bNeutral and bActive) or (bNeutral and not aNeutral and aActive)
end
function Rules.die(camp: Camp, now: number, delay: number)
	if camp.mode == "Dead" then return end
	camp.mode = "Dead"; camp.respawnAt = now + delay
end
function Rules.step(camp: Camp, now: number, running: boolean, homeDistance: number, targetValid: boolean, targetHomeDistance: number, leash: number): string
	if not running then return "Stopped" end
	if camp.mode == "Dead" then return if now >= camp.respawnAt then "Spawn" else "Dead" end
	if camp.mode == "Returning" then
		if homeDistance <= 3 then camp.mode = "Idle" end
	elseif homeDistance > leash or (targetValid and targetHomeDistance > leash) then camp.mode = "Returning"
	elseif targetValid then camp.mode = "Chasing"
	elseif homeDistance > 3 then camp.mode = "Returning"
	else camp.mode = "Idle" end
	return camp.mode
end
return Rules
