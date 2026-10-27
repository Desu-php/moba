--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Players = game:GetService("Players")
local Config = require(Shared.Config.MinionConfig)
local MapConfig = require(Shared.Config.MapConfig)
local Fighters = require(script.Parent.FighterStateService)
local Damage = require(script.Parent.DamageService)
local Teams = require(script.Parent.TeamService)
local Bases = require(script.Parent.BaseService)
local Structures = require(script.Parent.StructureService)
export type Minion = {
	model: Model, humanoid: Humanoid, root: BasePart, teamId: string, kind: string, lane: string,
	stats: Config.Stats, route: { Vector3 }, waypoint: number, target: Model?, mode: string,
	nextAttack: number, spawnedAt: number, deadAt: number?, lastPosition: Vector3,
	progressAt: number, recoveries: number, recoveryUntil: number, recoveryGoal: Vector3?,
	connections: { RBXScriptConnection },
}
local AI = { Shot = Instance.new("BindableEvent") }
local records: { [Model]: Minion } = {}
local grid: { [string]: { Model } } = {}
local active = 0
local running = false
local function setMode(npc: Minion, mode: string)
	if npc.mode ~= mode then npc.mode = mode; npc.model:SetAttribute("AIState", mode) end
end
local function dead(npc: Minion)
	if npc.deadAt then return end
	active -= 1; npc.deadAt = workspace:GetServerTimeNow(); npc.target = nil
	setMode(npc, "Dead"); npc.model:SetAttribute("CombatDisabled", true)
	npc.model:SetAttribute("TargetName", "")
	npc.humanoid:Move(Vector3.zero)
end
function AI.Remove(model: Model)
	local npc = records[model]; if not npc then return end
	if not npc.deadAt then active -= 1 end
	records[model] = nil
	for _, connection in npc.connections do connection:Disconnect() end
	Fighters.Remove(model); model:Destroy()
end
function AI.Register(model: Model, teamId: string, kind: string, lane: string, route: { Vector3 }, stats: Config.Stats)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local now = workspace:GetServerTimeNow()
	local npc: Minion = { model = model, humanoid = humanoid, root = root, teamId = teamId, kind = kind, lane = lane,
		stats = stats, route = route, waypoint = 1, target = nil, mode = "Spawning",
		nextAttack = now + Config.SpawnGrace, spawnedAt = now, deadAt = nil,
		lastPosition = root.Position, progressAt = now, recoveries = 0, recoveryUntil = 0, recoveryGoal = nil, connections = {} }
	records[model] = npc; active += 1
	model:SetAttribute("Lane", lane); model:SetAttribute("AIState", "Spawning"); model:SetAttribute("Waypoint", 1)
	if root:CanSetNetworkOwnership() then root:SetNetworkOwner(nil) end
	Fighters.GetOrCreate(model)
	table.insert(npc.connections, humanoid.Died:Connect(function() dead(npc) end))
	table.insert(npc.connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then AI.Remove(model) end
	end))
end
function AI.GetCount(): number return active end
function AI.GetAll(): { [Model]: Minion } return records end
function AI.SetRunning(value: boolean)
	running = value
	if not value then
		for _, npc in records do
			npc.target = nil; npc.humanoid:MoveTo(npc.root.Position); npc.humanoid.WalkSpeed = 0
			npc.model:SetAttribute("CombatDisabled", true)
		end
	end
end
function AI.RemoveTeam(id: string)
	local remove = {}; for model, npc in records do if npc.teamId == id then table.insert(remove, model) end end
	for _, model in remove do AI.Remove(model) end
end
local function cell(position: Vector3): string
	return math.floor(position.X / Config.SpatialCellSize) .. ":" .. math.floor(position.Z / Config.SpatialCellSize)
end
local function rebuildGrid()
	table.clear(grid)
	for model, fighter in Fighters.GetAll() do
		if fighter.humanoid.Health > 0 and model.Parent then
			local key = cell(fighter.root.Position)
			local bucket = grid[key]
			if not bucket then bucket = {}; grid[key] = bucket end
			table.insert(bucket, model)
		end
	end
end
local function selectTarget(npc: Minion): Model?
	local nearestNPC, nearestHero: Model? = nil, nil
	local npcDistance, heroDistance = math.huge, math.huge
	local radius = npc.stats.DetectionRange
	local origin = npc.root.Position
	local minX, maxX = math.floor((origin.X - radius) / Config.SpatialCellSize), math.floor((origin.X + radius) / Config.SpatialCellSize)
	local minZ, maxZ = math.floor((origin.Z - radius) / Config.SpatialCellSize), math.floor((origin.Z + radius) / Config.SpatialCellSize)
	for x = minX, maxX do for z = minZ, maxZ do
		for _, model in grid[x .. ":" .. z] or {} do
			if not Damage.CanDamage(npc.model, model) then continue end
			local root = model:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then continue end
			local distance = (root.Position - origin).Magnitude
			if distance > radius then continue end
			if model:GetAttribute("EntityKind") == "Minion" then
				if distance < npcDistance then nearestNPC = model; npcDistance = distance end
			elseif distance < heroDistance then nearestHero = model; heroDistance = distance end
		end
	end end
	if nearestNPC then return nearestNPC end
	if nearestHero then return nearestHero end
	local selected: Model? = nil; local distance = math.huge
	for model, tower in Structures.GetAll() do
		if tower.kind ~= "Tower" or not Structures.Alive(tower) then continue end
		local separation = (tower.root.Position - origin).Magnitude
		local sameLane = tower.lane == npc.lane
		if separation <= (if sameLane then npc.stats.DetectionRange else npc.stats.AttackRange)
			and (separation < distance or (separation == distance and selected ~= nil and model.Name < selected.Name))
			and Damage.CanDamage(npc.model, model) then selected = model; distance = separation end
	end
	if selected then return selected end
	for _, base in Bases.GetAll() do
		local separation = (base.root.Position - origin).Magnitude
		if separation <= npc.stats.AttackRange and separation < distance and Damage.CanDamage(npc.model, base.model) then
			selected = base.model; distance = separation
		end
	end
	return selected
