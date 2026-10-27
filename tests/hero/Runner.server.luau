--!strict
assert(game:GetService("RunService"):IsStudio())
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match = require(services.MatchService)
local Ability = require(services.AbilityService)
local Clones = require(services.CloneService)
local Appearance = require(services.HeroAppearanceService)
local Fighters = require(services.FighterStateService)
local Combat = require(services.CombatService)
local Damage = require(services.DamageService)
local Stats = require(services.CharacterStatsService)
local Progression = require(services.HeroProgressionService)
local Economy = require(services.EconomyService)
local Rewards = require(services.RewardService)
local Spawner = require(services.MinionSpawnerService)
local AI = require(services.MinionAIService)
local Bases = require(services.BaseService)
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.AbilityConfig)
local RigJoints = require(ReplicatedStorage.Shared.Combat.RigJoints)
local driver = Instance.new("RemoteEvent"); driver.Name = "HeroTestDriver"; driver.Parent = ReplicatedStorage
local responses: { [Player]: { id: number, data: any } } = {}
driver.OnServerEvent:Connect(function(player: Player, id: number, data: any) responses[player] = { id = id, data = data } end)
local count, commandId, requestId, m1Id = 0, 0, 0, 0
local function check(name: string, value: boolean) assert(value, "FAIL: " .. name); count += 1; print("[HeroTests] PASS: " .. name) end
local function untilTrue(predicate: () -> boolean, seconds: number, message: string)
	local deadline = os.clock() + seconds
	repeat if predicate() then return end; task.wait(0.02) until os.clock() >= deadline
	error(message)
end
local function command(player: Player, mode: string, data: any): any
	commandId += 1; local id = commandId; driver:FireClient(player, id, mode, data)
	untilTrue(function() return responses[player] ~= nil and responses[player].id == id end, 10, "No client response: " .. mode)
	return responses[player].data
