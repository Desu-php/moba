--!strict
export type Phase = "WaitingForPlayers" | "Preparing" | "InProgress" | "Finished" | "Intermission"
export type TeamState = { active: boolean, count: number }
export type State = {
	phase: Phase, teams: { [string]: TeamState }, order: { string },
	preparationEnds: number, startedAt: number, finishedAt: number,
	nextWaveAt: number, wave: number, winner: string?, roundId: number, intermissionEnds: number,
}
local Rules = {}
function Rules.new(ids: { string }): State
	assert(#ids >= 2, "At least two teams required")
	local teams = {}
	for _, id in ids do
		assert(not teams[id], "Duplicate team")
		teams[id] = { active = true, count = 0 }
	end
	return { phase = "WaitingForPlayers", teams = teams, order = table.clone(ids),
		preparationEnds = 0, startedAt = 0, finishedAt = 0, nextWaveAt = 0, wave = 0, winner = nil,
		roundId = 1, intermissionEnds = 0 }
end
function Rules.active(state: State): { string }
	local result = {}
	for _, id in state.order do if state.teams[id].active then table.insert(result, id) end end
	return result
end
function Rules.assign(state: State, preferred: string?): string?
	if state.phase == "Finished" or state.phase == "Intermission" then return nil end
	if preferred and state.teams[preferred] then
		-- Rejoining an eliminated team cannot escape elimination.
		if state.teams[preferred].active then return preferred end
		return nil
	end
	local selected: string? = nil
	for _, id in state.order do
		local team = state.teams[id]
		if team.active and (not selected or team.count < state.teams[selected].count) then selected = id end
	end
	return selected
end
function Rules.enemy(state: State, first: string?, second: string?): boolean
	return first ~= nil and second ~= nil and first ~= second
		and state.teams[first] ~= nil and state.teams[second] ~= nil
		and state.teams[first].active and state.teams[second].active
end
function Rules.advance(state: State, now: number, players: number, minimum: number, preparation: number, firstWave: number): boolean
	if state.phase == "WaitingForPlayers" and players >= minimum then
		state.phase = "Preparing"
		state.preparationEnds = now + preparation
		return true
	elseif state.phase == "Preparing" then
		if players < minimum then state.phase = "WaitingForPlayers"; return true end
		if now >= state.preparationEnds then
			state.phase = "InProgress"; state.startedAt = now; state.nextWaveAt = now + firstWave
			return true
		end
	end
	return false
end
function Rules.waveDue(state: State, now: number, interval: number): boolean
	if state.phase ~= "InProgress" or now < state.nextWaveAt then return false end
	state.wave += 1
	-- No catch-up storm after a long frame.
	state.nextWaveAt = now + interval
	return true
end
function Rules.eliminate(state: State, id: string, now: number): boolean
	local team = state.teams[id]
	if state.phase ~= "InProgress" or not team or not team.active then return false end
	team.active = false
	local survivors = Rules.active(state)
	if #survivors <= 1 then
		state.phase = "Finished"; state.winner = survivors[1]; state.finishedAt = now
	end
	return true
end
-- Scheduling is separate from phase assignment: test fixtures and admin inspection
-- cannot accidentally start a new round by temporarily setting phase = Finished.
function Rules.schedule(state: State, now: number, duration: number): boolean
	if state.phase ~= "Finished" or state.intermissionEnds > 0 then return false end
	state.intermissionEnds = now + math.max(0, duration)
	return true
end
function Rules.intermission(state: State, now: number, resultDuration: number): boolean
	if state.phase ~= "Finished" or state.intermissionEnds <= 0 then return false end
	if now < math.min(state.finishedAt + resultDuration, state.intermissionEnds) then return false end
	state.phase = "Intermission"
	return true
end
function Rules.restart(state: State, now: number, expectedRound: number): boolean
	if state.roundId ~= expectedRound or state.phase ~= "Intermission" or now < state.intermissionEnds then return false end
	state.roundId += 1
	state.phase = "WaitingForPlayers"
	state.preparationEnds = 0; state.startedAt = 0; state.finishedAt = 0; state.intermissionEnds = 0
	state.nextWaveAt = 0; state.wave = 0; state.winner = nil
	for _, team in state.teams do team.active = true; team.count = 0 end
	return true
end
return Rules
