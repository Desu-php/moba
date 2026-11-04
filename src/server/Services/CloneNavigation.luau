--!strict
local Pathfinding = game:GetService("PathfindingService")
local Policy = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Abilities.CloneNavigationPolicy)
export type Agent = {
	model: Model, root: BasePart, clock: Policy.Clock, target: Model?, slot: number?, goal: Vector3?,
	waypoints: { Vector3 }, waypoint: number, pathGoal: Vector3?, nextSlot: number,
	formationTarget: Model?, frontline: boolean?,
	progressAt: number, progressPosition: Vector3, failures: number, serial: number, groundOffset: number, queued: boolean, fallSpeed: number,
}
local Navigation = {}
local agents: { [Model]: Agent } = {}
local waiting: { { agent: Agent, generation: number } } = {}
local serial, active, nextRequest = 0, 0, 0
local function flat(v: Vector3): Vector3 return v * Vector3.new(1, 0, 1) end
local function unqueue(agent: Agent)
	agent.queued = false
	for index = #waiting, 1, -1 do if waiting[index].agent == agent then table.remove(waiting, index) end end
end
function Navigation.Register(model: Model, root: BasePart, humanoid: Humanoid)
	serial += 1
	agents[model] = { model = model, root = root, clock = Policy.new(), target = nil, slot = nil, goal = nil,
		formationTarget = nil, frontline = nil,
		waypoints = {}, waypoint = 1, pathGoal = nil, nextSlot = 0, progressAt = 0,
		progressPosition = root.Position, failures = 0, serial = serial, fallSpeed = 0,
		groundOffset = math.max(humanoid.HipHeight + root.Size.Y / 2, math.max(4, root.Size.Y) / 2 + 0.05), queued = false }
end
function Navigation.Remove(model: Model)
	local agent = agents[model]; if not agent then return end
	Policy.cancel(agent.clock); unqueue(agent); agents[model] = nil
end
function Navigation.Stop(model: Model)
	local agent = agents[model]; if not agent then return end
	if Policy.change(agent.clock, "idle") then
		agent.target = nil; agent.slot = nil; agent.goal = nil; table.clear(agent.waypoints); agent.pathGoal = nil; unqueue(agent)
	end
	model:SetAttribute("SummonMoving", false)
end
function Navigation.SetFrontline(model: Model, target: Model, frontline: boolean)
	local agent = agents[model]; if not agent then return end
	if agent.formationTarget == target and agent.frontline == frontline then return end
	agent.formationTarget = target; agent.frontline = frontline
	agent.slot = nil; agent.goal = nil; agent.nextSlot = 0; agent.pathGoal = nil
	table.clear(agent.waypoints); unqueue(agent)
	Policy.change(agent.clock, tostring(agent.clock.generation + 1))
	model:SetAttribute("SummonFrontline", frontline)
end
function Navigation.CanStrike(model: Model, target: Model): boolean
	local agent = agents[model]
	return agent ~= nil and agent.formationTarget == target and agent.frontline == true
		and agent.target == target
end
local function parameters(agent: Agent, owner: Model, target: Model): RaycastParams
	local excluded: { Instance } = { agent.model, owner, target }
	-- Registered clones and Gamakichi use explicit body clearance/peer avoidance.
	-- World geometry remains collidable, while summon bodies never block players.
	for model in agents do table.insert(excluded, model) end
	local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = excluded; ray.RespectCanCollide = true
	ray.CollisionGroup = "SurvivalSummons"
	return ray
end
-- Wide summons meet a raised lane with their toes before their center ray does.
-- Sweep a shallow foot plate; do not use the visual mesh or ignore world collision.
local stepHeight = .65
local function support(agent: Agent, point: Vector3, lift: number, drop: number, ray: RaycastParams): Vector3?
	local feet = Vector3.new(math.max(2.2,agent.root.Size.X)-.04,.04,math.max(2.2,agent.root.Size.Z)-.04)
	local from = point + Vector3.new(0,-agent.groundOffset+lift+.04,0)
	local hit = workspace:Blockcast(CFrame.new(from),feet,Vector3.new(0,-(lift+drop+.04),0),ray)
	if not hit or hit.Normal.Y < .7 then return nil end
	return Vector3.new(point.X,hit.Position.Y+agent.groundOffset,point.Z)
