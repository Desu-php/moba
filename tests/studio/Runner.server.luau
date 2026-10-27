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
	task.wait(Profile.ComboResetTime + 0.2)
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
	waitUntil(function() return health(player) == expected end, 2, "Expected health " .. expected .. ", got " .. health(player))
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
	for step, damage in Profile.DamageByComboStep do
		local startedAt = os.clock()
		command(first, "attack")
		if step == 1 then check("windup delays damage", health(second) == 100) end
		total += damage
		waitDamage(second, 100 - total)
		local victim = Fighters.Get(second.Character :: Model)
		assert(victim)
		check("step " .. step .. " damage and stun", victim.logic.mode == "Stunned")
		check("attacker combo step " .. step, (Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.comboStep == step)
		if step < 4 then
			task.wait(math.max(0, Profile.AttackCooldown + 0.05 - (os.clock() - startedAt)))
		else
			local _, _, root = body(second)
			check("finisher has bounded server knockback", root.AssemblyLinearVelocity.Magnitude > 10 and root.AssemblyLinearVelocity.Magnitude < Profile.MaxKnockbackSpeed + 5)
			check("finisher resets victim combo", victim.logic.comboStep == 0)
			check("finisher owns victim physics on server", root:GetNetworkOwner() == nil)
		end
	end
	check("complete combo damage 27", health(second) == 73 and health(first) == 100)
	task.wait(Profile.FinisherCooldown + 0.1)
	command(first, "attack")
	waitUntil(function() return (Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.comboStep == 1 end, 1, "Finisher did not reset")
	check("next combo starts at step 1", true)

	prepare(second, first)
	local observerBefore = command(first, "stats")
	command(second, "attack")
	waitDamage(first, 95)
	check("reciprocal PvP damage", health(second) == 100)
	local observer = command(first, "stats")
	check("remote attack does not advance observer combo", observer.localStep == observerBefore.localStep and observer.totalPlays == observerBefore.totalPlays and observer.ownStarts == observerBefore.ownStarts)
	check("both clients receive confirmed combat events", observer.otherStarts > 0 and observer.hits > 0 and observer.stuns > 0)

	prepare(first, second)
	command(first, "burst")
	waitDamage(second, 95)
	task.wait(0.45)
	check("remote flood cannot skip steps or damage repeatedly", health(second) == 95 and (Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.comboStep == 1)
	check("stun expires and movement restores", (Fighters.Get(second.Character :: Model) :: Fighters.Fighter).logic.mode == "Idle" and secondHumanoid.WalkSpeed > 0)

	prepare(first, second)
	command(first, "malformed")
	task.wait(0.4)
	check("forged damage, extra payload, nil, NaN and infinity rejected", health(second) == 100)

	prepare(first, second)
	command(first, "replay")
	waitDamage(second, 95)
	task.wait(0.4)
	check("replayed request cannot start an extra attack", health(second) == 95)

	prepare(first, second)
	local reply = command(first, "controllerBurst")
	waitDamage(second, 95)
	check("prediction confirms without replay", reply.sent == 1 and reply.plays == 1)

	prepare(first, second)
	command(first, "buffer")
	waitDamage(second, 90)
	check("early click buffers exactly one next attack", (Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.comboStep == 2)
	task.wait(0.5)
	check("buffer does not auto-chain a third attack", health(second) == 90)

	prepare(first, second)
	command(first, "attack")
	waitDamage(second, 95)
	command(second, "attack")
	task.wait(0.16)
	check("stunned player cannot start an attack", health(first) == 100)
	task.wait(Profile.ComboResetTime + 0.15)
	command(first, "attack")
	waitDamage(second, 90)
	check("pause restarts at first damage step", (Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.comboStep == 1)

	prepare(first, second)
	command(first, "attack")
	task.wait(0.04)
	command(second, "attack")
	task.wait(0.4)
	check("first impact interrupts victim windup", health(first) == 100 and health(second) == 95)

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
	Fighters.Stun(Fighters.Get(second.Character :: Model) :: Fighters.Fighter, Profile.FinisherStunDuration, true)
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
	local character = second.Character :: Model
	character.Archivable = true
	local npc = character:Clone()
	npc.Name = "TestThirdTarget"
	npc.Parent = workspace
	for _, descendant in npc:GetDescendants() do
		if descendant:IsA("BaseScript") then descendant:Destroy() end
	end
	local npcRoot = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	local npcHumanoid = npc:FindFirstChildOfClass("Humanoid") :: Humanoid
	npcRoot.CFrame = CFrame.new(1.8, 3, -3.5)
	npcRoot.Anchored = true
	npcHumanoid.Health = 100
	command(first, "attack")
	waitDamage(second, 95)
	check("one swing hits multiple unique humanoids", npcHumanoid.Health == 95)
	npc:Destroy()

	prepare(first, second)
	local _, _, targetRoot = body(second)
	targetRoot:SetNetworkOwner(second)
	local originalSpeed = secondHumanoid.WalkSpeed
	command(first, "attack")
	waitDamage(second, 95)
	check("stun immobilizes real player with server ownership", secondHumanoid.WalkSpeed == 0 and targetRoot:GetNetworkOwner() == nil)
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
	waitDamage(second, 95)
	check("respawn resets combo and client prediction", (Fighters.Get(first.Character :: Model) :: Fighters.Fighter).logic.comboStep == 1 and Fighters.Get(oldCharacter) == nil)

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