end
local function body(player: Player): (Model, Humanoid, BasePart)
	local model = player.Character; assert(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid"); local root = model:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and root:IsA("BasePart")); return model, humanoid, root
end
local function arrange(player: Player, position: Vector3)
	local model, humanoid, root = body(player)
	for _, item in model:GetChildren() do if item:IsA("ForceField") or (item:IsA("Script") and item.Name == "Health") then item:Destroy() end end
	root.Anchored = false; root:SetNetworkOwner(nil); root.CFrame = CFrame.new(position)
	root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
	humanoid.AutoRotate = false
end
local function cast(player: Player, id: string): (boolean, string)
	requestId += 1; return Ability.TryCast(player, requestId, player.Character, id)
end
local function realCast(player: Player, id: string, character: Model?, extra: boolean?): any
	requestId += 1
	return command(player, "cast", { n = if extra then 4 else 3, requestId, character or player.Character, id, if extra then 999 else nil })
end
local function attack(player: Player): string m1Id += 1; return Combat.TryAttack(player, m1Id, player.Character) end
local function npc(team: string, position: Vector3): (Model, Humanoid, BasePart)
	local model = Spawner.Spawn(team, "Mid", "Melee", 1); assert(model)
	local record = AI.GetAll()[model]; record.root.CFrame = CFrame.new(position); record.root.Anchored = true
	return model, record.humanoid, record.root
end
local function wall(position: Vector3, size: Vector3): Part
	local part = Instance.new("Part"); part.Name = "HeroTestWall"; part.Anchored = true; part.Size = size; part.Position = position; part.Parent = workspace; return part
end
local function clean()
	Ability.Reset()
	for model in AI.GetAll() do AI.Remove(model) end
	task.wait(0.85) -- Let M1 recovery and token buckets recover; never shorten production timings.
end
local ok, failure = xpcall(function()
	print("[HeroTests] Waiting for 2 clients...")
	untilTrue(function() return #Players:GetPlayers() == 2 and Match.GetState() ~= nil end, 120, "Use Server & Clients -> 2")
	local state = Match.GetState(); assert(state)
	untilTrue(function() return state.phase == "InProgress" end, 30, "Match not started")
	local hero: Player? = nil; local enemy: Player? = nil
	for _, player in Players:GetPlayers() do if player:GetAttribute("TeamId") == "Blue" then hero = player else enemy = player end end
	assert(hero and enemy); local first, second = hero :: Player, enemy :: Player
	untilTrue(function() return first.Character ~= nil and first.Character:GetAttribute("HeroAppearanceVersion") ~= nil and second.Character ~= nil and second.Character:GetAttribute("HeroAppearanceVersion") ~= nil end, 20, "Appearance not ready")
	state.nextWaveAt = workspace:GetServerTimeNow() + 10000; state.startedAt = workspace:GetServerTimeNow() + 10000
	Rewards.Reset(); AI.SetRunning(false); clean()
	Progression.ResetPlayer(first); Progression.ResetPlayer(second)
	arrange(first, Vector3.new(0, 36, 0)); arrange(second, Vector3.new(80, 36, 0))
	local model, humanoid, root = body(first)
	local enemyModel = body(second)
	check("R15 automatically assigned", humanoid.RigType == Enum.HumanoidRigType.R15 and model:GetAttribute("HeroId") == "OrangeNinja")
	local fighter = Fighters.GetOrCreate(model); assert(fighter)
	check("server combat profile snapshot", Fighters.Snapshot(fighter).profileId == "OrangeNinja")
	local appearance = model:FindFirstChild("HeroAppearance"); assert(appearance)
	local details = #appearance:GetChildren(); local joints = #RigJoints.Collect(model)
	Appearance.Apply(model); Appearance.Apply(model)
	appearance = model:FindFirstChild("HeroAppearance"); assert(appearance)
	check("appearance idempotent", #appearance:GetChildren() == details)
	local newJoints, safe = #RigJoints.Collect(model), true
	for _, item in appearance:GetChildren() do if item:IsA("BasePart") then safe = safe and item.Massless and not item.CanCollide and not item.CanQuery and not item.CanTouch end end
	check("cosmetics never change hurtbox", safe)
	check("joints and server Animator preserved", newJoints == joints and joints >= 15 and humanoid:FindFirstChildOfClass("Animator") ~= nil)
	local fixture = Instance.new("Model")
	local lower = Instance.new("Part"); lower.Name = "LowerTorso"; lower.Parent = fixture
	local upper = Instance.new("Part"); upper.Name = "UpperTorso"; upper.Parent = fixture
	local legacy = Instance.new("Motor6D"); legacy.Part0 = lower; legacy.Part1 = upper; legacy.Parent = upper
	local a0 = Instance.new("Attachment"); a0.Parent = lower
	local a1 = Instance.new("Attachment"); a1.Parent = upper
	local modern = Instance.new("AnimationConstraint"); modern.Attachment0 = a0; modern.Attachment1 = a1; modern.Parent = upper
	local collected = RigJoints.Collect(fixture)
	check("modern joints preferred and mapped by body part", #collected == 1 and collected[1].joint == modern and collected[1].key == "Waist")
	modern:Destroy(); collected = RigJoints.Collect(fixture)
	check("legacy joints still supported", #collected == 1 and collected[1].joint == legacy and collected[1].key == "Waist")
	fixture:Destroy()
	local hud = command(first, "hud", {})
	check("hero ability and match HUD exist", hud.hero and hud.abilities and hud.match)
	local pose = command(second, "motion", model)
	check("observer sees appearance and real idle joints", pose.appearance and pose.moved >= 2)
	local prediction = command(first, "prediction", {})
	check("first hero M1 prediction not replayed on profile confirmation", prediction.accepted and prediction.plays == 1)
	m1Id = 100 -- Keep direct server test intents above the first real client's request ID.
	task.wait(1.3)
	for step = 1, 4 do
		check("M1 accepted " .. step, attack(first) == "Started")
		local otherPose = command(second, "motion", model)
		check("observer joints move for M1 " .. step, otherPose.changed > 0)
		task.wait(if step == 4 then 0.85 else 0.36)
	end
	clean(); arrange(first, Vector3.new(0, 36, 0))
	local target, targetHumanoid = npc("Red", Vector3.new(0, 36, -4))
	local _, fartherHumanoid = npc("Red", Vector3.new(1, 36, -5))
	local response = realCast(first, "SpiralSphere")
	check("real client request accepted", response.accepted == true)
	check("ability blocks M1", attack(first) == "Rejected")
	local busy, busyReason = cast(first, "WindPalm")
	check("ability blocks another ability", not busy and busyReason == "Busy")
	local localPose = command(first, "motion", model)
	check("local ability moves joints", localPose.moved >= 2)
	task.wait(0.6)
	check("sphere impacts once for 22", math.abs(targetHumanoid.Health - 78) < 0.001)
	check("sphere selects only nearest target", fartherHumanoid.Health == 100)
	task.wait(0.4); check("sphere does not repeat impact", math.abs(targetHumanoid.Health - 78) < 0.001)
	local cooldown, cooldownReason = cast(first, "SpiralSphere")
	check("server enforces cooldown", not cooldown and cooldownReason == "Cooldown")
	task.wait(0.4)
	local replay, replayReason = Ability.TryCast(first, requestId, model, "SpiralSphere")
	check("replay rejected", not replay and replayReason == "Replay")
	clean(); response = realCast(first, "SpiralSphere", enemyModel)
	check("forged Character rejected", not response.accepted and response.reason == "Malformed")
	task.wait(0.4); response = realCast(first, "SpiralSphere", nil, true)
	check("extra damage argument rejected", not response.accepted and response.reason == "Malformed")
	task.wait(0.4); requestId += 100; local flood = command(first, "flood", requestId); requestId += 100
	check("flood replies throttled", flood.replies <= 2)
	-- Remove transport latency from the token-boundary assertion itself.
	for _ = 1, 30 do requestId += 1; Ability.TryCast(first, requestId, model, "Unknown") end
	local flooded, floodedReason = cast(first, "WindPalm")
	check("flood requests limited", not flooded and floodedReason == "RateLimited")
	task.wait(2)
	check("NaN request rejected", not Ability.TryCast(first, 0 / 0, model, "WindPalm"))
	check("infinite request rejected", not Ability.TryCast(first, math.huge, model, "WindPalm"))
	clean(); arrange(first, Vector3.new(0, 36, 0))
	local _, enteringHumanoid, enteringRoot = npc("Red", Vector3.new(0, 36, -14))
	check("moving contact cast accepted", cast(first, "SpiralSphere")); task.wait(0.42)
	enteringRoot.CFrame = CFrame.new(0, 36, -4); task.wait(0.22)
	check("sphere catches entry during contact window", enteringHumanoid.Health == 78)
	clean(); local _, lateHumanoid, lateRoot = npc("Red", Vector3.new(0, 36, -14))
	cast(first, "SpiralSphere"); task.wait(0.6); lateRoot.CFrame = CFrame.new(0, 36, -4); task.wait(0.3)
	check("sphere cannot hit during recovery", lateHumanoid.Health == 100)
	clean(); arrange(first, Vector3.new(0, 36, 0)); target, targetHumanoid = npc("Red", Vector3.new(0, 36, -4))
	local obstacle = wall(Vector3.new(0, 36, -2), Vector3.new(12, 10, 0.5))
	check("sphere cast near wall accepted", cast(first, "SpiralSphere")); task.wait(0.8)
	check("sphere cannot hit through wall", targetHumanoid.Health == 100)
	obstacle:Destroy(); clean()
	target, targetHumanoid = npc("Blue", Vector3.new(0, 36, -4))
	cast(first, "SpiralSphere"); task.wait(0.8); check("sphere has no allied damage", targetHumanoid.Health == 100)
	clean(); target, targetHumanoid = npc("Red", Vector3.new(0, 36, -4))
	local force = Instance.new("ForceField"); force.Parent = target
	local victimFighter = Fighters.Get(target); assert(victimFighter)
	cast(first, "SpiralSphere"); task.wait(0.5)
	check("zero damage causes no stun", targetHumanoid.Health == 100 and victimFighter.logic.mode == "Idle")
	check("zero damage causes no knockback", victimFighter.root.AssemblyLinearVelocity.Magnitude < 0.001)
	clean(); target, targetHumanoid = npc("Red", Vector3.new(0, 36, -4))
	cast(first, "SpiralSphere"); task.wait(0.1); Fighters.Stun(fighter, 0.5, false)
	check("stun immediately cancels cast", model:GetAttribute("AbilityId") == "")
	check("stunned actor cannot cast", not cast(first, "WindPalm")); task.wait(0.7)
	check("cancelled sphere cannot impact", targetHumanoid.Health == 100)
	local abilityState = Ability.GetState(first); assert(abilityState)
	check("cancelled sphere keeps cooldown", (abilityState.ready.SpiralSphere or 0) > workspace:GetServerTimeNow())
	clean(); check("M1 starts before ability", attack(first) == "Started")
	check("M1 blocks ability", not cast(first, "WindPalm")); task.wait(0.29)
	check("M1 recovery still blocks ability", not cast(first, "WindPalm"))
	clean(); Progression.AddXP(first, 100); Progression.Equip(first, "IronBlade")
	arrange(first, Vector3.new(0, 36, 0)); target, targetHumanoid = npc("Red", Vector3.new(0, 36, -4))
	cast(first, "SpiralSphere"); task.wait(0.8)
	check("level and Blade multiplier applied once", math.abs(targetHumanoid.Health - (100 - 22 * 1.17)) < 0.001)
	clean(); arrange(first, Vector3.new(0, 36, 0)); target, targetHumanoid = npc("Red", Vector3.new(0, 36, -3))
	Clones.Spawn(first, model); task.wait(3.4)
	check("clone level and Blade multiplier applied once", math.abs(targetHumanoid.Health - (100 - 18 * 1.17)) < 0.001)
	clean(); Progression.ResetPlayer(first); arrange(first, Vector3.new(0, 36, 0))
	target, targetHumanoid = npc("Red", Vector3.new(0, 36, -3))
	local minionCount, beforeGold = AI.GetCount(), Economy.GetGold(first)
	check("clone cast accepted", cast(first, "ShadowClones")); task.wait(0.4)
	check("two summons separate from NPC waves", Clones.GetCount() == 2 and AI.GetCount() == minionCount)
	local summonsSafe = true
	for _, clone in Clones.GetAll() do summonsSafe = summonsSafe and clone.model:GetAttribute("EntityKind") == "Summon" and Fighters.Get(clone.model) == nil and Damage.Apply(enemyModel, clone.humanoid, 100) == 0 end
	check("summons invulnerable and not fighters", summonsSafe)
	task.wait(2.8)
	check("two clones at most three hits each", math.abs(targetHumanoid.Health - 82) < 0.001)
	local totalHits = 0; for _, clone in Clones.GetAll() do totalHits += clone.hits end
	check("hit budget exhausted at six", totalHits == 6)
	task.wait(2.2)
	check("summons expire without rewards", Clones.GetCount() == 0 and Economy.GetGold(first) == beforeGold)
	clean(); arrange(first, Vector3.new(0, 36, 0)); target, targetHumanoid = npc("Red", Vector3.new(0, 36, -3)); targetHumanoid.Health = 3
	local profile = Progression.Get(first); assert(profile); local beforeKills = profile.TotalMinionKills
	Clones.Spawn(first, model); task.wait(1.2)
	check("clone damage credits owner's last hit", profile.TotalMinionKills == beforeKills + 1 and Economy.GetGold(first) == beforeGold + 20)
	clean(); arrange(first, Vector3.new(0, 36, 0)); target, targetHumanoid = npc("Red", Vector3.new(0, 36, -3))
	obstacle = wall(Vector3.new(0, 36, -1.5), Vector3.new(16, 10, 0.5)); Clones.Spawn(first, model); task.wait(1.8)
	check("clones cannot strike through wall", targetHumanoid.Health == 100); obstacle:Destroy()
	clean(); local base = Bases.Get("Red"); assert(base)
	-- Preserve the original sphere/base assertion after the new tower prerequisite.
	for _, tower in require(services.TowerService).GetAll() do
		if tower.structure.teamId == "Red" then Damage.Apply(model, tower.structure.humanoid, 9999) end
	end
	task.wait(0.2)
	arrange(first, base.root.Position + Vector3.new(0, 0, 5)); local baseHP = base.humanoid.Health
	Clones.Spawn(first, model); task.wait(1.2); check("clones never attack bases", base.humanoid.Health == baseHP)
	Ability.Reset(); cast(first, "SpiralSphere"); task.wait(0.8)
	check("sphere damages base", base.humanoid.Health == baseHP - 22)
	check("base is never a stunned fighter", Fighters.Get(base.model) == nil)
	clean(); local savedCap = Config.Clones.GlobalLimit; Config.Clones.GlobalLimit = 2
	Clones.Spawn(first, model); Clones.Spawn(second, enemyModel)
	check("global cap enforced across owners", Clones.GetCount() == 2); Config.Clones.GlobalLimit = savedCap
	Clones.Spawn(first, model); check("owner cannot accumulate clones", Clones.GetCount() == 2)
	clean(); arrange(first, Vector3.new(0, 36, 30)); Progression.Equip(first, "SwiftBoots"); Stats.RecalculateStats(first)
	task.wait(0.1); local origin = root.Position
	local _, windFirst = npc("Red", Vector3.new(0, 36, 20))
	local _, windSecond = npc("Red", Vector3.new(1, 36, 19))
	local _, windThird = npc("Red", Vector3.new(-1, 36, 18))
	local _, windFourth = npc("Red", Vector3.new(0, 36, 17))
	check("wind cast accepted", cast(first, "WindPalm")); task.wait(0.7)
	check("wind damages nearest three targets once", windFirst.Health == 86 and windSecond.Health == 86 and windThird.Health == 86 and windFourth.Health == 100)
	check("wind does not dash the owner", ((root.Position - origin) * Vector3.new(1, 0, 1)).Magnitude < 0.75)
	check("wind preserves Boots and autorotate", humanoid.WalkSpeed == 18 and humanoid.AutoRotate == false)
	check("removed dash request rejected", not cast(first, "NinjaDash"))
	clean(); arrange(first, Vector3.new(0, 36, 30)); obstacle = wall(Vector3.new(0, 36, 25), Vector3.new(12, 12, 1))
	local _, blockedWind = npc("Red", Vector3.new(0, 36, 20))
	cast(first, "WindPalm"); task.wait(0.7)
	check("wind cannot hit through wall", blockedWind.Health == 100)
	obstacle:Destroy(); clean(); arrange(first, Vector3.new(0, 36, 30))
	local _, alliedWind = npc("Blue", Vector3.new(0, 36, 20))
	cast(first, "WindPalm"); task.wait(0.7); check("wind has no allied damage", alliedWind.Health == 100)
	clean(); local _, cancelledWind = npc("Red", Vector3.new(0, 36, 20))
	cast(first, "WindPalm"); task.wait(0.05); Fighters.Stun(fighter, 0.5, false)
	task.wait(0.35)
	check("stun cancels wind before impact", cancelledWind.Health == 100)
	check("stun movement lock survives wind cleanup", humanoid.WalkSpeed == 0)
	task.wait(0.3); check("Boots restored after stun", humanoid.WalkSpeed == 18)
	clean(); state.phase = "Preparing"; check("outside InProgress rejected", not cast(first, "ShadowClones")); state.phase = "InProgress"
	model:SetAttribute("CombatDisabled", true)
	check("CombatDisabled rejects actions", not cast(first, "ShadowClones")); model:SetAttribute("CombatDisabled", false)
	model:SetAttribute("HeroId", "Unknown")
	check("server HeroId whitelist enforced", not cast(first, "ShadowClones")); model:SetAttribute("HeroId", "OrangeNinja")
	task.wait(1)
	arrange(first, Vector3.new(0, 36, 0)); target, targetHumanoid = npc("Red", Vector3.new(0, 36, -4))
	Clones.Spawn(first, model); cast(first, "SpiralSphere"); humanoid.Health = 0
	task.wait(0.5)
	check("death cancels impact and clones", targetHumanoid.Health == 100 and Clones.GetCount() == 0)
	check("dead player cannot cast", not cast(first, "WindPalm"))
	untilTrue(function() return first.Character ~= nil and first.Character ~= model and first.Character:GetAttribute("HeroAppearanceVersion") ~= nil end, 12, "Hero respawn failed")
	local oldModel = model; model, humanoid, root = body(first); fighter = Fighters.GetOrCreate(model); assert(fighter)
	check("respawn appearance and Boots preserved", model:FindFirstChild("HeroAppearance") ~= nil and humanoid.WalkSpeed == 18)
	requestId += 1; check("old Character request rejected", not Ability.TryCast(first, requestId, oldModel, "ShadowClones"))
	check("old life did not damage later", targetHumanoid.Health == 100)
	clean(); Clones.Spawn(first, model); Damage.Apply(model, base.humanoid, 10000)
	untilTrue(function() return state.phase == "Finished" and Clones.GetCount() == 0 end, 3, "Finish did not clear summons")
	check("finished match rejects abilities", not cast(first, "ShadowClones"))
	check("eliminated team rejects abilities", not cast(second, "WindPalm"))
	Match.ResetProgression(); local resetState = Ability.GetState(first); assert(resetState)
	check("match reset clears cooldowns", next(resetState.ready) == nil)
	second:Kick("Hero test: cleanup")
	untilTrue(function() return Ability.GetState(second) == nil end, 5, "Ability session leaked after leave")
	check("departure clears ability session", Ability.GetState(second) == nil)
	print("[HeroTests] ALL PASS: " .. count .. " integration checks")
	workspace:SetAttribute("HeroTestsPassed", count)
	return "passed"
end, function(message) return debug.traceback(tostring(message), 2) end)
if not ok then warn("[HeroTests] FAILED after " .. count .. ": " .. tostring(failure)) end
