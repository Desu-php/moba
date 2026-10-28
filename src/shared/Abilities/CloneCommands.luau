--!strict
-- Agreed third-person control adaptation: owner follow/assist and explicit group target.
-- Target validity is supplied by the authoritative world adapter; no distances/AI invented.
export type State = {
	ownerId: string, round: number, life: number, active: boolean,
	lastRequest: number, assistTarget: string?, commandedTarget: string?,
}
export type Intent = { mode: string, ownerId: string, targetId: string? }
local Commands = {}
function Commands.new(ownerId: string, round: number, life: number): State
	return { ownerId = ownerId, round = round, life = life, active = true, lastRequest = 0,
		assistTarget = nil, commandedTarget = nil }
end
function Commands.suspend(state: State)
	state.active = false; state.assistTarget = nil; state.commandedTarget = nil
end
function Commands.newLife(state: State, round: number, life: number)
	Commands.suspend(state); state.round = round; state.life = life; state.active = true
end
function Commands.assist(state: State, targetId: string?, validEnemy: boolean)
	state.assistTarget = if state.active and validEnemy and targetId ~= "" then targetId else nil
end
function Commands.invalidateTarget(state: State, targetId: string)
	if state.assistTarget == targetId then state.assistTarget = nil end
	if state.commandedTarget == targetId then state.commandedTarget = nil end
end
function Commands.command(state: State, actorId: string, round: number, life: number,
	requestId: number, targetId: string, validEnemy: boolean): (boolean, string)
	if actorId ~= state.ownerId then return false, "Owner" end
	if round ~= state.round or life ~= state.life then return false, "StaleLife" end
	if requestId ~= requestId or requestId == math.huge or requestId < 1 or requestId % 1 ~= 0 then return false, "Malformed" end
	if requestId <= state.lastRequest then return false, "Replay" end
	state.lastRequest = requestId
	if not state.active then return false, "Unavailable" end
	if targetId == "" or not validEnemy then return false, "Target" end
	state.commandedTarget = targetId; return true, "Accepted"
end
function Commands.resolve(state: State): Intent
	if not state.active then return { mode = "Idle", ownerId = state.ownerId, targetId = nil } end
	if state.commandedTarget then return { mode = "Command", ownerId = state.ownerId, targetId = state.commandedTarget } end
	if state.assistTarget then return { mode = "Assist", ownerId = state.ownerId, targetId = state.assistTarget } end
	return { mode = "Follow", ownerId = state.ownerId, targetId = nil }
end
return Commands
