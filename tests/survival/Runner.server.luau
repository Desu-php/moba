--!strict
assert(game:GetService("RunService"):IsStudio(), "Studio-only test")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match = require(services.MatchService)
local Teams = require(services.TeamService)
local Bases = require(services.BaseService)
local AI = require(services.MinionAIService)
local Spawner = require(services.MinionSpawnerService)
local Builder = require(services.MapBuilder)
local Damage = require(services.DamageService)
local Fighters = require(services.FighterStateService)
local MinionConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.MinionConfig)
local driver = Instance.new("RemoteEvent"); driver.Name = "SurvivalTestDriver"; driver.Parent = ReplicatedStorage
local replies: { [Player]: { id: number, data: any } } = {}
driver.OnServerEvent:Connect(function(player: Player, id: number, data: any) replies[player] = { id = id, data = data } end)
local count, serial = 0, 0
local function check(name: string, value: boolean)
	assert(value, "FAIL: " .. name); count += 1; print("[SurvivalTests] PASS: " .. name)
end
local function untilTrue(predicate: () -> boolean, duration: number, message: string)
	local deadline = os.clock() + duration
	repeat if predicate() then return end; task.wait(0.03) until os.clock() >= deadline
	error(message)
end
local function command(player: Player, mode: string): any
	serial += 1; local id = serial; driver:FireClient(player, id, mode)
	untilTrue(function() return replies[player] ~= nil and replies[player].id == id end, 8, "No client reply")
	return replies[player].data
