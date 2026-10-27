--!strict
export type Candidate = { id: number, kind: string, distance: number, valid: boolean }
export type State = { target: number?, aggro: number?, aggroUntil: number, readyAt: number,
	shot: number?, contactAt: number, destroyed: boolean, rewarded: boolean }
local Rules = {}
function Rules.new(): State
	return { target = nil, aggro = nil, aggroUntil = 0, readyAt = 0, shot = nil, contactAt = 0, destroyed = false, rewarded = false }
end
function Rules.cancel(state: State)
	state.target = nil; state.shot = nil; state.aggro = nil; state.aggroUntil = 0
end
function Rules.aggress(state: State, attacker: number, now: number, duration: number, confirmedEnemyHero: boolean)
	if state.destroyed or not confirmedEnemyHero then return end
	state.aggro = attacker; state.aggroUntil = now + duration
	if state.shot and state.shot ~= attacker then state.shot = nil; state.readyAt = math.min(state.readyAt, now) end
end
function Rules.choose(state: State, candidates: { Candidate }, now: number, priority: { [string]: number }, allowSummons: boolean): number?
	if state.destroyed then return nil end
	local best: Candidate? = nil
	for _, candidate in candidates do
		local rank = priority[candidate.kind]
		if not candidate.valid or not rank or (candidate.kind == "Summon" and not allowSummons) then continue end
		if candidate.id == state.aggro and now < state.aggroUntil and candidate.kind == "Hero" then return candidate.id end
		local previous = best
		if not previous or rank < priority[previous.kind]
			or (rank == priority[previous.kind] and (candidate.distance < previous.distance - 0.001
				or (math.abs(candidate.distance - previous.distance) <= 0.001 and
					(candidate.id == state.target or (previous.id ~= state.target and candidate.id < previous.id))))) then best = candidate end
	end
	state.aggro = nil; state.aggroUntil = 0
	return if best then best.id else nil
end
function Rules.begin(state: State, target: number, now: number, windup: number, interval: number): boolean
	if state.destroyed or state.shot or now < state.readyAt then return false end
	state.target = target; state.shot = target; state.contactAt = now + windup; state.readyAt = now + interval; return true
end
function Rules.contact(state: State, now: number, targetValid: boolean, inProgress: boolean): number?
	if state.destroyed or not inProgress or not targetValid then state.shot = nil; return nil end
	if not state.shot or now < state.contactAt then return nil end
	local target = state.shot; state.shot = nil; return target
end
function Rules.destroy(state: State): boolean
	if state.destroyed then return false end
	state.destroyed = true; Rules.cancel(state); return true
end
function Rules.claimReward(state: State, enemyTeam: boolean): boolean
	if not state.destroyed or state.rewarded or not enemyTeam then return false end
	state.rewarded = true; return true
end
function Rules.recipient(attackingTeam: string, team: string, connected: boolean, active: boolean, eliminated: boolean): boolean
	return attackingTeam == team and connected and active and not eliminated
end
return Rules
