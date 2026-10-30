--!strict
assert(game:GetService("RunService"):IsStudio())
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.TowerConfig)
local Match = require(services.MatchService)
local Towers = require(services.TowerService)
local Structures = require(services.StructureService)
local Builder = require(services.MapBuilder)
local Bases = require(services.BaseService)
local Damage = require(services.DamageService)
local Fighters = require(services.FighterStateService)
local Economy = require(services.EconomyService)
local Progression = require(services.HeroProgressionService)
local Rewards = require(services.RewardService)
local AI = require(services.MinionAIService)
local Spawner = require(services.MinionSpawnerService)
local Ability = require(services.AbilityService)
local remote = Instance.new("RemoteEvent"); remote.Name = "TowerTestDriver"; remote.Parent = ReplicatedStorage
local replies: { [Player]: { id: number, value: any } } = {}
remote.OnServerEvent:Connect(function(player: Player, id: number, value: any) replies[player] = { id = id, value = value } end)
local count, sequence, abilityId = 0, 0, 0
local function check(name: string, value: boolean) assert(value, name); count += 1; print("[TowerTests] PASS: " .. name) end
local function untilTrue(predicate: () -> boolean, seconds: number, message: string)
	local deadline = os.clock() + seconds
	repeat if predicate() then return end; task.wait(0.02) until os.clock() >= deadline
	error(message)
end
local function command(player: Player, mode: string): any
	sequence += 1; local id = sequence; remote:FireClient(player, id, mode)
	untilTrue(function() return replies[player] ~= nil and replies[player].id == id end, 10, "Client timeout")
	return replies[player].value
