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
	serial: number, combatTarget: Model?, combatOffset: Vector3?,
	laneAssault: boolean, passUntil: number, passGoal: Vector3?, passes: number,
	connections: { RBXScriptConnection },
}
local AI = { Shot = Instance.new("BindableEvent") }
local records: { [Model]: Minion } = {}
local grid: { [string]: { Model } } = {}
local active = 0
local running = false
local serial = 0
local function flat(v: Vector3): Vector3 return v*Vector3.new(1,0,1) end
local function setMode(npc: Minion, mode: string)
	if npc.mode ~= mode then npc.mode = mode; npc.model:SetAttribute("AIState", mode) end
end
local function dead(npc: Minion)
	if npc.deadAt then return end
	active -= 1; npc.deadAt = workspace:GetServerTimeNow(); npc.target = nil
	npc.model:SetAttribute("MinionDiedAt", npc.deadAt)
	setMode(npc, "Dead"); npc.model:SetAttribute("CombatDisabled", true)
	npc.model:SetAttribute("TargetName", "")
	for _, item in npc.model:GetDescendants() do if item:IsA("BasePart") then item.CanCollide=false end end
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
	if records[model] then return end
	local match = Teams.GetState(); if match then model:SetAttribute("RoundId", match.roundId) end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local now = workspace:GetServerTimeNow()
	serial += 1
	local npc: Minion = { model = model, humanoid = humanoid, root = root, teamId = teamId, kind = kind, lane = lane,
		stats = stats, route = route, waypoint = 1, target = nil, mode = "Spawning",
		nextAttack = now + Config.SpawnGrace, spawnedAt = now, deadAt = nil,
		lastPosition = root.Position, progressAt = now, recoveries = 0, recoveryUntil = 0, recoveryGoal = nil, connections = {},
		serial=serial,combatTarget=nil,combatOffset=nil,laneAssault=false,passUntil=0,passGoal=nil,passes=0 }
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
function AI.Reset()
	running = false
	for model in records do AI.Remove(model) end
	table.clear(grid); active = 0
end
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
	-- Once a wave reaches its lane defenses, the newly unlocked tower is its
	-- objective even beyond local detection range. Never return to an old waypoint.
	local ownTower: Model? = nil; local ownTier=math.huge
	for model, tower in Structures.GetAll() do
		if tower.kind=="Tower" and tower.lane==npc.lane and Structures.Alive(tower) and Damage.CanDamage(npc.model,model) then
			local level=(model:GetAttribute("TowerTier") or 1) :: number
			if level<ownTier then ownTower=model;ownTier=level end
		end
	end
	if ownTower then
		local root=ownTower.PrimaryPart
		if root and (npc.laneAssault or (root.Position-origin).Magnitude<=math.max(npc.stats.DetectionRange,Config.StructureDetectionRange)) then return ownTower end
	end
	local selected: Model? = nil; local distance = math.huge
	for model, tower in Structures.GetAll() do
		if tower.kind ~= "Tower" or not Structures.Alive(tower) then continue end
		if ownTower and tower.lane~=npc.lane then continue end
		local separation = (tower.root.Position - origin).Magnitude
		local sameLane = tower.lane == npc.lane
		if separation <= (if sameLane then math.max(npc.stats.DetectionRange,Config.StructureDetectionRange) else npc.stats.AttackRange)
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
local function crowded(npc: Minion, radius: number?): boolean
	for _, peer in records do
		if peer~=npc and not peer.deadAt and math.abs(peer.root.Position.Y-npc.root.Position.Y)<4
			and flat(peer.root.Position-npc.root.Position).Magnitude<(radius or Config.Separation-.2) then return true end
	end
	return false
end
local function combatGoal(npc: Minion, target: Model, center: Vector3): Vector3?
	if npc.combatTarget~=target then
		npc.combatTarget=target;npc.combatOffset=nil;npc.passUntil=0;npc.passGoal=nil;npc.recoveryUntil=0
	end
	local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances={npc.model.Parent :: Instance};overlap.RespectCanCollide=true
	overlap.CollisionGroup="SurvivalMinions"
	local function free(offset: Vector3): boolean
		for _, other in records do
			if other~=npc and not other.deadAt and other.combatTarget==target and other.combatOffset
				and (offset-other.combatOffset).Magnitude<Config.Separation then return false end
		end
		return #workspace:GetPartBoundsInBox(CFrame.new(center+offset),Vector3.new(Config.BodyDiameter,4,Config.BodyDiameter),overlap)==0
	end
	local radius=npc.stats.AttackRange-.6
	if npc.combatOffset and npc.combatOffset.Magnitude<=radius+.01 and free(npc.combatOffset) then return center+npc.combatOffset end
	-- Full melee positions must not strand the rest of a wave at the old tower.
	-- Reserve spaced waiting rings and promote them as inner positions become free.
	for ring=0,3 do
		if ring>0 and npc.combatOffset and math.abs(npc.combatOffset.Magnitude-(radius+ring*Config.Separation))<.01
			and free(npc.combatOffset) then return center+npc.combatOffset end
		local best: Vector3?=nil;local score=math.huge
		local count=12+ring*6
		for i=0,count-1 do
			local angle=i*2*math.pi/count;local offset=Vector3.new(math.cos(angle),0,math.sin(angle))*(radius+ring*Config.Separation)
			if free(offset) then
				local distance=flat(center+offset-npc.root.Position).Magnitude
				if distance<score then best=offset;score=distance end
			end
		end
		if best then npc.combatOffset=best;return center+best end
	end
	npc.combatOffset=nil;return nil