end
-- Anchored navigation rigs need explicit gravity, including while holding/stunned.
-- Sweep the feet to the floor; never teleport an airborne spawn to its destination.
function Navigation.Settle(model: Model, owner: Model, delta: number): boolean
	local agent = agents[model]; if not agent then return false end
	local dt = math.clamp(delta, 0, .1)
	local fall = agent.fallSpeed * dt + workspace.Gravity * dt * dt / 2
	local ray = parameters(agent, owner, owner)
	local position = agent.root.Position
	local floor = support(agent,position,.08,fall+.15,ray)
	if floor then
		local y = floor.Y
		if math.abs(y - position.Y) > .001 then model:PivotTo(model:GetPivot() + Vector3.new(0, y - position.Y, 0)) end
		agent.fallSpeed = 0; model:SetAttribute("SummonGrounded", true)
		return true
	end
	agent.fallSpeed += workspace.Gravity * dt
	model:PivotTo(model:GetPivot() - Vector3.new(0, fall, 0))
	model:SetAttribute("SummonGrounded", false)
	return false
end
local function ground(agent: Agent, point: Vector3, ray: RaycastParams): Vector3?
	return support(agent,point,stepHeight,8,ray)
end
local function bodySize(agent: Agent): Vector3
	return Vector3.new(math.max(2.2, agent.root.Size.X), math.max(4, agent.root.Size.Y), math.max(2.2, agent.root.Size.Z))
end
local function bodyClear(agent: Agent, point: Vector3, ray: RaycastParams): boolean
	local overlap = OverlapParams.new(); overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ray.FilterDescendantsInstances; overlap.RespectCanCollide = true
	overlap.CollisionGroup = ray.CollisionGroup
	return #workspace:GetPartBoundsInBox(CFrame.new(point), bodySize(agent), overlap) == 0
end
-- Spawn searches nearby clear ground instead of clamping into a wall/floor overlap.
-- RespectCanCollide ignores visual grass and foliage, while retaining actual terrain.
function Navigation.Place(model:Model,owner:Model,origin:CFrame,distance:number):boolean
 local agent=agents[model];if not agent then return false end
 local ray=parameters(agent,owner,owner)
 for _,radius in {distance,distance+4,math.max(2,distance-3),distance+8} do
  for index=0,11 do
   local angle=index*math.pi/6
   local raw=(origin*CFrame.new(math.cos(angle)*radius,0,math.sin(angle)*radius)).Position
   local hit=workspace:Raycast(raw+Vector3.new(0,6,0),Vector3.new(0,-18,0),ray)
   local point=if hit and hit.Normal.Y>=.7 then Vector3.new(raw.X,hit.Position.Y+agent.groundOffset,raw.Z) else nil
   if point and bodyClear(agent,point,ray) and not workspace:Raycast(origin.Position,point-origin.Position,ray) then
    model:PivotTo(CFrame.new(point)*origin.Rotation);return true
   end
  end
 end
 -- Airborne/fully enclosed spawn: gravity settles it as soon as clear ground exists.
 model:PivotTo(origin+CFrame.new(0,agent.groundOffset,0).Position);return false
end
local function clear(agent: Agent, origin: Vector3, goal: Vector3, ray: RaycastParams): boolean
	local delta = goal - origin
	if delta.Magnitude < 0.001 then return true end
	return workspace:Blockcast(CFrame.new(origin), bodySize(agent), delta, ray) == nil
