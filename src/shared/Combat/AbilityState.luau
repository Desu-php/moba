--!strict
-- A life owns its casts. No delayed callback can claim an old or cancelled cast.
export type Definition = { read Cooldown: number, read Windup: number, read Duration: number }
export type Cast = { id: number, life: number, abilityId: string, requestId: number,
	startedAt: number, impactAt: number, endsAt: number, impacted: boolean }
export type State = { life: number, serial: number, active: Cast?, ready: { [string]: number } }
local Rules = {}
function Rules.new(life: number): State return { life = life, serial = 0, active = nil, ready = {} } end
function Rules.remaining(state: State, id: string, now: number): number return math.max(0, (state.ready[id] or 0) - now) end
function Rules.request(state: State, id: string, definition: Definition, now: number, requestId: number,
	mode: string, nextM1: number, allowed: boolean): (Cast?, string)
	if not allowed or mode == "Dead" or mode == "Stunned" then return nil, "Unavailable" end
	if state.active or mode ~= "Idle" or now < nextM1 then return nil, "Busy" end
	if Rules.remaining(state, id, now) > 0 then return nil, "Cooldown" end
	state.serial += 1
	local cast: Cast = { id = state.serial, life = state.life, abilityId = id, requestId = requestId,
		startedAt = now, impactAt = now + definition.Windup, endsAt = now + definition.Duration, impacted = false }
	state.active = cast; state.ready[id] = now + definition.Cooldown
	return cast, "Accepted"
end
function Rules.current(state: State, cast: Cast): boolean
	return state.life == cast.life and state.active == cast and state.serial == cast.id
end
function Rules.claim(state: State, cast: Cast, now: number): boolean
	if not Rules.current(state, cast) or cast.impacted or now < cast.impactAt or now >= cast.endsAt then return false end
	cast.impacted = true; return true
end
function Rules.contactOpen(state: State, cast: Cast, now: number, window: number): boolean
	return Rules.current(state, cast) and not cast.impacted and now >= cast.impactAt
		and now <= cast.impactAt + window and now < cast.endsAt
end
function Rules.cancel(state: State) state.active = nil end
function Rules.finish(state: State, cast: Cast, now: number): boolean
	if not Rules.current(state, cast) or now < cast.endsAt then return false end
	state.active = nil; return true
end
function Rules.newLife(state: State, life: number)
	state.life = life; state.active = nil -- Cooldowns persist across respawn; a new match creates a new state.
end
return Rules