end
local function steer(npc: Minion, goal: Vector3): Vector3
	local delta=flat(goal-npc.root.Position);if delta.Magnitude<.2 then return goal end
	local forward=delta.Unit;local force=Vector3.zero
	for _, peer in records do
		if peer==npc or peer.deadAt or math.abs(peer.root.Position.Y-npc.root.Position.Y)>4 then continue end
		local away=flat(npc.root.Position-peer.root.Position);local distance=away.Magnitude
		if distance>=Config.AvoidanceRadius then continue end
		if distance<.01 then away=Vector3.new(if npc.serial<peer.serial then -1 else 1,0,0);distance=.01 end
		if distance<Config.Separation then force+=away.Unit*((Config.Separation-distance)/Config.Separation)*2 end
		local ahead=-away:Dot(forward)
		if ahead>0 and ahead<Config.AvoidanceRadius and (away+forward*ahead).Magnitude<Config.BodyDiameter then
			local side=if npc.serial%2==0 then 1 else -1
			force+=Vector3.new(-forward.Z,0,forward.X)*side*(1-distance/Config.AvoidanceRadius)
		end
	end
	local direction=forward+force
	-- The far side of a tower needs a route beside its solid base, not MoveTo
	-- through its center. Keep the detour outside the full horizontal footprint.
	local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances={npc.model.Parent :: Instance};ray.RespectCanCollide=true;ray.CollisionGroup="SurvivalMinions"
	local hit=workspace:Blockcast(CFrame.new(npc.root.Position),Vector3.new(Config.BodyDiameter,4,Config.BodyDiameter),forward*math.min(delta.Magnitude,6),ray)
	if hit and hit.Instance:IsA("BasePart") then
		local obstacle=hit.Instance;local radial=flat(npc.root.Position-obstacle.Position)
		if radial.Magnitude>.1 then
			local toward=flat(goal-obstacle.Position)
			local cross=radial.X*toward.Z-radial.Z*toward.X
			local side=if math.abs(cross)>.1 then (if cross>0 then 1 else -1) else (if npc.serial%2==0 then 1 else -1)
			local clearance=Vector2.new(obstacle.Size.X,obstacle.Size.Z).Magnitude/2+Config.BodyDiameter/2+.4
			local tangent=Vector3.new(-radial.Unit.Z,0,radial.Unit.X)*side
			local around=obstacle.Position+radial.Unit*clearance+tangent*3
			direction=flat(around-npc.root.Position).Unit+force*.4
		end
	end
	return if direction.Magnitude>.1 then npc.root.Position+direction.Unit*math.min(delta.Magnitude,6) else npc.root.Position
end
local function move(npc: Minion, goal: Vector3, now: number)
	setMode(npc, "Moving")
	local displacement = (npc.root.Position - npc.lastPosition) * Vector3.new(1, 0, 1)
	if displacement.Magnitude >= Config.ProgressDistance then
		npc.lastPosition = npc.root.Position; npc.progressAt = now
	end
	local congestion=crowded(npc,Config.AvoidanceRadius)
	-- A stationary ally must not suppress recovery forever. Use a short, stable
	-- passing maneuver while retaining collisions and the lane objective.
	if congestion and now-npc.progressAt>=1.2 and now>=npc.passUntil then
		local delta=flat(goal-npc.root.Position)
		if delta.Magnitude>.1 then
			npc.passes+=1
			local side=if (npc.serial+npc.passes)%2==0 then 1 else -1
			npc.passGoal=npc.root.Position+Vector3.new(-delta.Unit.Z,0,delta.Unit.X)*side*Config.Separation+delta.Unit*2
			npc.passUntil=now+1;npc.progressAt=now
		end
	end
	if now - npc.progressAt >= Config.StuckTime and not congestion then
		npc.recoveries += 1; npc.progressAt = now
		if npc.recoveries > Config.MaxRecoveryAttempts then
			warn(string.format("[Minions] Despawn stuck %s lane=%s waypoint=%d", npc.model.Name, npc.lane, npc.waypoint))
			AI.Remove(npc.model); return
		end
		local delta = goal - npc.root.Position
		local side = Vector3.new(-delta.Z, 0, delta.X)
		if side.Magnitude > 0.01 then side = side.Unit else side = Vector3.zAxis end
		npc.recoveryGoal = npc.root.Position + side * Config.RecoveryOffset * (if npc.recoveries % 2 == 1 then 1 else -1)
		npc.recoveryUntil = now + 1
		warn(string.format("[Minions] Recovery %d/%d: %s %s", npc.recoveries, Config.MaxRecoveryAttempts, npc.model.Name, npc.lane))
	end
	local destination=if now<npc.passUntil and npc.passGoal then npc.passGoal
		elseif now < npc.recoveryUntil and npc.recoveryGoal then npc.recoveryGoal else goal
	npc.humanoid:MoveTo(steer(npc,destination))