end
local function body(player: Player): (Model, Humanoid, BasePart)
	local model = player.Character; assert(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid"); local root = model:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and root:IsA("BasePart")); return model, humanoid, root
end
local function clearNPCs()
	local list = {}; for model in AI.GetAll() do table.insert(list, model) end
	for _, model in list do AI.Remove(model) end
end
local function arrange(player: Player, position: Vector3, target: Vector3)
	local model, humanoid, root = body(player)
	for _, item in model:GetChildren() do if item:IsA("ForceField") or (item:IsA("Script") and item.Name == "Health") then item:Destroy() end end
	humanoid.Health = 100; humanoid.AutoRotate = false
	root:SetNetworkOwner(nil); root.AssemblyLinearVelocity = Vector3.zero; root.CFrame = CFrame.lookAt(position, target)
end
local ok, failure = xpcall(function()
	print("[SurvivalTests] Waiting for two clients...")
	untilTrue(function() return Match.GetState() ~= nil and #Players:GetPlayers() >= 2 end, 120, "Start Server & Clients with 2")
	local state = Match.GetState(); assert(state)
	untilTrue(function() return state.phase == "InProgress" end, 30, "Match did not start")
	local blue: Player? = nil; local red: Player? = nil
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("TeamId") == "Blue" then blue = player else red = player end
	end
	assert(blue and red)
	local bluePlayer: Player = blue; local redPlayer: Player = red
	untilTrue(function() return bluePlayer.Character ~= nil and redPlayer.Character ~= nil end, 20, "Heroes missing")
	local map = workspace:FindFirstChild("Map") :: Folder
	local original = map
	check("map build is idempotent", Builder.Build() == original)
	check("user objects and Baseplate preserved", workspace:FindFirstChild("Baseplate") ~= nil and workspace:FindFirstChild("UserObject") ~= nil)
	check("two 1500 HP bases", (Bases.Get("Blue") :: Bases.Base).humanoid.Health == 1500 and (Bases.Get("Red") :: Bases.Base).humanoid.Health == 1500)
	local lanes = map:FindFirstChild("Lanes"); assert(lanes)
	check("three lanes", #lanes:GetChildren() == 3)
	for _, lane in { "Top", "Mid", "Bottom" } do
		local forward = Builder.Route(map, lane, false); local reverse = Builder.Route(map, lane, true)
		check(lane .. " mirrored routes", forward[1] == reverse[#reverse] and #forward >= 2)
	end
	local _, _, blueRoot = body(bluePlayer); local _, _, redRoot = body(redPlayer)
	check("team specific spawn", blueRoot.Position.X < -140 and redRoot.Position.X > 140)
	check("HUD on both clients", command(bluePlayer, "stats").hud and command(redPlayer, "stats").hud)
	check("no early first wave", state.wave == 0)
	untilTrue(function() return state.wave == 1 end, 8, "First wave missing")
	check("first wave has 18 minions", AI.GetCount() == 18)
	local groups: { [string]: { [string]: number } } = {}
	local starts: { [Model]: Vector3 } = {}
	for model, npc in AI.GetAll() do
		local key = npc.teamId .. npc.lane
		if not groups[key] then groups[key] = { Melee = 0, Ranged = 0 } end
		groups[key][npc.kind] += 1; starts[model] = npc.root.Position
	end
	local compositions = true
	for _, group in groups do if group.Melee ~= 2 or group.Ranged ~= 1 then compositions = false end end
	check("two melee and one ranged per lane and side", compositions)
	local combatLanes: { [string]: boolean } = {}
	local shotConnection = AI.Shot.Event:Connect(function(_: Vector3, _target: Vector3, _kind: string, _team: string, target: Model)
		local lane = target:GetAttribute("Lane"); if typeof(lane) == "string" then combatLanes[lane] = true end
	end)
	task.wait(3)
	local moving = 0
	for model, position in starts do local npc = AI.GetAll()[model]; if npc and (npc.root.Position - position).Magnitude > 10 then moving += 1 end end
	check("all minions move along routes", moving == 18)
	untilTrue(function() return state.wave >= 2 end, 22, "Second wave missing")
	check("second wave after twenty seconds", workspace:GetServerTimeNow() - state.startedAt >= 25)
	untilTrue(function() return combatLanes.Top == true and combatLanes.Mid == true and combatLanes.Bottom == true end, 30, "Waves did not fight on all three lanes")
	check("opposing waves fight on every lane", true); shotConnection:Disconnect()
	state.nextWaveAt = workspace:GetServerTimeNow() + 1000
	clearNPCs()
	check("despawn frees registry", AI.GetCount() == 0)
	local enemy = Spawner.Spawn("Red", "Mid", "Melee", 2); assert(enemy)
	local npc = AI.GetAll()[enemy]; npc.root.CFrame = CFrame.new(0, 36, -3.5); npc.root.Anchored = true; npc.nextAttack = math.huge
	arrange(bluePlayer, Vector3.new(0, 36, 0), Vector3.new(0, 36, -4))
	task.wait(1.3); command(bluePlayer, "combo")
	check("hero M1 combo deals 27 to enemy NPC", npc.humanoid.Health == 73)
	check("finisher resets NPC combo", (Fighters.Get(enemy) :: Fighters.Fighter).logic.comboStep == 0)
	local blueModel = bluePlayer.Character :: Model
	local lethal = Damage.Apply(blueModel, npc.humanoid, 100)
	check("shared damage can kill enemy NPC (dealt=" .. lethal .. ", health=" .. npc.humanoid.Health .. ")", lethal == 73 and npc.humanoid.Health == 0)
	task.wait(MinionConfig.CorpseLifetime + 0.3)
	check("dead NPC destroyed and state removed", enemy.Parent == nil and Fighters.Get(enemy) == nil)
	local ally = Spawner.Spawn("Blue", "Mid", "Melee", 2); assert(ally)
	local allied = AI.GetAll()[ally]; allied.root.CFrame = CFrame.new(0, 36, -3.5); allied.root.Anchored = true; allied.nextAttack = math.huge
	task.wait(1.3); command(bluePlayer, "attack")
	check("M1 friendly fire blocked", allied.humanoid.Health == 100)
	check("friendly base damage blocked", Damage.Apply(blueModel, (Bases.Get("Blue") :: Bases.Base).humanoid, 100) == 0)
	clearNPCs()
	local killer = Spawner.Spawn("Red", "Mid", "Melee", 2); assert(killer)
	local killerNPC = AI.GetAll()[killer]; killerNPC.root.CFrame = CFrame.new(0, 36, -3.5)
	local oldModel, heroHumanoid = body(bluePlayer); heroHumanoid.Health = 8
	untilTrue(function() return heroHumanoid.Health == 0 end, 5, "NPC did not kill hero")
	check("NPC can kill hero", true); clearNPCs()
	untilTrue(function() return bluePlayer.Character ~= nil and bluePlayer.Character ~= oldModel end, 12, "Hero did not respawn")
	task.wait(0.5)
	local _, newHumanoid, newRoot = body(bluePlayer)
	check("hero respawns at living base", newHumanoid.Health > 0 and newRoot.Position.X < -140 and Teams.IsActive("Blue"))
	local base = Bases.Get("Red") :: Bases.Base
	arrange(bluePlayer, base.root.Position + Vector3.new(-4.5, 0, 0), base.root.Position)
	task.wait(1.3); local before = base.humanoid.Health; command(bluePlayer, "attack")
	check("hero M1 damages enemy base", base.humanoid.Health == before - 5)
	local siege = Spawner.Spawn("Blue", "Mid", "Ranged", 2); assert(siege)
	local siegeNPC = AI.GetAll()[siege]; siegeNPC.root.CFrame = CFrame.new(base.root.Position + Vector3.new(-12, 0, 0))
	before = base.humanoid.Health
	untilTrue(function() return base.humanoid.Health < before end, 4, "Ranged NPC did not hit base")
	check("ranged NPC attacks enemy structure", true)
	clearNPCs()
	local pursuer = Spawner.Spawn("Blue", "Mid", "Melee", 2); assert(pursuer)
	local defeated = Spawner.Spawn("Red", "Mid", "Melee", 2); assert(defeated)
	local advancing, defender = AI.GetAll()[pursuer], AI.GetAll()[defeated]
	advancing.root.CFrame = CFrame.new(-4, 36, 0); advancing.waypoint = 3
	defender.root.CFrame = CFrame.new(0, 36, 0); defender.root.Anchored = true
	defender.humanoid.Health = 8; defender.nextAttack = math.huge
	check("NPC friendly hero damage blocked", Damage.Apply(pursuer, newHumanoid, 8) == 0)
	untilTrue(function() return defender.humanoid.Health == 0 end, 5, "Minion failed to defeat target")
	untilTrue(function() return advancing.root.Position.X > 10 and advancing.mode == "Moving" end, 6, "Minion did not resume route after kill")
	check("minion resumes route after defeating enemy", true)
	clearNPCs()
	local stuck = Spawner.Spawn("Blue", "Mid", "Melee", 2); assert(stuck)
	local stuckNPC = AI.GetAll()[stuck]; stuckNPC.root.Anchored = true
	untilTrue(function() return stuck.Parent == nil end, (MinionConfig.MaxRecoveryAttempts + 2) * MinionConfig.StuckTime, "Stuck NPC never despawned")
	check("stuck recovery has finite retries and cleanup", AI.GetAll()[stuck] == nil)
	-- Natural route traversal to a base with opposition removed.
	local walker = Spawner.Spawn("Blue", "Mid", "Melee", 2); assert(walker)
	before = base.humanoid.Health
	untilTrue(function() return base.humanoid.Health < before end, 40, "Unopposed minion failed to reach base")
	check("minion traverses full route and attacks base", true)
	clearNPCs()
	for _ = 1, 10 do Spawner.Wave(state.wave + 1) end
	check("global NPC cap enforced", AI.GetCount() == MinionConfig.MaxActiveNPCs)
	local redCharacter = redPlayer.Character :: Model
	local destroyed = 0
	local destroyConnection = Bases.Destroyed.Event:Connect(function() destroyed += 1 end)
	Damage.Apply(bluePlayer.Character :: Model, base.humanoid, 2000)
	untilTrue(function() return state.phase == "Finished" end, 2, "No winner")
	check("last active team wins", state.winner == "Blue" and not Teams.IsActive("Red"))
	local redCount = 0; for _, record in AI.GetAll() do if record.teamId == "Red" then redCount += 1 end end
	check("eliminated minions removed", redCount == 0)
	check("eliminated hero removed from combat", (redCharacter:FindFirstChildOfClass("Humanoid") :: Humanoid).Health == 0)
	check("repeated destruction ignored", Damage.Apply(bluePlayer.Character :: Model, base.humanoid, 2000) == 0 and destroyed == 1)
	local finalCount, finalWave = AI.GetCount(), state.wave
	Spawner.Wave(100); task.wait(5)
	check("finished match cannot spawn waves or respawn eliminated hero", AI.GetCount() == finalCount and state.wave == finalWave and redPlayer.Character == redCharacter)
	check("combat disabled after finish", not Damage.CanAct(bluePlayer.Character :: Model))
	local client = command(bluePlayer, "stats")
	check("winner replicated to HUD", client.phase == "Finished" and client.winner == "Blue")
	destroyConnection:Disconnect()
	print("[SurvivalTests] ALL PASS: " .. count .. " integration checks")
	workspace:SetAttribute("SurvivalTestsPassed", count)
	return "passed"
end, function(message) return debug.traceback(tostring(message), 2) end)
if not ok then warn("[SurvivalTests] FAILED after " .. count .. ": " .. tostring(failure)) end