end
local function baseGoal(npc: Minion): Vector3?
	local selected: Vector3? = nil; local nearest = math.huge
	-- Once the lane route is complete, help another lane if its towers still shield the core.
	-- Own-lane towers always take precedence; the outer route keeps cross-lane travel away from rocks.
	local ownLane = false
	for model, tower in Structures.GetAll() do
		if tower.kind ~= "Tower" or not Structures.Alive(tower) or not Damage.CanDamage(npc.model, model) then continue end
		local sameLane = tower.lane == npc.lane
		local distance = (tower.root.Position - npc.root.Position).Magnitude
		if (sameLane and not ownLane) or (sameLane == ownLane and distance < nearest) then
			selected = tower.root.Position; nearest = distance; ownLane = sameLane
		end
	end
	if selected then return selected end
	for _, base in Bases.GetAll() do
		if Teams.IsActive(base.teamId) and base.teamId ~= npc.teamId and Structures.CanReceive(base.model) then
			local distance = (base.root.Position - npc.root.Position).Magnitude
			if distance < nearest then selected = base.root.Position; nearest = distance end
		end
	end
	return selected
end
local function visible(npc: Minion, target: Model, position: Vector3): boolean
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: { Instance } = { npc.model, target, npc.model.Parent :: Instance }
	-- Actors do not obstruct a confirmed shot; solid map geometry still does.
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(excluded, player.Character) end
	end
	params.FilterDescendantsInstances = excluded
	params.RespectCanCollide = true
	return workspace:Raycast(npc.root.Position, position - npc.root.Position, params) == nil
end
local function move(npc: Minion, goal: Vector3, now: number)
	setMode(npc, "Moving")
	local displacement = (npc.root.Position - npc.lastPosition) * Vector3.new(1, 0, 1)
	if displacement.Magnitude >= Config.ProgressDistance then
		npc.lastPosition = npc.root.Position; npc.progressAt = now
	end
	if now - npc.progressAt >= Config.StuckTime then
		npc.recoveries += 1; npc.progressAt = now
		if npc.recoveries > Config.MaxRecoveryAttempts then
			warn(string.format("[Minions] Despawn stuck %s lane=%s waypoint=%d", npc.model.Name, npc.lane, npc.waypoint))
			AI.Remove(npc.model); return
		end
		npc.humanoid.Jump = true
		local delta = goal - npc.root.Position
		local side = Vector3.new(-delta.Z, 0, delta.X)
		if side.Magnitude > 0.01 then side = side.Unit else side = Vector3.zAxis end
		npc.recoveryGoal = npc.root.Position + side * Config.RecoveryOffset * (if npc.recoveries % 2 == 1 then 1 else -1)
		npc.recoveryUntil = now + 1
		warn(string.format("[Minions] Recovery %d/%d: %s %s", npc.recoveries, Config.MaxRecoveryAttempts, npc.model.Name, npc.lane))
	end
	npc.humanoid:MoveTo(if now < npc.recoveryUntil and npc.recoveryGoal then npc.recoveryGoal else goal)
end
function AI.Update(now: number)
	-- Corpse cleanup also runs after the match has stopped.
	local remove = {}
	for model, npc in records do
		if npc.deadAt and now - npc.deadAt >= Config.CorpseLifetime then table.insert(remove, model) end
	end
	for _, model in remove do AI.Remove(model) end
	if not running then return end
	rebuildGrid()
	for model, npc in records do
		if npc.deadAt or now - npc.spawnedAt < Config.SpawnGrace then continue end
		if npc.humanoid.Health <= 0 then dead(npc); continue end
		if npc.root.Position.Y < MapConfig.Origin.Y - 15 then AI.Remove(model); continue end
		local fighter = Fighters.Get(model)
		if not fighter or fighter.logic.mode == "Stunned" then
			npc.progressAt = now; npc.lastPosition = npc.root.Position; continue
		end
		if not Damage.CanAct(model) then continue end
		local target = selectTarget(npc)
		npc.target = target; model:SetAttribute("TargetName", if target then target.Name else "")
		local goal: Vector3? = nil
		if target then
			local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart
			goal = targetRoot.Position
			if (goal - npc.root.Position).Magnitude <= npc.stats.AttackRange and visible(npc, target, goal) then
				setMode(npc, "Attacking"); npc.humanoid:MoveTo(npc.root.Position); npc.progressAt = now
				if now >= npc.nextAttack then
					npc.nextAttack = now + npc.stats.AttackCooldown
					local humanoid = target:FindFirstChildOfClass("Humanoid")
					if humanoid and Damage.Apply(model, humanoid, npc.stats.Damage) > 0 then
						AI.Shot:Fire(npc.root.Position, goal, npc.kind, npc.teamId, target)
					end
				end
				continue
			end
		else
			local waypoint = npc.route[npc.waypoint]
			if waypoint and ((waypoint - npc.root.Position) * Vector3.new(1, 0, 1)).Magnitude <= Config.WaypointRadius then
				npc.waypoint += 1; npc.recoveries = 0; model:SetAttribute("Waypoint", npc.waypoint)
				waypoint = npc.route[npc.waypoint]
			end
			goal = waypoint or baseGoal(npc)
		end
		if goal then move(npc, goal, now) end
	end
end
return AI