end
local function stepClear(agent: Agent, origin: Vector3, goal: Vector3, ray: RaycastParams): boolean
	if clear(agent,origin,goal,ray) then return true end
	-- Raise / move / lower is a swept route over a small curb, never through a wall.
	if math.abs(goal.Y-origin.Y)>stepHeight then return false end
	local y=math.max(origin.Y,goal.Y)+stepHeight
	local up=Vector3.new(origin.X,y,origin.Z);local across=Vector3.new(goal.X,y,goal.Z)
	return clear(agent,origin,up,ray) and bodyClear(agent,up,ray)
		and clear(agent,up,across,ray) and bodyClear(agent,across,ray) and clear(agent,across,goal,ray)
end
local function available(agent: Agent, target: Model, index: number): boolean
	for _, other in agents do
		if other ~= agent and other.target == target and other.slot == index then return false end
	end
	return true
end
local function chooseGoal(agent: Agent, target: Model, destination: BasePart, radius: number, ray: RaycastParams, now: number): Vector3?
	local center = destination.Position
	local function candidate(index: number): Vector3?
		if agent.formationTarget == target and agent.frontline ~= nil
			and (index <= Policy.SlotsPerRing) ~= agent.frontline then return nil end
		if not available(agent, target, index) then return nil end
		local x, z = Policy.slot(index, radius, Policy.RingSpacing)
		local point = ground(agent, center + Vector3.new(x, 0, z), ray)
		if not point then return nil end
		-- Blockcast omits initial overlap, so also validate destination body bounds.
		if not bodyClear(agent, point, ray) then return nil end
		if workspace:Raycast(point, center - point, ray) then return nil end
		return point
	end
	if now < agent.nextSlot and agent.goal then
		-- Translate the existing slot with a moving target between selection ticks.
		if agent.slot then
			local x, z = Policy.slot(agent.slot, radius, Policy.RingSpacing)
			return Vector3.new(center.X + x, agent.goal.Y, center.Z + z)
		end
		return agent.goal
	end
	agent.nextSlot = now + Policy.SlotInterval
	if agent.slot and agent.failures < 2 then
		-- A settled waiting clone must claim newly freed inner positions instead
		-- of keeping its outer reservation forever after a front clone dies.
		local innerBest: Vector3? = nil; local innerSlot: number? = nil; local innerDistance = math.huge
		for index = 1, math.floor((agent.slot - 1) / Policy.SlotsPerRing) * Policy.SlotsPerRing do
			local point = candidate(index)
			if point then
				local distance = flat(point-agent.root.Position).Magnitude
				if distance < innerDistance then innerBest = point; innerSlot = index; innerDistance = distance end
			end
			if index % Policy.SlotsPerRing == 0 and innerBest then break end
		end
		if innerBest then agent.slot = innerSlot; return innerBest end
		local point = candidate(agent.slot); if point then return point end
	end
	local best: Vector3? = nil; local bestSlot: number? = nil; local bestScore = math.huge
	-- Attack positions plus waiting rings for mass-clone casts. Occupied
	-- slots do not query geometry; stop after the first ring with a usable slot.
	for index = 1, 80 do
		local point = candidate(index)
		if point then
			local score = flat(point - agent.root.Position).Magnitude + math.floor((index - 1) / Policy.SlotsPerRing) * 20
			if index == agent.slot and agent.failures >= 2 then score += 100 end
			if score < bestScore then best = point; bestSlot = index; bestScore = score end
		end
		if index % Policy.SlotsPerRing == 0 and best then break end
	end
	agent.slot = bestSlot; agent.failures = 0
	return best