end
local function body(player: Player): (Model, Humanoid, BasePart)
	local model = player.Character; assert(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid"); local root = model:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and root:IsA("BasePart")); return model, humanoid, root
end
local function arrange(player: Player, position: Vector3, face: Vector3?)
	local model, humanoid, root = body(player)
	for _, item in model:GetChildren() do if item:IsA("ForceField") or (item:IsA("Script") and item.Name == "Health") then item:Destroy() end end
	root.CFrame = CFrame.lookAt(position, face or position + Vector3.new(0, 0, -1)); root.AssemblyLinearVelocity = Vector3.zero
	root:SetNetworkOwner(nil); humanoid.AutoRotate = false
end
local function npc(team: string, lane: string, kind: string, position: Vector3): AI.Minion
	local model = Spawner.Spawn(team, lane, kind, 1); assert(model)
	local record = AI.GetAll()[model]; record.root.CFrame = CFrame.new(position); record.root.Anchored = true; return record
end
local function tower(team: string, lane: string): Towers.Tower
	for _, record in Towers.GetAll() do if record.structure.teamId == team and record.structure.lane == lane then return record end end
	error("Tower missing")
end
local function cast(player: Player, id: string)
	Ability.Reset(); task.wait(1); abilityId += 1
	check(id .. " cast accepted", Ability.TryCast(player, abilityId, player.Character, id))
end
local function clearNPCs() for model in AI.GetAll() do AI.Remove(model) end end
local ok, failure = xpcall(function()
	untilTrue(function() return #Players:GetPlayers() == 2 and Match.GetState() ~= nil end, 120, "Start Server & Clients with 2 clients")
	local state = Match.GetState(); assert(state)
	untilTrue(function() return state.phase == "InProgress" end, 30, "Match not running")
	local blue: Player?; local red: Player?
	for _, player in Players:GetPlayers() do if player:GetAttribute("TeamId") == "Blue" then blue = player else red = player end end
	assert(blue and red); local first, second = blue :: Player, red :: Player
	untilTrue(function() return first.Character ~= nil and second.Character ~= nil and first.Character:GetAttribute("HeroId") ~= nil end, 20, "Hero missing")
	state.startedAt = workspace:GetServerTimeNow() + 10000; state.nextWaveAt = state.startedAt; Rewards.Reset()
	AI.SetRunning(false); clearNPCs(); arrange(first, Vector3.new(0, 36, 0)); arrange(second, Vector3.new(0, 36, 50))
	local model, humanoid, _root = body(first); local enemyModel = body(second)
	local map = Builder.Build(); local container = map:FindFirstChild("Towers"); assert(container)
	local originalCount = #container:GetChildren()
	local userGeometry = Instance.new("Folder"); userGeometry.Name = "TowerTestUserGeometry"; userGeometry.Parent = map
	Builder.Build(); Towers.Start(map); Match.Start()
	check("exactly six towers without duplicate Build or Start", originalCount == 6 and #container:GetChildren() == 6)
	check("unknown map content preserved", userGeometry.Parent == map); userGeometry:Destroy()
	check("three towers per team", Structures.Remaining("Blue") == 3 and Structures.Remaining("Red") == 3)
	local sentry = tower("Red", "Mid"); local position = sentry.structure.root.Position
	local base = Bases.Get("Red"); assert(base)
	check("allied damage blocked", Damage.Apply(enemyModel, sentry.structure.humanoid, 50) == 0)
	check("direct damage blocked by central shield", Damage.Apply(model, base.humanoid, 99999) == 0)
	check("structures never registered as fighters", Fighters.GetOrCreate(sentry.structure.model) == nil and Fighters.GetOrCreate(base.model) == nil)
	local safe = true
	for _, item in sentry.structure.model:GetDescendants() do
		if item:IsA("BasePart") and item ~= sentry.structure.root then safe = safe and not item.CanQuery and not item.CanTouch and not item.CanCollide end
	end
	check("decorations do not expand hurtbox", safe)
	local victim = npc("Blue", "Mid", "Melee", position + Vector3.new(0, 0, -12))
	untilTrue(function() return sentry.logic.shot ~= nil end, 3, "Tower did not prepare")
	local wall = Instance.new("Part"); wall.Size = Vector3.new(16, 14, 1); wall.Anchored = true; wall.Position = position + Vector3.new(0, 0, -6); wall.Parent = workspace
	task.wait(0.6); check("new wall cancels prepared contact", victim.humanoid.Health == 100)
	wall:Destroy(); untilTrue(function() return sentry.logic.shot ~= nil end, 3, "Tower did not reacquire")
	victim.root.CFrame = CFrame.new(position + Vector3.new(0, 0, -40)); task.wait(0.6)
	check("range checked again at contact", victim.humanoid.Health == 100)
	victim.root.CFrame = CFrame.new(position + Vector3.new(0, 0, -12))
	untilTrue(function() return victim.humanoid.Health < 100 end, 3, "No tower shot")
	check("tower shot deals eighteen", victim.humanoid.Health == 82)
	local snapshot = command(first, "inspect"); local observer = command(second, "inspect")
	check("both clients show structure health and roster HUD", snapshot.towerLabels == 6 and observer.towerLabels == 6 and snapshot.portraitSlots == 10 and observer.portraitSlots == 10 and snapshot.hero and snapshot.abilities)
	check("bounded cosmetic effects", snapshot.safeEffects and observer.safeEffects and snapshot.effectCount <= Config.Visual.MaxEffects)
	check("shot events reach both clients", snapshot.shots > 0 and observer.shots > 0)
	arrange(first, position + Vector3.new(-8, 0, -6)); arrange(second, position + Vector3.new(0, 0, -8))
	local aggroBefore = sentry.logic.aggroUntil
	check("hero damage confirmed", Damage.Apply(model, select(2, body(second)), 1) == 1)
	task.wait(0.05); check("hero damage triggers defensive aggression", sentry.logic.aggro ~= nil and sentry.logic.aggroUntil > aggroBefore)
	arrange(first, Vector3.new(0, 36, 0)); task.wait(1.5)
	check("out of range aggressor released", sentry.logic.aggro == nil)
	arrange(second, Vector3.new(0, 36, 50)); clearNPCs()
	victim = npc("Blue", "Mid", "Melee", position + Vector3.new(0, 0, -12))
	untilTrue(function() return sentry.logic.shot ~= nil end, 3, "No pending shot before finish")
	local before = victim.humanoid.Health; state.phase = "Finished"; Towers.Update(workspace:GetServerTimeNow()); task.wait(0.5)
	check("Finished cancels prepared shot", sentry.logic.shot == nil and victim.humanoid.Health == before)
	state.phase = "InProgress"; clearNPCs()
	victim = npc("Blue", "Mid", "Melee", position + Vector3.new(0, 0, -12))
	untilTrue(function() return sentry.logic.shot ~= nil end, 3, "No pending shot before removal")
	victim.model:Destroy(); task.wait(0.5); check("removed target cancels pending shot", sentry.logic.shot == nil)
	local removedTower = tower("Blue", "Bottom")
	victim = npc("Red", "Bottom", "Melee", removedTower.structure.root.Position + Vector3.new(0, 0, -12))
	untilTrue(function() return removedTower.logic.shot ~= nil end, 3, "No pending shot before tower removal")
	before = victim.humanoid.Health; removedTower.structure.model.Parent = nil; Towers.Update(workspace:GetServerTimeNow()); task.wait(0.5)
	check("removed tower cancels pending shot and unregisters", victim.humanoid.Health == before and Towers.GetAll()[removedTower.structure.model] == nil and Structures.GetAll()[removedTower.structure.model] == nil)
	removedTower.structure.model:Destroy()
	-- Range zero isolates existing offensive systems from incoming tower fire in the following checks.
	Config.Range = 0; Towers.CancelAll(); clearNPCs()
	arrange(first, position + Vector3.new(0, 0, -4.5), position)
	local towerHP = sentry.structure.humanoid.Health
	check("real client M1 accepted", command(first, "attack").accepted)
	check("M1 damages tower without stun or movement", sentry.structure.humanoid.Health == towerHP - 5 and Fighters.Get(sentry.structure.model) == nil and sentry.structure.root.Position == position)
	require(services.HeroProgressionService).AddXP(first, 450)
	towerHP = sentry.structure.humanoid.Health
	cast(first, "Rasengan"); task.wait(2.2); command(first, "attack")
	local q = require(services.NarutoAbilityService).Get(first); assert(q)
	check("structure receives M1 but cannot consume Rasengan", math.abs(sentry.structure.humanoid.Health - (towerHP - 5.3)) < 0.001
		and q.q.active ~= nil and q.q.active.phase == "Holding" and sentry.structure.model:GetAttribute("CombatState") == nil)
	towerHP = sentry.structure.humanoid.Health
	cast(first, "ShadowClones"); task.wait(3.4)
	check("summons exclude structures", sentry.structure.humanoid.Health == towerHP)
	Ability.Reset()
	arrange(first, base.root.Position + Vector3.new(-4.5, 0, 0), base.root.Position)
	task.wait(1.3); command(first, "attack"); check("M1 cannot bypass base shield", base.humanoid.Health == base.humanoid.MaxHealth)
	cast(first, "Rasengan"); task.wait(2.2); command(first, "attack")
	check("prepared Rasengan cannot bypass base shield", base.humanoid.Health == base.humanoid.MaxHealth)
	cast(first, "ShadowClones"); task.wait(1)
	check("clones cannot bypass base shield", base.humanoid.Health == base.humanoid.MaxHealth); Ability.Reset()
	local melee = npc("Blue", "Mid", "Melee", base.root.Position + Vector3.new(-4, 0, 0))
	local ranged = npc("Blue", "Mid", "Ranged", base.root.Position + Vector3.new(-12, 0, 0))
	AI.SetRunning(true); melee.spawnedAt = 0; ranged.spawnedAt = 0; AI.Update(workspace:GetServerTimeNow())
	check("minions cannot bypass shield", base.humanoid.Health == base.humanoid.MaxHealth and melee.target ~= base.model and ranged.target ~= base.model)
	clearNPCs()
	local top = tower("Red", "Top")
	melee = npc("Blue", "Top", "Melee", top.structure.root.Position + Vector3.new(0, 0, 4))
	melee.spawnedAt = 0; before = top.structure.humanoid.Health; AI.Update(workspace:GetServerTimeNow() + 1)
	check("melee minion attacks its lane tower", top.structure.humanoid.Health == before - 8 and melee.target == top.structure.model)
	local opposing = npc("Red", "Top", "Melee", melee.root.Position + Vector3.new(2, 0, 0))
	AI.Update(workspace:GetServerTimeNow() + 1.1)
	check("nearby enemy minion takes priority over tower", melee.target == opposing.model)
	clearNPCs()
	ranged = npc("Blue", "Top", "Ranged", top.structure.root.Position + Vector3.new(0, 0, 12)); ranged.spawnedAt = 0
	before = top.structure.humanoid.Health; AI.Update(workspace:GetServerTimeNow() + 1)
	check("ranged minion attacks tower", top.structure.humanoid.Health == before - 12)
	-- A single surviving lane wave can finish the low-HP objective and continue physically along the route.
	top.structure.humanoid.Health = 8; clearNPCs()
	melee = npc("Blue", "Top", "Melee", top.structure.root.Position + Vector3.new(0, 0, 4)); melee.spawnedAt = 0
	melee.waypoint = 4; melee.root.Anchored = false; local moveFrom = melee.root.Position
	untilTrue(function() return top.logic.destroyed end, 4, "Minion did not finish tower")
	untilTrue(function() return (melee.root.Position - moveFrom).Magnitude > 6 end, 5, "Minion stuck at ruin")
	check("minion destroys tower and continues route", melee.target ~= top.structure.model)
	clearNPCs(); AI.SetRunning(false)
	check("two towers still shield core", Structures.Remaining("Red") == 2 and Damage.Apply(model, base.humanoid, 100) == 0)
	local profile = Progression.Get(first); assert(profile)
	local kills, deaths, assists, minionKills = profile.TotalKills, profile.TotalDeaths, profile.Assists, profile.TotalMinionKills
	local gold, enemyGold = Economy.GetGold(first), Economy.GetGold(second)
	Config.Range = 28; arrange(first, Vector3.new(0, 36, 0))
	victim = npc("Blue", "Mid", "Melee", position + Vector3.new(0, 0, -12))
	untilTrue(function() return sentry.logic.shot ~= nil end, 3, "No pending shot before destruction")
	before = victim.humanoid.Health
	check("lethal damage confirmed", Damage.Apply(model, sentry.structure.humanoid, 9999) > 0)
	check("bounty committed synchronously with lethal damage", Economy.GetGold(first) == gold + 50)
	task.wait(0.6)
	check("destroyed tower cannot finish shot", sentry.logic.destroyed and sentry.logic.shot == nil and victim.humanoid.Health == before)
	check("team gold awarded once", Economy.GetGold(first) == gold + 50 and Economy.GetGold(second) == enemyGold)
	Damage.Apply(model, sentry.structure.humanoid, 9999); task.wait(0.1)
	check("repeated destruction gives no gold", Economy.GetGold(first) == gold + 50)
	check("no KDA minion reward or life ledger for tower", profile.TotalKills == kills and profile.TotalDeaths == deaths and profile.Assists == assists and profile.TotalMinionKills == minionKills and sentry.structure.model:GetAttribute("LifeId") == nil)
	check("ruin cannot block or be hit", not sentry.structure.root.CanCollide and not sentry.structure.root.CanQuery)
	check("last tower still protects base", Structures.Remaining("Red") == 1 and Damage.Apply(model, base.humanoid, 9999) == 0)
	local bottom = tower("Red", "Bottom"); local minionModel = victim.model
	-- The only connected attacker-team player is temporarily dead; minion last hit must still pay them.
	gold = Economy.GetGold(first); humanoid.Health = 0
	Damage.Apply(minionModel, bottom.structure.humanoid, 9999); task.wait(0.2)
	check("dead connected teammate receives tower gold", Economy.GetGold(first) == gold + 50)
	check("third tower opens base", Structures.Remaining("Red") == 0 and Structures.CanReceive(base.model))
	check("base damage opens for minions", Damage.Apply(minionModel, base.humanoid, 12) == 12)
	untilTrue(function() return first.Character ~= nil and first.Character ~= model end, 12, "Respawn failed")
	task.wait(0.5); model, humanoid, _root = body(first); arrange(first, Vector3.new(0, 36, 0))
	Damage.Apply(model, base.humanoid, 9999)
	untilTrue(function() return state.phase == "Finished" end, 3, "No winner after core destroyed")
	check("tower progression permits match victory", state.winner == "Blue")
	print("[TowerTests] ALL PASS: " .. count .. " integration checks"); workspace:SetAttribute("TowerTestsPassed", count)
	return "passed"
end, function(message) return debug.traceback(tostring(message), 2) end)
Config.Range = 28
if not ok then warn("[TowerTests] FAILED after " .. count .. ": " .. tostring(failure)) end
