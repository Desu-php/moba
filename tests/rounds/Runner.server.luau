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
local Clones = require(Services.CloneService)
local Spawner = require(Services.MinionSpawnerService)
local AI = require(Services.MinionAIService)
local Progression = require(Services.HeroProgressionService)
local Economy = require(Services.EconomyService)
local Shop = require(Services.ItemShopService)
local Life = require(Services.CombatLifeService)
local Rewards = require(Services.RewardService)
local RoundConfig = require(Storage:WaitForChild("Shared").Config.RoundConfig)
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
	print("[RoundTests] Waiting for 2 clients; production round timings are preserved...")
	untilTrue(function() return #Players:GetPlayers() == 2 and Match.GetState() ~= nil end, 120, "Use Server & Clients with 2 clients")
	local state = Match.GetState(); assert(state)
	local map = workspace:WaitForChild("Map") :: Folder
	local keep = Instance.new("Folder"); keep.Name = "UnmanagedRoundSentinel"; keep.Parent = map
	local oldHero: Model? = nil; local oldHumanoid: Humanoid? = nil; local oldDeath: Life.Death? = nil
	local oldTowerHumanoid: Humanoid? = nil
	local baselineRemotes = 0
	for _, child in Storage:GetDescendants() do if child:IsA("RemoteEvent") then baselineRemotes += 1 end end
	local baseConnection = Bases.Destroyed.Event:Connect(function() finishes += 1 end)
	local deathConnection = Life.Died.Event:Connect(function(event: Life.Death) oldDeath = event end)
	local mapCount: number? = nil
	for round = 1, 3 do
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
			local ability = Ability.GetState(player); assert(ability)
			check("cooldowns cleared", ability.active == nil and next(ability.ready) == nil)
		end
		local model, humanoid = body(blue)
		arrange(blue, Vector3.new(0, 36, 0)); arrange(red, Vector3.new(130, 36, 50))
		check("summons cleared", Clones.GetCount() == 0)
		if round > 1 then
			assert(oldHero and oldHumanoid and oldTowerHumanoid)
			check("old life removed", oldHero ~= model and oldHero.Parent == nil and oldTowerHumanoid.Parent == nil)
			check("stale attacker cannot damage", Damage.Apply(oldHero, humanoid, 100) == 0)
			check("stale victim cannot receive damage", Damage.Apply(model, oldHumanoid, 100) == 0)
			check("stale reset ignored", not Match.ResetRound(round - 1))
			Bases.Destroyed:Fire("Blue", round - 1)
			if oldDeath then Life.Died:Fire(oldDeath) end
			local shop = Shop.GetLocation("Blue"); assert(shop); arrange(blue, shop.Position + Vector3.new(0, 2, -4))
			Economy.AddGold(blue, 900, "StaleRequestFixture")
			command(blue, "stale", round - 1)
			check("old network requests cannot buy, attack or summon", Economy.GetGold(blue) == 1000 and Clones.GetCount() == 0
				and model:GetAttribute("AbilityId") == "" and model:GetAttribute("CombatLastAttackAt") == 0 and state.phase == "InProgress")
			check("old death cannot reward", (Progression.Get(blue) :: any).TotalKills == 0)
		end
		arrange(blue, Vector3.new(0, 36, 0))
		local npc = Spawner.Spawn("Red", "Mid", "Melee", 1); assert(npc)
		local target = AI.GetAll()[npc]; target.root.Anchored = true; target.root.CFrame = CFrame.new(0, 36, -4)
		local response = command(blue, "attack")
		check("M1 works each round", response.accepted == true and target.humanoid.Health < target.humanoid.MaxHealth)
		task.wait(1)
		local hp = target.humanoid.Health
		response = command(blue, "cast", "SpiralSphere")
		check("Rasengan works each round", response.accepted == true and target.humanoid.Health < hp)
		Damage.Apply(model, target.humanoid, 9999); task.wait(0.15)
		check("minion rewards work each round", (Progression.Get(blue) :: any).TotalMinionKills == 1)
		local shop = Shop.GetLocation("Blue"); assert(shop)
		arrange(blue, shop.Position + Vector3.new(0, 2, -4)); Economy.AddGold(blue, 1000, "RoundTest")
		command(blue, "buy")
		check("shop works each round", (Progression.Get(blue) :: any).Owned.IronBlade == true)
		Progression.AddXP(blue, 500); Progression.Increment(blue, "TotalKills")
		arrange(blue, Vector3.new(0, 36, 0)); Ability.Reset()
		check("clones created before boundary", Clones.Spawn(blue, model) > 0)
		local gold = Economy.GetGold(blue)
		local bounty = 0
		for _, tower in Towers.GetAll() do
			if tower.structure.teamId == "Red" then
				oldTowerHumanoid = tower.structure.humanoid
				check("tower lethal hit", Damage.Apply(model, tower.structure.humanoid, 9999) > 0)
				bounty += 50
				check("tower bounty exactly once", Economy.GetGold(blue) == gold + bounty and Damage.Apply(model, tower.structure.humanoid, 9999) == 0)
			end
		end
		local base = Bases.Get("Red"); assert(base)
		check("ability prepared near finish", command(blue, "prepare").accepted == true)
		oldHero = model; oldHumanoid = humanoid
		check("core damage after shields fall", Damage.Apply(model, base.humanoid, 9999) > 0)
		untilTrue(function() return state.phase == "Finished" end, 2, "No result")
		check("winner once", state.winner == "Blue" and state.roundId == round)
		local stoppedAbility = Ability.GetState(blue); assert(stoppedAbility)
		check("finish stops attacks and summons", not Damage.CanAct(model) and Clones.GetCount() == 0 and stoppedAbility.active == nil)
		check("early reset rejected", not Match.ResetRound(round))
		local ending = command(blue, "status")
		check("HUD round and result", ending.roundId == round and string.find(ending.title, tostring(round), 1, true) ~= nil and ending.guiCount == 3)
		untilTrue(function() return state.phase == "Intermission" end, RoundConfig.IntermissionTime, "No intermission")
		local endingAgain = command(red, "status")
		check("client effects cleared", endingAgain.effects == 0 and endingAgain.phase == "Intermission")
		if round == 3 then
			untilTrue(function() return state.roundId == 4 end, 15, "Third reset did not complete")
			check("third reset restored six towers", Structures.Remaining("Blue") == 3 and Structures.Remaining("Red") == 3)
		end
	end
	-- Three real destructions plus two explicitly injected stale events.
	check("no duplicated base notifications", finishes == 5)
	baseConnection:Disconnect(); deathConnection:Disconnect(); keep:Destroy()
	workspace:SetAttribute("RoundTestsPassed", count)
	print("[RoundTests] ALL PASS: " .. count .. " checks across three rounds")
	return "passed"
end, function(message) return debug.traceback(tostring(message), 2) end)
if not ok then workspace:SetAttribute("RoundTestsFailed", tostring(failure)); warn("[RoundTests] FAILED after " .. count .. ": " .. tostring(failure)) end
