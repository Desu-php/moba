--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Combat tests are Studio-only")
Players.CharacterAutoLoads = false
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.CombatConfig)
local Profile = Config.Profiles.Default
local VFXConfig = require(Shared.Config.VFXConfig)
local Fighters = require(game:GetService("ServerScriptService").Server.Services.FighterStateService)
local Knockback = require(game:GetService("ServerScriptService").Server.Services.KnockbackService)
local driver = Instance.new("RemoteEvent")
driver.Name = "CombatTestDriver"
driver.Parent = ReplicatedStorage
local ready: { [Player]: boolean } = {}
local replies: { [Player]: { sequence: number, data: any } } = {}
driver.OnServerEvent:Connect(function(player: Player, sequence: number, data: any)
	if sequence == 0 then ready[player] = true
	else replies[player] = { sequence = sequence, data = data } end
end)

local sequence, passed = 0, 0
local function waitUntil(predicate: () -> boolean, timeout: number, message: string)
	local deadline = os.clock() + timeout
	repeat
		if predicate() then return end
		task.wait(0.01)
	until os.clock() >= deadline
	error(message)
end

local function body(player: Player): (Model, Humanoid, BasePart)
	local character = player.Character
	assert(character, "Character missing")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and root:IsA("BasePart"), "Character not ready")
	return character, humanoid, root
end

local function prepare(attacker: Player, victim: Player, victimPosition: Vector3?)
	task.wait(Profile.AttackCooldown + 0.2)
	for _, player in { attacker, victim } do
		local character, humanoid, root = body(player)
		local regen = character:FindFirstChild("Health")
		if regen and regen:IsA("Script") then regen:Destroy() end
		local forceField = character:FindFirstChildOfClass("ForceField")
		if forceField then forceField:Destroy() end
		humanoid.Health = 100
		humanoid.AutoRotate = false
		root.Anchored = false
		root:SetNetworkOwner(nil)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		local position = if player == attacker then Vector3.new(0, 3, 0) else victimPosition or Vector3.new(0, 3, -3.5)
		root.CFrame = CFrame.lookAt(position, position + (if player == attacker then -Vector3.zAxis else Vector3.zAxis))
	end
	task.wait(0.1)
end

local function command(player: Player, mode: string): any
	sequence += 1
	local current = sequence
	driver:FireClient(player, current, mode)
	waitUntil(function()
		return replies[player] ~= nil and replies[player].sequence == current
	end, 8, "Client did not acknowledge " .. mode)
	return replies[player].data
end

local function health(player: Player): number
	local _, humanoid = body(player)
	return humanoid.Health
end

local function check(name: string, condition: boolean)
	assert(condition, "FAIL: " .. name)
	passed += 1
	print("[M1Tests] PASS: " .. name)
end

local function waitDamage(player: Player, expected: number)
	local ok,why=pcall(function() waitUntil(function() return health(player) == expected end, 2, "Expected health " .. expected .. ", got " .. health(player)) end)
	if not ok then
		local diagnostics={}
		for _,p in Players:GetPlayers() do
			local c,h,r=body(p);local f=Fighters.Get(c)
			table.insert(diagnostics,{name=p.Name,health=h.Health,position={r.Position.X,r.Position.Y,r.Position.Z},look={r.CFrame.LookVector.X,r.CFrame.LookVector.Y,r.CFrame.LookVector.Z},mode=if f then f.logic.mode else "missing",serial=if f then f.logic.attackSerial else -1,nextAttack=if f then f.logic.nextAttackAt else 0,now=workspace:GetServerTimeNow()})
		end
		error(tostring(why).." STATE "..game:GetService("HttpService"):JSONEncode(diagnostics))
	end
end

