--!strict

-- Pure state machine. No timers, Instances, network calls or client authority.
export type Mode = "Idle" | "Attacking" | "Stunned" | "Dead"
export type Profile = {
	read AttackCooldown: number, read InputBufferWindow: number, read HitDelay: number, read AttackDuration: number,
}
export type Attack = {
	id: number, requestId: number, step: number, startedAt: number,
	hitAt: number, endsAt: number, hitClaimed: boolean,
}
export type Buffer = { requestId: number, dueAt: number, expiresAt: number }
export type Fighter = {
	mode: Mode, lastAttackAt: number, nextAttackAt: number,
	stunUntil: number, attackSerial: number, active: Attack?, buffered: Buffer?,
}

local CombatState = {}

function CombatState.new(): Fighter
	return {
		mode = "Idle", lastAttackAt = 0, nextAttackAt = 0,
		stunUntil = 0, attackSerial = 0, active = nil, buffered = nil,
	}
end

function CombatState.Update(state: Fighter, now: number): boolean
	if state.mode == "Stunned" and now >= state.stunUntil then
		state.mode = "Idle"
		state.stunUntil = 0
		return true
	end
	local attack = state.active
	if state.mode == "Attacking" and attack and now >= attack.endsAt then
		state.mode = "Idle"
		state.active = nil
		return true
	end
	return false
end

function CombatState.Request(state: Fighter, profile: Profile, now: number, requestId: number, speedMultiplier: number?): (string, string?)
	CombatState.Update(state, now)
	if state.mode == "Dead" or state.mode == "Stunned" then
		return "Rejected", state.mode
	end
	if state.buffered then
		return "Rejected", "BufferFull"
	end
	if now < state.nextAttackAt or state.mode == "Attacking" then
		local remaining = state.nextAttackAt - now
		if remaining > 0 and remaining <= profile.InputBufferWindow then
			state.buffered = { requestId = requestId, dueAt = state.nextAttackAt, expiresAt = state.nextAttackAt + profile.InputBufferWindow }
			return "Buffered", nil
		end
		return "Rejected", "Cooldown"
	end
	local speed = speedMultiplier or 1
	if speed ~= speed or speed <= 0 or speed == math.huge then return "Rejected", "InvalidSpeed" end
	state.attackSerial += 1
	state.lastAttackAt = now
	state.nextAttackAt = now + math.max(profile.AttackCooldown, profile.AttackDuration) / speed
	state.mode = "Attacking"
	state.active = {
		id = state.attackSerial, requestId = requestId, step = 1, startedAt = now,
		hitAt = now + profile.HitDelay / speed,
		endsAt = now + profile.AttackDuration / speed, hitClaimed = false,
	}
	return "Started", nil
end

function CombatState.ClaimHit(state: Fighter, now: number): Attack?
	local attack = state.active
	if state.mode ~= "Attacking" or not attack or attack.hitClaimed or now < attack.hitAt or now >= attack.endsAt then
		return nil
	end
	attack.hitClaimed = true
	return attack
end

function CombatState.TakeBuffer(state: Fighter, now: number): (number?, boolean)
	local buffer = state.buffered
	if not buffer or now < buffer.dueAt then
		return nil, false
	end
	state.buffered = nil
	return buffer.requestId, now <= buffer.expiresAt and state.mode == "Idle"
end

function CombatState.Stun(state: Fighter, now: number, duration: number, _interrupt: boolean)
	if state.mode == "Dead" then
		return
	end
	state.mode = "Stunned"
	state.active = nil
	state.buffered = nil
	-- Overlap replaces the deadline, rather than stacking durations or old timers.
	state.stunUntil = math.max(state.stunUntil, now + duration)
	state.nextAttackAt = math.max(state.nextAttackAt, state.stunUntil)
end

function CombatState.Kill(state: Fighter)
	state.mode = "Dead"
	state.lastAttackAt = 0
	state.nextAttackAt = 0
	state.stunUntil = 0
	state.active = nil
	state.buffered = nil
end

return CombatState