end
local function request(requester: Agent, now: number)
	if not requester.queued and Policy.canRequest(requester.clock, now) then
		requester.queued = true
		table.insert(waiting, { agent = requester, generation = requester.clock.generation })
	end
	if active >= Policy.MaxConcurrent or now < nextRequest then return end
	local selected: Agent? = nil
	while #waiting > 0 do
		local entry = table.remove(waiting, 1); assert(entry); local candidate = entry.agent
		if entry.generation == candidate.clock.generation and candidate.queued and agents[candidate.model] == candidate then
			candidate.queued = false
			if candidate.goal and Policy.canRequest(candidate.clock, now) then selected = candidate; break end
		end
	end
	if not selected or not selected.goal then return end
	local agent, goal = selected, selected.goal
	nextRequest = now + Policy.RequestInterval; active += 1
	local generation = Policy.begin(agent.clock, now)
	local origin = agent.root.Position
	agent.pathGoal = goal
	task.spawn(function()
		local points: { Vector3 } = {}
		local path: Path? = nil
		local ok = pcall(function()
			local computed = Pathfinding:CreatePath({ AgentRadius = math.max(1.5, agent.root.Size.X / 2, agent.root.Size.Z / 2),
				AgentHeight = math.max(5, agent.root.Size.Y), AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 3 })
			path = computed; computed:ComputeAsync(origin, goal)
			if computed.Status ~= Enum.PathStatus.Success then return end
			for _, waypoint in computed:GetWaypoints() do
				if waypoint.Action ~= Enum.PathWaypointAction.Walk then table.clear(points); return end
				table.insert(points, waypoint.Position + Vector3.new(0, agent.groundOffset, 0))
			end
		end)
		if path then path:Destroy() end
		active -= 1
		local accepted = Policy.finish(agent.clock, generation, workspace:GetServerTimeNow(), ok and #points > 1)
		if not accepted or agents[agent.model] ~= agent then return end
		-- A completed calculation for an old moving goal cannot replace the current route.
		if not agent.goal or flat(agent.goal - goal).Magnitude > Policy.GoalDrift then agent.pathGoal = nil; return end
		if ok and #points > 1 then
			agent.waypoints = points; agent.waypoint = 2
		else
			table.clear(agent.waypoints); agent.pathGoal = nil; agent.failures += 1
		end
	end)
end
local function peerClear(agent: Agent, nextPosition: Vector3, destination: BasePart): boolean
	local origin, center = agent.root.Position, destination.Position
	if math.abs(center.Y-nextPosition.Y) < 4 and not Policy.clearPeer(origin.X,origin.Z,nextPosition.X,nextPosition.Z,
		center.X,center.Z,(agent.root.Size.X+destination.Size.X)/2+0.2) then return false end
	for _, other in agents do
		if other ~= agent and math.abs(other.root.Position.Y - nextPosition.Y) < 4 then
			local p = other.root.Position; local a = agent.root.Position
			local spacing = (agent.root.Size.X + other.root.Size.X) / 2 + 0.35
			if not Policy.clearPeer(a.X, a.Z, nextPosition.X, nextPosition.Z, p.X, p.Z, spacing) then return false end
		end
	end
	return true
end
function Navigation.Step(model: Model, owner: Model, target: Model, destination: BasePart, radius: number, now: number, delta: number, speed: number): boolean
	local agent = agents[model]; if not agent then return false end
	if agent.target ~= target then
		Policy.change(agent.clock, tostring(agent.clock.generation + 1))
		agent.target = target; agent.slot = nil; agent.goal = nil; agent.pathGoal = nil; unqueue(agent)
		table.clear(agent.waypoints); agent.nextSlot = 0; agent.failures = 0; agent.progressAt = now
		agent.progressPosition = agent.root.Position
	end
	local ray = parameters(agent, owner, target)
	agent.goal = chooseGoal(agent, target, destination, math.max(2.5, radius - 0.65), ray, now)
	local goal = agent.goal
	if not goal then return false end
	local position = agent.root.Position
	if flat(goal - position).Magnitude < 0.3 then agent.progressAt = now; return false end
	if flat(position - agent.progressPosition).Magnitude > 0.4 then
		agent.progressPosition = position; agent.progressAt = now
	elseif now - agent.progressAt > Policy.StuckTime then
		table.clear(agent.waypoints); agent.pathGoal = nil; agent.failures += 1; agent.progressAt = now
	end
	local aim = goal
	if not stepClear(agent, position, goal, ray) then
		while agent.waypoint <= #agent.waypoints and flat(agent.waypoints[agent.waypoint] - position).Magnitude < 0.5 do agent.waypoint += 1 end
		local waypoint = agent.waypoints[agent.waypoint]
		if waypoint then aim = waypoint else aim = position end
		if not agent.pathGoal or flat(agent.pathGoal - goal).Magnitude > Policy.GoalDrift or not waypoint then request(agent, now) end
	else
		table.clear(agent.waypoints); agent.pathGoal = nil; unqueue(agent)
		if agent.formationTarget == target and agent.frontline then
			-- Approach a free melee place from its outside. Cutting straight through
			-- the occupied front arc traps rear clones behind settled attackers.
			local from = flat(position - destination.Position)
			local to = flat(goal - destination.Position)
			if from.Magnitude > .1 and to.Magnitude > .1 then
				local angle = math.atan2(from.X * to.Z - from.Z * to.X, from:Dot(to))
				if math.abs(angle) > .25 then
					local step = math.clamp(angle, -.35, .35)
					local direction = from.Unit
					local radial = Vector3.new(direction.X * math.cos(step) - direction.Z * math.sin(step), 0,
						direction.X * math.sin(step) + direction.Z * math.cos(step))
					local orbit = Vector3.new(destination.Position.X, position.Y, destination.Position.Z) + radial * (to.Magnitude + Policy.RingSpacing / 2)
					if clear(agent, position, orbit, ray) then aim = orbit end
				end
			end
		end
	end
	local direction = flat(aim - position)
	if direction.Magnitude < 0.001 then return false end
	local length = math.min(direction.Magnitude, speed * math.clamp(delta, 0, 0.1))
	local forward = direction.Unit
	-- Look ahead beyond this frame's step. A short sidestep only at contact can
	-- oscillate against a settled melee ring; steer toward a tangent beside its
	-- nearest blocking body before reaching contact instead.
	local blockerRoot: BasePart? = nil; local nearest = math.huge
	local look = position + forward * math.min(direction.Magnitude, 6)
	for _, other in agents do
		local p = other.root.Position
		if other ~= agent and math.abs(p.Y-position.Y) < 4 then
			local spacing = (agent.root.Size.X + other.root.Size.X) / 2 + 0.5
			local distance = flat(p-position).Magnitude
			if distance < nearest and not Policy.clearPeer(position.X,position.Z,look.X,look.Z,p.X,p.Z,spacing) then
				blockerRoot = other.root; nearest = distance
			end
		end
	end
	local center = destination.Position
	if math.abs(center.Y-position.Y) < 4 and flat(center-position).Magnitude < nearest
		and not Policy.clearPeer(position.X,position.Z,look.X,look.Z,center.X,center.Z,(agent.root.Size.X+destination.Size.X)/2+0.5) then
		blockerRoot = destination
	end
	if blockerRoot then
		local side = if agent.serial % 2 == 0 then 1 else -1
		local spacing = (agent.root.Size.X + blockerRoot.Size.X) / 2 + 1
		local tangent = flat(blockerRoot.Position-position) + Vector3.new(-forward.Z,0,forward.X) * side * spacing
		if tangent.Magnitude > 0.001 then forward = tangent.Unit end
	end
	-- Deterministic side preference breaks symmetric head-on deadlocks; final sweep
	-- and peer segment checks are mandatory even for local avoidance steps.
	local side = if agent.serial % 2 == 0 then 1 else -1
	for _, angle in { 0, side * math.pi/4, -side * math.pi/4, side * math.pi/2, -side * math.pi/2 } do
		local rotated = Vector3.new(forward.X * math.cos(angle) - forward.Z * math.sin(angle), 0,
			forward.X * math.sin(angle) + forward.Z * math.cos(angle))
		local point = ground(agent, position + rotated * length, ray)
		if point and math.abs(point.Y - position.Y) <= math.max(stepHeight,length + 0.25) and stepClear(agent, position, point, ray)
			and bodyClear(agent, point, ray) and peerClear(agent, point, destination) then
			model:PivotTo(model:GetPivot() + (point - position)); return true
		end
	end
	return false
end
return Navigation