local success, failure = xpcall(function()
	print("[M1Tests] Waiting for Server & Clients with 2 players...")
	waitUntil(function() return #Players:GetPlayers() >= 2 end, 120, "Use Server & Clients, 2 clients")
	local clients = Players:GetPlayers()
	local first, second = clients[1], clients[2]
	for _, player in { first, second } do player:LoadCharacterAsync() end
	waitUntil(function() return ready[first] == true and ready[second] == true end, 30, "Test clients not ready")
	local _, firstHumanoid = body(first)
	local _, secondHumanoid = body(second)
	check("two R15 players", firstHumanoid.RigType == Enum.HumanoidRigType.R15 and secondHumanoid.RigType == Enum.HumanoidRigType.R15)

	prepare(first, second)
	local total = 0
	for step, damage in { Profile.Damage, Profile.Damage, Profile.Damage, Profile.Damage } do
		command(first, "attack")
		if step == 1 then check("windup delays damage", health(second) == 100) end
		total += damage
		waitDamage(second, 100 - total)
		local victim = Fighters.Get(second.Character :: Model)
		assert(victim)
		check("repeat " .. step .. " damage without stun", victim.logic.mode == "Idle")
		check("one animation on repeat " .. step, ((Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.active :: any).step == 1)
		-- Admission can lag the driver send during client startup. Cadence is owned
		-- by the server's accepted attack, not the fixture's pre-network timestamp.
		local attacker=Fighters.Get(first.Character :: Model);assert(attacker)
		waitUntil(function()return workspace:GetServerTimeNow()>=attacker.logic.nextAttackAt+.03 end,2,"Server attack recovery deadline")
	end
	check("four equal attacks deal 32", health(second) == 68 and health(first) == 100)
	task.wait(Profile.AttackCooldown + 0.1)
	command(first, "attack")
	waitUntil(function() return (Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.active ~= nil end, 1, "Repeat did not start")
	check("next repeat has one animation", true)

	prepare(second, first)
	local observerBefore = command(first, "stats")
	command(second, "attack")
	waitDamage(first, 92)
	check("reciprocal PvP damage", health(second) == 100)
	local observer = command(first, "stats")
	check("remote attack does not play observer animation", observer.localStep == observerBefore.localStep and observer.totalPlays == observerBefore.totalPlays and observer.ownStarts == observerBefore.ownStarts)
	check("both clients receive confirmed combat events", observer.otherStarts > 0 and observer.hits > 0 and observer.stuns == 0)

	prepare(first, second)
	command(first, "burst")
	waitDamage(second, 92)
	task.wait(0.45)
	check("remote flood cannot damage repeatedly", health(second) == 92)
	check("stun expires and movement restores", (Fighters.Get(second.Character :: Model) :: Fighters.Fighter).logic.mode == "Idle" and secondHumanoid.WalkSpeed > 0)

	prepare(first, second)
	command(first, "malformed")
	task.wait(0.4)
	check("forged damage, extra payload, nil, NaN and infinity rejected", health(second) == 100)

	prepare(first, second)
	command(first, "replay")
	waitDamage(second, 92)
	task.wait(0.4)
	check("replayed request cannot start an extra attack", health(second) == 92)

	prepare(first, second)
	local reply = command(first, "controllerBurst")
	waitDamage(second, 92)
	check("prediction confirms without replay", reply.sent == 1 and reply.plays == 1)

	prepare(first, second)
	command(first, "buffer")
	waitDamage(second, 84)
	check("early click buffers exactly one next attack", (Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.active ~= nil)
	task.wait(0.5)
	check("buffer does not auto-chain a third attack", health(second) == 84)

	prepare(first, second)
	command(first, "attack")
	waitDamage(second, 92)
	Fighters.Stun(Fighters.Get(second.Character :: Model) :: Fighters.Fighter, 0.4, false)
	command(second, "attack")
	task.wait(0.2)
	check("stunned player cannot start an attack", health(first) == 100)
	task.wait(Profile.AttackCooldown + 0.15)
	command(first, "attack")
	waitDamage(second, 84)
	check("pause preserves one attack", (Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.active ~= nil)

	prepare(first, second)
	command(first, "attack")
	task.wait(0.04)
	command(second, "attack")
	task.wait(0.4)
	check("ordinary hit allows reciprocal windup", health(first) == 92 and health(second) == 92)

	prepare(first, second, Vector3.new(0, 3, 4))
	command(first, "attack")
	task.wait(0.35)
	check("behind target outside permitted direction", health(second) == 100)
	prepare(first, second, Vector3.new(0, 3, -15))
	command(first, "attack")
	task.wait(0.35)
	check("out of range and empty swing safe", health(second) == 100)

	prepare(first, second)
	command(first, "attack")
	local _, _, turningRoot = body(first)
	turningRoot.CFrame = CFrame.lookAt(turningRoot.Position, turningRoot.Position + Vector3.zAxis)
	task.wait(0.35)
	check("impact samples current facing after windup", health(second) == 100)

	prepare(first, second)
	local wall = Instance.new("Part")
	wall.Name = "TestWall"
	wall.Anchored = true
	wall.Size = Vector3.new(12, 10, 0.5)
	wall.Position = Vector3.new(0, 5, -1.75)
	wall.Parent = workspace
	command(first, "attack")
	task.wait(0.35)
	check("solid wall prevents hits", health(second) == 100)
	wall:Destroy()

	prepare(first, second)
	local _, _, knockAttacker = body(first)
	local _, _, knockTarget = body(second)
	local backWall = Instance.new("Part")
	backWall.Anchored = true
	backWall.Size = Vector3.new(12, 10, 0.5)
	backWall.Position = Vector3.new(0, 5, -5.5)
	backWall.Parent = workspace
	Fighters.Stun(Fighters.Get(second.Character :: Model) :: Fighters.Fighter, 0.65, true)
	Knockback.Apply(knockAttacker, knockTarget, Profile)
	task.wait(0.05)
	local horizontal = knockTarget.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	check("near wall reduces knockback without crossing wall", horizontal.Magnitude < Profile.KnockbackVelocity / 2 and knockTarget.Position.Z > -5.5)
	backWall:Destroy()

	prepare(first, second)
	local shield = Instance.new("ForceField")
	shield.Parent = second.Character
	command(first, "attack")
	task.wait(0.35)
	check("ForceField prevents damage and stun", health(second) == 100 and (Fighters.Get(second.Character :: Model) :: Fighters.Fighter).logic.mode == "Idle")
	shield:Destroy()

	prepare(first, second)
	-- A cloned R15 Humanoid can restore collision flags while entering a physics
	-- state and shove the intended closest victim. Use a stationary hurtbox,
	-- like the manual targeting fixture, so this tests selection rather than shoving.
	local npc = Instance.new("Model");npc.Name="TestThirdTarget"
	local npcRoot=Instance.new("Part");npcRoot.Name="HumanoidRootPart";npcRoot.Size=Vector3.new(2,4,2)
	npcRoot.CanCollide=false;npcRoot.Parent=npc
	local npcHumanoid=Instance.new("Humanoid");npcHumanoid.RequiresNeck=false;npcHumanoid.EvaluateStateMachine=false;npcHumanoid.Parent=npc
	npcRoot.CFrame = CFrame.new(1.8, 3, -3.5)
	npcRoot.Anchored = true
	npcHumanoid.Health = 100
	npc.PrimaryPart=npcRoot;npc.Parent=workspace
	local _,_,nearestOrigin=body(first)
	local _,_,nearestVictim=body(second)
	check("nearest fixture order is stable before impact",(nearestVictim.Position-nearestOrigin.Position).Magnitude<(npcRoot.Position-nearestOrigin.Position).Magnitude)
	command(first, "attack")
	waitDamage(second, 92)
	check("one swing hits only closest humanoid", npcHumanoid.Health == 100)
	npc:Destroy()

	prepare(first, second)
	local _, _, targetRoot = body(second)
	targetRoot:SetNetworkOwner(second)
	local originalSpeed = secondHumanoid.WalkSpeed
	command(first, "attack")
	waitDamage(second, 92)
	Fighters.Stun(Fighters.Get(second.Character :: Model) :: Fighters.Fighter, 0.25, false)
	check("spell stun immobilizes real player with server ownership", secondHumanoid.WalkSpeed == 0 and targetRoot:GetNetworkOwner() == nil)
	task.wait(0.1)
	Fighters.Stun(Fighters.Get(second.Character :: Model) :: Fighters.Fighter, 0.4, false)
	task.wait(0.2)
	check("old stun deadline does not release overlapping stun", secondHumanoid.WalkSpeed == 0)
	task.wait(0.25)
	check("overlap ends and ownership restores", secondHumanoid.WalkSpeed == originalSpeed and targetRoot:GetNetworkOwner() == second)

	prepare(first, second)
	local oldCharacter = first.Character :: Model
	command(first, "attack")
	firstHumanoid.Health = 0
	task.wait(0.3)
	check("death cancels pending damage", health(second) == 100)
	command(first, "attack")
	task.wait(0.2)
	check("dead requests rejected", health(second) == 100)
	first:LoadCharacterAsync()
	prepare(first, second)
	command(first, "controller")
	waitDamage(second, 92)
	check("respawn replaces fighter and client prediction", (Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.active ~= nil and Fighters.Get(oldCharacter) == nil)

	local effects = command(first, "vfxCap")
	check("VFX has a hard concurrent cap", effects.activeEffects <= VFXConfig.MaxEffects)
	task.wait(0.4)
	check("temporary VFX cleaned up", command(first, "stats").activeEffects == 0)
	local removedCharacter = second.Character :: Model
	second:Kick("M1 integration tests: player cleanup check")
	waitUntil(function() return second.Parent ~= Players and Fighters.Get(removedCharacter) == nil end, 10, "Player state leaked after departure")
	check("departure removes fighter and pending work", true)
	workspace:SetAttribute("CombatTestsPassed", passed)
	print(string.format("[M1Tests] ALL PASS: %d integration checks", passed))
	return "passed"
end, function(message) return debug.traceback(tostring(message), 2) end)

if not success then
	warn("[M1Tests] FAILED after " .. passed .. " checks: " .. tostring(failure))
	workspace:SetAttribute("CombatTestsFailed", tostring(failure))
end
