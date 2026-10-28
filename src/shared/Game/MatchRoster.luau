--!strict
-- Round-scoped roster aggregate. Roblox Players, attributes and phase timing
-- belong to adapters; this module owns membership, capacity and readiness.
export type Member = { teamId: string, connected: boolean }
export type State = {
	order: { string }, capacity: number, locked: boolean,
	members: { [number]: Member },
}
local Roster = {}

function Roster.new(ids: { string }, capacity: number?): State
	local limit = capacity or 5
	assert(limit >= 1 and limit < math.huge and limit % 1 == 0, "Capacity must be a positive integer")
	assert(#ids >= 2, "At least two teams required")
	local seen: { [string]: boolean } = {}
	for _, id in ids do
		assert(id ~= "" and not seen[id], "Team IDs must be nonempty and unique")
		seen[id] = true
	end
	return { order = table.clone(ids), capacity = limit, locked = false, members = {} }
end

function Roster.counts(state: State): { [string]: number }
	local result: { [string]: number } = {}
	for _, id in state.order do result[id] = 0 end
	for _, member in state.members do
		if member.connected then result[member.teamId] += 1 end
	end
	return result
end

function Roster.teamOf(state: State, userId: number): string?
	local member = state.members[userId]
	return if member and member.connected then member.teamId else nil
end

function Roster.join(state: State, userId: number): string?
	-- Studio uses negative synthetic IDs; require integers, not positivity.
	assert(userId > -math.huge and userId < math.huge and userId % 1 == 0, "User ID must be a finite integer")
	local member = state.members[userId]
	if member then
		member.connected = true
		return member.teamId
	end
	if state.locked then return nil end
	local counts = Roster.counts(state)
	local selected: string? = nil
	for _, id in state.order do
		if counts[id] < state.capacity and (not selected or counts[id] < counts[selected]) then selected = id end
	end
	if selected then state.members[userId] = { teamId = selected, connected = true } end
	return selected
end

function Roster.leave(state: State, userId: number)
	local member = state.members[userId]
	if not member then return end
	if state.locked then member.connected = false else state.members[userId] = nil end
end

function Roster.lock(state: State)
	-- A disconnected slot remains reserved to its owner until the next round.
	-- A fresh aggregate is created at reset; no in-match replacement or switching.
	state.locked = true
end

function Roster.connectedCount(state: State): number
	local total = 0
	for _, count in Roster.counts(state) do total += count end
	return total
end

function Roster.ready(state: State, minimumPerTeam: number): boolean
	assert(minimumPerTeam >= 1 and minimumPerTeam % 1 == 0, "Minimum must be a positive integer")
	if minimumPerTeam > state.capacity then return false end
	for _, count in Roster.counts(state) do
		if count < minimumPerTeam then return false end
	end
	return true
end

return Roster
