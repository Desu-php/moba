--!strict
assert(game:GetService("RunService"):IsStudio())
local Players = game:GetService("Players")
local Storage = game:GetService("ReplicatedStorage")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match = require(Services.MatchService)
local Teams = require(Services.TeamService)
local Towers = require(Services.TowerService)
local Bases = require(Services.BaseService)
local Structures = require(Services.StructureService)
local Damage = require(Services.DamageService)
local Combat = require(Services.CombatService)
local Ability = require(Services.AbilityService)
local Clones = require(Services.NarutoSummonService)
local Spawner = require(Services.MinionSpawnerService)
local AI = require(Services.MinionAIService)
local Progression = require(Services.HeroProgressionService)
local Economy = require(Services.EconomyService)
local Shop = require(Services.ItemShopService)
local Rewards = require(Services.RewardService)
local driver = Instance.new("RemoteEvent"); driver.Name = "RoundTestDriver"; driver.Parent = Storage
local responses: { [Player]: { id: number, data: any } } = {}
driver.OnServerEvent:Connect(function(player: Player, id: number, data: any) responses[player] = { id = id, data = data } end)
local count, commandId, finishes = 0, 0, 0
local function check(name: string, value: boolean)
	assert(value, "FAIL: " .. name); count += 1; print("[RoundTests] PASS: " .. name)
end
local function untilTrue(predicate: () -> boolean, seconds: number, message: string)
	local deadline = os.clock() + seconds
	repeat if predicate() then return end; task.wait(0.03) until os.clock() >= deadline
	error(message)
end
local function command(player: Player, mode: string, data: any?): any
	commandId += 1; local id = commandId; driver:FireClient(player, id, mode, data)
	untilTrue(function() return responses[player] ~= nil and responses[player].id == id end, 8, "No client response: " .. mode)
	return responses[player].data
