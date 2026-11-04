--!strict
-- Engine-free policy; coordinates are horizontal studs. World queries stay server-side.
local Policy = {}
Policy.RepathInterval = 0.8
Policy.FailureDelay = 2
Policy.GoalDrift = 2
Policy.StuckTime = 1.2
Policy.RequestInterval = 0.25
Policy.MaxConcurrent = 2
Policy.SlotInterval = 0.5
Policy.SlotsPerRing = 10
-- Leave two angular gaps for incoming/outgoing fighters instead of sealing the ring.
Policy.FrontlineLimit = 8
Policy.RingSpacing = 5
export type Clock = { generation: number, key: string, nextPath: number, pending: boolean, alive: boolean }
function Policy.new(): Clock
	return { generation = 0, key = "", nextPath = 0, pending = false, alive = true }
end
function Policy.change(state: Clock, key: string): boolean
	if state.key == key then return false end
	state.key = key; state.generation += 1
	return true
end
function Policy.cancel(state: Clock)
	state.generation += 1; state.alive = false
end
function Policy.canRequest(state: Clock, now: number): boolean
	return state.alive and not state.pending and now >= state.nextPath
end
function Policy.begin(state: Clock, now: number): number
	state.pending = true; state.nextPath = now + Policy.RepathInterval
	return state.generation
end
function Policy.finish(state: Clock, generation: number, now: number, success: boolean): boolean
	state.pending = false
	if not state.alive or generation ~= state.generation then return false end
	if not success then state.nextPath = now + Policy.FailureDelay end
	return true
end
function Policy.slot(index: number, radius: number, spacing: number): (number, number)
	local ring = math.floor((index - 1) / Policy.SlotsPerRing)
	-- Stagger waiting rings so settled overflow does not seal the radial lanes.
	local angle = ((index - 1) % Policy.SlotsPerRing) * 2 * math.pi / Policy.SlotsPerRing + ring * math.pi / Policy.SlotsPerRing
	local distance = radius + ring * spacing
	return math.cos(angle) * distance, math.sin(angle) * distance
end
function Policy.segmentDistance(ax: number, az: number, bx: number, bz: number, px: number, pz: number): number
	local dx, dz = bx - ax, bz - az
	local length = dx * dx + dz * dz
	local t = if length > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / length, 0, 1) else 0
	return math.sqrt((ax + t * dx - px)^2 + (az + t * dz - pz)^2)
end
function Policy.clearPeer(ax: number, az: number, bx: number, bz: number, px: number, pz: number, spacing: number): boolean
	local before = math.sqrt((ax-px)^2 + (az-pz)^2)
	local after = math.sqrt((bx-px)^2 + (bz-pz)^2)
	-- Spawn overlap can escape, but cannot deepen or pass through another unit.
	if before < spacing then return after > before + 0.001 end
	return Policy.segmentDistance(ax, az, bx, bz, px, pz) >= spacing
end
return table.freeze(Policy)
