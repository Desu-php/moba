--!strict
-- Ordinary A014 only. No shared JASS-style caster/target state and no Roblox instances.
-- request returns a debit command exactly once; the application must commit it atomically.
export type Configuration = {
	read ManaCost: number, read Cooldown: number, read Preparation: number,
	read HoldDuration: number, read AttackControlDelay: number, read ImpactDelay: number, read Stun: number,
}
export type Cast = {
	id: number, ownerId: string, round: number, life: number, requestId: number,
	startedAt: number, readyAt: number, expiresAt: number, phase: string,
	targetId: string?, controlAt: number?, controlled: boolean, impactAt: number?, impacted: boolean,
}
export type State = { ownerId: string, round: number, life: number, serial: number, lastRequest: number, cooldownAt: number, active: Cast? }
local Module = {}
local function finite(value: number): boolean return value == value and math.abs(value) < math.huge end
function Module.new(ownerId: string, round: number, life: number): State
	return { ownerId = ownerId, round = round, life = life, serial = 0, lastRequest = 0, cooldownAt = 0, active = nil }
end
function Module.current(state: State, cast: Cast): boolean
	return state.active == cast and state.ownerId == cast.ownerId and state.round == cast.round
		and state.life == cast.life and state.serial == cast.id
end
function Module.cancel(state: State) state.active = nil end
function Module.newLife(state: State, life: number)
	state.life = life; Module.cancel(state) -- Cooldowns persist across respawn as an explicit Roblox lifecycle policy.
end
function Module.reset(state: State, round: number, life: number)
	state.round = round; state.life = life; state.cooldownAt = 0; Module.cancel(state)
	-- Keep serial/request high-water marks so an old packet cannot impersonate a new cast.
end
function Module.configure(config: Configuration)
	local Rules = {}
	function Rules.request(state: State, now: number, requestId: number, mana: number, allowed: boolean): (Cast?, string, number)
		if not finite(now) or not finite(requestId) or requestId < 1 or requestId % 1 ~= 0
			or not finite(mana) or mana < 0 then return nil, "Malformed", 0 end
		if requestId <= state.lastRequest then return nil, "Replay", 0 end
		state.lastRequest = requestId
		if not allowed then return nil, "Unavailable", 0 end
		if state.active and (state.active.phase == "Consumed" or now < state.active.expiresAt) then return nil, "Busy", 0 end
		if now < state.cooldownAt then return nil, "Cooldown", 0 end
		if mana < config.ManaCost then return nil, "Mana", 0 end
		state.serial += 1
		local cast: Cast = { id = state.serial, ownerId = state.ownerId, round = state.round, life = state.life,
			requestId = requestId, startedAt = now, readyAt = now + config.Preparation,
			expiresAt = now + config.HoldDuration, phase = "Preparing", targetId = nil,
			controlAt = nil, controlled = false, impactAt = nil, impacted = false }
		state.active = cast; state.cooldownAt = now + config.Cooldown
		return cast, "Accepted", config.ManaCost
	end
	function Rules.update(state: State, now: number)
		local cast = state.active; if not cast or not finite(now) then return end
		if cast.phase ~= "Consumed" and now >= cast.expiresAt then Module.cancel(state)
		elseif cast.phase == "Preparing" and now >= cast.readyAt then cast.phase = "Holding" end
	end
	function Rules.hasMarker(state: State, now: number): boolean
		local cast = state.active
		-- Consuming the attack handler does not remove B00T: held buff cleanup follows impact.
		return finite(now) and cast ~= nil and Module.current(state, cast)
			and now >= cast.startedAt and now < cast.expiresAt
	end
	-- Caller supplies a server-admitted hostile nonstructure attack-start event.
	-- Using confirmed contact instead requires an explicitly documented adapter policy.
	function Rules.attack(state: State, cast: Cast, now: number, targetId: string, hostile: boolean, structure: boolean): boolean
		if not finite(now) or not Module.current(state, cast) or cast.phase == "Consumed" or now < cast.readyAt
			or now >= cast.expiresAt or targetId == "" or not hostile or structure then return false end
		cast.phase = "Consumed"; cast.targetId = targetId; cast.controlAt = now + config.AttackControlDelay
		return true
	end
	function Rules.claimControl(state: State, cast: Cast, now: number): (string?, number)
		local at = cast.controlAt
		if not finite(now) or not Module.current(state, cast) or cast.phase ~= "Consumed" or cast.controlled
			or not at or now < at then return nil, 0 end
		cast.controlled = true; cast.impactAt = now + config.ImpactDelay
		-- A0JT is applied before the one-second damage wait (JASS 48693-48789).
		return cast.targetId, config.Stun
	end
	function Rules.claimImpact(state: State, cast: Cast, now: number): string?
		local at = cast.impactAt
		if not finite(now) or not Module.current(state, cast) or cast.phase ~= "Consumed" or cast.impacted
			or not cast.controlled or not at or now < at then return nil end
		cast.impacted = true
		local targetId = cast.targetId
		Module.cancel(state)
		-- Formula is deliberately resolved from CURRENT level/STR by the application at this event.
		return targetId
	end
	return Rules
end
return Module