end
local function body(player: Player): (Model, Humanoid, BasePart)
	local model = player.Character; assert(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid"); local root = model:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and root:IsA("BasePart")); return model, humanoid, root
end
local function arrange(player: Player, position: Vector3)
	local model, _, root = body(player)
	for _, child in model:GetChildren() do if child:IsA("ForceField") then child:Destroy() end end
	root.Anchored = false; root:SetNetworkOwner(nil); root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(position)
end
local function connections(): number
	local total = 0
	for _, tower in Towers.GetAll() do total += #tower.connections end
	return total
end
local ok, failure = xpcall(function()
	print("[RoundTests] Waiting for 2 clients; single-match terminal policy...")
	untilTrue(function() return #Players:GetPlayers() == 2 and Match.GetState() ~= nil end, 120, "Use Server & Clients with 2 clients")
	local state = Match.GetState(); assert(state)
	local map = workspace:WaitForChild("Map") :: Folder
	local keep = Instance.new("Folder"); keep.Name = "UnmanagedRoundSentinel"; keep.Parent = map
	local baselineRemotes = 0
	for _, child in Storage:GetDescendants() do if child:IsA("RemoteEvent") then baselineRemotes += 1 end end
	local baseConnection = Bases.Destroyed.Event:Connect(function() finishes += 1 end)
	local mapCount: number? = nil
	do local round = 1
		untilTrue(function() return state.roundId == round and state.phase == "InProgress" end, 35, "Next round did not start")
		local first: Player? = nil; local second: Player? = nil
		for _, player in Players:GetPlayers() do if player:GetAttribute("TeamId") == "Blue" then first = player else second = player end end
		assert(first and second); local blue, red = first :: Player, second :: Player
		untilTrue(function()
			for _, player in { blue, red } do
				local model = player.Character
				if not model or model:GetAttribute("RoundId") ~= round or model:GetAttribute("HeroAppearanceVersion") == nil then return false end
			end
			return true
		end, 20, "New heroes not ready")
		-- Isolate rewards and targeting, while using normal preparation/intermission timings.
		state.nextWaveAt = workspace:GetServerTimeNow() + 10000
		state.startedAt = workspace:GetServerTimeNow() + 10000; Rewards.Reset(); AI.Reset()
		Match.Start(); Teams.Start(state, map); Bases.Start(map); Towers.Start(map); Spawner.Start(map); Ability.Start(); Combat.Start()
		check("six tower health subscriptions round " .. round, connections() == 6)
		local remotes = 0; for _, child in Storage:GetDescendants() do if child:IsA("RemoteEvent") then remotes += 1 end end
		check("no duplicate remotes", remotes == baselineRemotes)
		check("unmanaged map content preserved", keep.Parent == map)
		local descendants = #map:GetDescendants()
		if not mapCount then mapCount = descendants end
		check("map objects do not grow", descendants == mapCount)
		check("six living towers and shielded cores", Structures.Remaining("Blue") == 3 and Structures.Remaining("Red") == 3)
		for _, base in Bases.GetAll() do check("core restored", base.humanoid.Health == base.humanoid.MaxHealth and not base.destroyed and base.root.CanCollide) end
		for _, player in { blue, red } do
			local profile = Progression.Get(player); assert(profile)
			check("profile fully reset", profile.Level == 1 and profile.CurrentXP == 0 and next(profile.Owned) == nil
				and profile.TotalKills == 0 and profile.TotalDeaths == 0 and profile.Assists == 0 and profile.TotalMinionKills == 0 and Economy.GetGold(player) == 100)
			local ability = require(Services.NarutoAbilityService).Get(player); assert(ability)
			check("cooldowns cleared", ability.q.active == nil and ability.q.cooldownAt == 0 and ability.clones.cooldownAt == 0)
		end
		local model = body(blue)
		arrange(blue, Vector3.new(0, 36, 0)); arrange(red, Vector3.new(130, 36, 50))
		check("summons cleared", Clones.GetCount() == 0)
		arrange(blue, Vector3.new(0, 36, 0))
		local npc = Spawner.Spawn("Red", "Mid", "Melee", 1); assert(npc)
		local target = AI.GetAll()[npc]; target.root.Anchored = true; target.root.CFrame = CFrame.new(0, 36, -4)
		local response = command(blue, "attack")
		check("M1 works each round", response.accepted == true and target.humanoid.Health < target.humanoid.MaxHealth)
		task.wait(1)
		local hp = target.humanoid.Health
		Progression.AddXP(blue, 450) -- Source rank-I Q eligibility; no timing shortcuts.
		response = command(blue, "cast", "Rasengan")
		check("prepared Rasengan works each round", response.accepted == true and response.attack == true and target.humanoid.Health < hp)
		Damage.Apply(model, target.humanoid, 9999); task.wait(0.15)
		check("minion rewards work each round", (Progression.Get(blue) :: any).TotalMinionKills == 1)
		local shop = Shop.GetLocation("Blue"); assert(shop)
		arrange(blue, shop.Position + Vector3.new(0, 2, -4)); Economy.AddGold(blue, 1000, "RoundTest")
		command(blue, "buy")
		check("shop works each round", (Progression.Get(blue) :: any).Owned.IronBlade == true)
		Progression.AddXP(blue, 500); Progression.Increment(blue, "TotalKills")
		arrange(blue, Vector3.new(0, 36, 0)); Ability.Reset()
		local native = require(Services.NarutoAbilityService)
		local summoned = native.TryCast(blue, "ShadowClones", round, workspace:GetServerTimeNow(), nil)
		untilTrue(function() return Clones.GetCount() > 0 end, 2, "No source clones before boundary")
		check("clones created before boundary", summoned and Clones.GetCount() > 0)
		local gold = Economy.GetGold(blue)
		local bounty = 0
		for _, tower in Towers.GetAll() do
			if tower.structure.teamId == "Red" then
				check("tower lethal hit", Damage.Apply(model, tower.structure.humanoid, 9999) > 0)
				bounty += 50
				check("tower bounty exactly once", Economy.GetGold(blue) == gold + bounty and Damage.Apply(model, tower.structure.humanoid, 9999) == 0)
			end
		end
		local base = Bases.Get("Red"); assert(base)
		task.wait(.35); local preparing = command(blue, "prepare"); local active = native.Get(blue)
		check("ability prepared near finish", preparing.accepted == true and active ~= nil and active.q.active ~= nil)
		check("core damage after shields fall", Damage.Apply(model, base.humanoid, 9999) > 0)
		untilTrue(function() return state.phase == "Finished" end, 2, "No result")
		check("winner once", state.winner == "Blue" and state.roundId == round)
		local stoppedAbility = require(Services.NarutoAbilityService).Get(blue); assert(stoppedAbility)
		check("finish stops attacks and summons", not Damage.CanAct(model) and Clones.GetCount() == 0 and stoppedAbility.q.active == nil)
		local finishingGold = Economy.GetGold(blue)
		local epoch, finishedAt, wave = state.roundId, state.finishedAt, state.wave
		local ending = command(blue, "status", "ПОБЕДА")
		check("victory HUD retained", ending.phase == "Finished" and ending.guiCount == 3)
		check("ten top hero portrait slots", ending.portraitSlots == 10)
		check("lower HP and MP use real current/max values", ending.health ~= "" and ending.mana ~= "" and string.find(ending.health, "/", 1, true) ~= nil and string.find(ending.mana, "/", 1, true) ~= nil)
		check("HUD has no round diagnostics or duplicate stats", not ending.debugText and not ending.duplicateStats)
		check("winning side sees victory", ending.resultText == "ПОБЕДА")
		Bases.Destroyed:Fire("Blue", epoch + 1)
		check("foreign epoch core event ignored", state.winner == "Blue" and state.phase == "Finished")
		Bases.Destroyed:Fire("Blue", epoch)
		check("late same epoch core event ignored", state.winner == "Blue")
		command(blue, "stale", epoch + 1)
		check("foreign epoch requests rejected", Economy.GetGold(blue) == finishingGold and Clones.GetCount() == 0)
		check("current epoch ability rejected after victory", not Ability.TryCast(blue, 999999, model, "ShadowClones"))
		check("current epoch attack rejected after victory", Combat.TryAttack(blue, 999999, model) ~= "Started")
		check("no damage after victory", Damage.Apply(model, base.humanoid, 9999) == 0)
		task.wait(17) -- Exceeds the former result/intermission/preparation cycle.
		check("match stays terminal beyond old restart deadline", state.phase == "Finished" and state.roundId == epoch and state.finishedAt == finishedAt and state.winner == "Blue")
		check("no new wave or economy after victory", state.wave == wave and Economy.GetGold(blue) == finishingGold)
		check("destroyed structures remain destroyed", Structures.Remaining("Red") == 0 and base.humanoid.Health == 0)
		check("winner character not reset", blue.Character == model and model.Parent ~= nil)
		check("loser does not respawn", red.Character == nil or (red.Character:FindFirstChildOfClass("Humanoid") :: Humanoid).Health <= 0)
		local endingAgain = command(red, "status", "ПОРАЖЕНИЕ")
		check("client effects cleared and result retained", endingAgain.effects == 0 and endingAgain.phase == "Finished")
		check("losing side sees defeat", endingAgain.resultText == "ПОРАЖЕНИЕ")
		local abilityRemote = Storage:FindFirstChild("HeroAbility") :: RemoteEvent
		abilityRemote:FireClient(blue, { kind = "RasenganFinish", position = model:GetPivot().Position, roundId = epoch })
		task.wait(.1)
		check("late same epoch visual ignored after victory", command(blue, "status").effects == 0)
	end
	check("one real destruction plus injected notifications", finishes == 3)
	baseConnection:Disconnect(); keep:Destroy()
	workspace:SetAttribute("RoundTestsPassed", count)
	print("[RoundTests] ALL PASS: " .. count .. " terminal match checks")
	return "passed"
end, function(message) return debug.traceback(tostring(message), 2) end)
if not ok then workspace:SetAttribute("RoundTestsFailed", tostring(failure)); warn("[RoundTests] FAILED after " .. count .. ": " .. tostring(failure)) end