end
-- Project onto the lane polyline. Between distant towers keep every bend;
-- a global assault objective must never turn into a shortcut through the jungle.
local function laneGoal(npc: Minion, objective: Vector3?): Vector3?
	local function project(position: Vector3): (number, number)
		local best=math.huge;local index=1;local fraction=0
		for i=1,#npc.route-1 do
			local a=npc.route[i];local delta=flat(npc.route[i+1]-a)
			local t=math.clamp(flat(position-a):Dot(delta)/delta:Dot(delta),0,1)
			local distance=flat(position-a-delta*t).Magnitude
			if distance<best then best=distance;index=i;fraction=t end
		end
		return index,fraction
	end
	local segment,t=project(npc.root.Position)
	if objective then
		local targetSegment=project(objective)
		if targetSegment<=segment then return nil end
	end
	local index=segment+1
	if t>.97 then index+=1 end
	if index>#npc.route then return nil end
	if npc.waypoint~=index then npc.waypoint=index;npc.recoveries=0;npc.model:SetAttribute("Waypoint",index) end
	local point=npc.route[index];local direction=flat(point-npc.route[index-1]).Unit
	return point+Vector3.new(-direction.Z,0,direction.X)*((npc.model:GetAttribute("LaneOffset") or 0) :: number)
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
		if not fighter or fighter.logic.mode == "Stunned" or (fighter.sleep and fighter.sleep.active) then
			npc.progressAt = now; npc.lastPosition = npc.root.Position; continue
		end
		if not Damage.CanAct(model) then continue end
		local target = selectTarget(npc)
		npc.target = target; model:SetAttribute("TargetName", if target then target.Name else "")
		local goal: Vector3? = nil
		if target then
			if target:GetAttribute("EntityKind")=="Tower" and target:GetAttribute("Lane")==npc.lane then npc.laneAssault=true end
			local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart
			local position=targetRoot.Position
			if target:GetAttribute("EntityKind")=="Tower" and target:GetAttribute("Lane")==npc.lane and flat(position-npc.root.Position).Magnitude>30 then
				local routeGoal=laneGoal(npc,position)
				if routeGoal then
					npc.combatTarget=nil;npc.combatOffset=nil
					move(npc,routeGoal,now);continue
				end
			end
			goal = combatGoal(npc,target,position)
			if (position - npc.root.Position).Magnitude <= npc.stats.AttackRange and visible(npc, target, position) and not crowded(npc) then
				setMode(npc, "Attacking"); npc.humanoid:MoveTo(npc.root.Position); npc.progressAt = now
				if now >= npc.nextAttack then
					npc.nextAttack = now + npc.stats.AttackCooldown
					-- Presentation timestamp only; the existing server damage/cooldown stays authoritative.
					model:SetAttribute("MinionAttackAt", now)
					local humanoid = target:FindFirstChildOfClass("Humanoid")
					if humanoid and Damage.ApplyAttack(model, humanoid, npc.stats.Damage) > 0 then
						AI.Shot:Fire(npc.root.Position, position, npc.kind, npc.teamId, target, model:GetAttribute("RoundId"))
					end
				end
				continue
			end
			if goal and flat(goal-npc.root.Position).Magnitude<.8 and (position-npc.root.Position).Magnitude>npc.stats.AttackRange then
				-- An occupied melee front has a real waiting position. Arrival is
				-- progress, not a stuck MoveTo that should eventually delete the unit.
				setMode(npc,"Waiting");npc.humanoid:MoveTo(npc.root.Position);npc.progressAt=now
				npc.passUntil=0;npc.recoveryUntil=0;continue
			end
		else
			npc.combatTarget=nil;npc.combatOffset=nil
			goal = laneGoal(npc,nil) or baseGoal(npc)
		end
		if goal then move(npc, goal, now)
		else npc.humanoid:MoveTo(npc.root.Position);npc.progressAt=now end
	end
end
return AI
