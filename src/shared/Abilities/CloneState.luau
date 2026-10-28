--!strict
-- Ordinary A04N burst/illusion lifetime. Roblox units, orders and Sleep are adapters.
export type Configuration = {
	read Lifetime: number, read SpawnInterval: number, read OutgoingMultiplier: number,
	read IncomingMultiplier: number, read MassCount: number,
}
export type Burst = { id: number, round: number, life: number, remaining: number, nextAt: number }
export type Clone = {
	id: number, ownerId: string, round: number, life: number, expiresAt: number,
	outgoingMultiplier: number, incomingMultiplier: number, hasPayload: boolean,
}
export type Payload = { cloneId: number, ownerId: string, round: number, life: number, targetId: string, claimed: boolean }
export type State = {
	ownerId: string, round: number, life: number, serial: number, burstSerial: number,
	lastRequest: number, cooldownAt: number, burst: Burst?, clones: { [number]: Clone }, pending: { [Payload]: boolean },
}
local Module = {}
local function finite(value: number): boolean return value == value and math.abs(value) < math.huge end
function Module.new(ownerId: string, round: number, life: number): State
	return { ownerId = ownerId, round = round, life = life, serial = 0, burstSerial = 0,
		lastRequest = 0, cooldownAt = 0, burst = nil, clones = {}, pending = {} }
end
function Module.newLife(state: State, life: number)
	state.life = life; state.burst = nil; table.clear(state.pending)
	-- Source does not prove a death purge of completed illusions. Invalidate empowered payloads
	-- as an intentional safety fix, but keep already-created clones until expiry/removal.
	for _, clone in state.clones do clone.hasPayload = false end
end
function Module.reset(state: State, round: number, life: number)
	Module.newLife(state, life); state.round = round; state.cooldownAt = 0; table.clear(state.clones)
end
function Module.remove(state: State, clone: Clone): boolean
	if state.clones[clone.id] ~= clone then return false end
	state.clones[clone.id] = nil; return true
end
function Module.expire(state: State, now: number): { Clone }
	local removed: { Clone } = {}
	if not finite(now) then return removed end
	for _, clone in state.clones do
		if now >= clone.expiresAt then Module.remove(state, clone); table.insert(removed, clone) end
	end
	return removed
end
function Module.takePayload(state: State, clone: Clone, now: number, targetId: string, hostile: boolean, structure: boolean): Payload?
	if not finite(now) or state.clones[clone.id] ~= clone or clone.ownerId ~= state.ownerId
		or clone.round ~= state.round or clone.life ~= state.life or now >= clone.expiresAt
		or not clone.hasPayload or not hostile or structure or targetId == "" then return nil end
	clone.hasPayload = false -- Atomic admission closes the same-frame double-attack race.
	local payload: Payload = { cloneId = clone.id, ownerId = state.ownerId, round = state.round, life = state.life,
		targetId = targetId, claimed = false }
	state.pending[payload] = true
	return payload
end
function Module.claimPayload(state: State, payload: Payload): string?
	if not state.pending[payload] or payload.claimed or payload.ownerId ~= state.ownerId or payload.round ~= state.round
		or payload.life ~= state.life then return nil end
	state.pending[payload] = nil; payload.claimed = true; return payload.targetId
end
function Module.configure(config: Configuration)
	local Rules = {}
	-- Count/cooldown come from the server's validated clone plan, never a client packet.
	function Rules.begin(state: State, now: number, requestId: number, count: number, cooldown: number): (Burst?, string)
		if not finite(now) or not finite(requestId) or requestId < 1 or requestId % 1 ~= 0
			or not finite(count) or count < 1 or count > config.MassCount or count % 1 ~= 0
			or not finite(cooldown) or cooldown < 0 then return nil, "Malformed" end
		if requestId <= state.lastRequest then return nil, "Replay" end
		state.lastRequest = requestId
		if state.burst then return nil, "Busy" end
		if now < state.cooldownAt then return nil, "Cooldown" end
		state.burstSerial += 1
		local burst: Burst = { id = state.burstSerial, round = state.round, life = state.life,
			remaining = count, nextAt = now + config.SpawnInterval }
		state.burst = burst; state.cooldownAt = now + cooldown
		return burst, "Accepted"
	end
	function Rules.spawnOne(state: State, burst: Burst, now: number, alive: boolean, heldRasengan: boolean): Clone?
		if not finite(now) or state.burst ~= burst or burst.round ~= state.round or burst.life ~= state.life then return nil end
		if not alive then state.burst = nil; return nil end
		if now < burst.nextAt then return nil end
		state.serial += 1
		local clone: Clone = { id = state.serial, ownerId = state.ownerId, round = state.round, life = state.life,
			expiresAt = now + config.Lifetime, outgoingMultiplier = config.OutgoingMultiplier,
			incomingMultiplier = config.IncomingMultiplier, hasPayload = heldRasengan }
		state.clones[clone.id] = clone
		burst.remaining -= 1; burst.nextAt = now + config.SpawnInterval
		if burst.remaining == 0 then state.burst = nil end
		return clone
	end
	return Rules
end
return Module
