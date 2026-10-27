--!strict
export type Phase = "WaitingForPlayers" | "Preparing" | "InProgress" | "Finished"
export type TeamState = { active: boolean, count: number }
export type State = {
	phase: Phase, teams: { [string]: TeamState }, order: { string },
	preparationEnds: number, startedAt: number, finishedAt: number,
	nextWaveAt: number, wave: number, winner: string?,
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
		preparationEnds = 0, startedAt = 0, finishedAt = 0, nextWaveAt = 0, wave = 0, winner = nil }
end
function Rules.active(state: State): { string }
	local result = {}
	for _, id in state.order do if state.teams[id].active then table.insert(result, id) end end
	return result
end
function Rules.assign(state: State, preferred: string?): string?
	if state.phase == "Finished" then return nil end
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
return Rules
