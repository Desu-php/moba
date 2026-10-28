--!strict
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Physics = game:GetService("PhysicsService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.GameModeConfig)
local Rules = require(Shared.Game.MatchState)
local Roster = require(Shared.Game.MatchRoster)
local TeamService = {}
local state: Rules.State? = nil
local map: Folder? = nil
local teams: { [string]: Team } = {}
local roster: Roster.State? = nil
local connections: { [Player]: { RBXScriptConnection } } = {}
local deaths: { [Player]: RBXScriptConnection } = {}
local descendants: { [Player]: RBXScriptConnection } = {}
local pending: { [Player]: number } = {}
local loading: { [Player]: number } = {}
local resetRound = 1
function TeamService.GetId(model: Model): string?
	local player = Players:GetPlayerFromCharacter(model)
	local id = if player then player:GetAttribute("TeamId") else model:GetAttribute("TeamId")
	return if typeof(id) == "string" then id else nil
end
function TeamService.IsActive(id: string?): boolean
	local current = state
	return current ~= nil and id ~= nil and current.teams[id] ~= nil and current.teams[id].active
end
function TeamService.IsEnemy(first: Model, second: Model): boolean
	local current = state
	if not current then return first ~= second end -- Isolated M1 regression scene.
	return Rules.enemy(current, TeamService.GetId(first), TeamService.GetId(second))
end
function TeamService.GetActiveTeams(): { string }
	return if state then Rules.active(state) else {}
end
function TeamService.GetState(): Rules.State? return state end
function TeamService.IsParticipant(player: Player): boolean
	local current, members = state, roster
	return current ~= nil and members ~= nil and Roster.teamOf(members, player.UserId) ~= nil
		and player.Parent == Players and player:GetAttribute("Spectating") ~= true
end
function TeamService.Count(): number
	return if roster then Roster.connectedCount(roster) else 0
end
function TeamService.Ready(minimumPerTeam: number): boolean
	return roster ~= nil and Roster.ready(roster, minimumPerTeam)
end
function TeamService.LockRoster()
	if roster then Roster.lock(roster) end
end
local function syncCounts()
	local current, members = state, roster
	if not current or not members then return end
	local counts = Roster.counts(members)
	for id, team in current.teams do team.count = counts[id] or 0 end
end
local function invalidateCharacter(player: Player)
	pending[player] = nil
	local character = player.Character
	if character then
		character:SetAttribute("CombatDisabled", true)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Health = 0 end
	end
end
local function canSpawn(player: Player): boolean
	local current = state
	local id = player:GetAttribute("TeamId")
	return player.Parent == Players and current ~= nil and current.phase ~= "Finished" and current.phase ~= "Intermission"
		and TeamService.IsParticipant(player) and typeof(id) == "string" and TeamService.IsActive(id)
end
local function characterAdded(player: Player, character: Model)
	local current = state; if not current then return end
	local epoch = loading[player] or current.roundId
	character:SetAttribute("RoundId", epoch)
	if deaths[player] then deaths[player]:Disconnect(); deaths[player] = nil end
	if descendants[player] then descendants[player]:Disconnect() end
	local function collision(item: Instance)
		if item:IsA("BasePart") and item.CollisionGroup == "Default" then item.CollisionGroup = "SurvivalHeroes" end
	end
	for _, item in character:GetDescendants() do collision(item) end
	descendants[player] = character.DescendantAdded:Connect(collision)
	local id = player:GetAttribute("TeamId")
	character:SetAttribute("TeamId", id); character:SetAttribute("EntityKind", "Hero")
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if player.Character ~= character or player.Parent ~= Players then return end
		if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then return end
		if epoch ~= current.roundId or not canSpawn(player) then invalidateCharacter(player); return end
		local respawn = player.RespawnLocation
		if respawn then character:PivotTo(respawn.CFrame + Vector3.new(0, 4, 0)) end
		character:SetAttribute("CombatDisabled", false)
		deaths[player] = humanoid.Died:Connect(function()
			if epoch == current.roundId and player.Character == character and canSpawn(player) then pending[player] = workspace:GetServerTimeNow() + Config.RespawnTime end
		end)
	end)
end
local function add(player: Player)
	local current, arena = state, map
	assert(current and arena)
	player:SetAttribute("RoundId", current.roundId)
	local members = roster; assert(members)
	local id: string? = if current.phase ~= "Finished" and current.phase ~= "Intermission" then Roster.join(members, player.UserId) else nil
	local eliminated = id ~= nil and not TeamService.IsActive(id)
	if eliminated then id = nil end
	syncCounts()
	player.Neutral = true
	if id then
		player:SetAttribute("Spectating", false)
		player.Team = teams[id]; player.Neutral = false
		player:SetAttribute("TeamId", id); player:SetAttribute("Eliminated", false)
		local points = arena:FindFirstChild("SpawnPoints"); assert(points)
		local teamPoints = points:FindFirstChild(id); assert(teamPoints)
		local spawn = teamPoints:FindFirstChild("Hero")
		assert(spawn and spawn:IsA("SpawnLocation"), "Hero spawn missing for " .. id)
		player.RespawnLocation = spawn
		pending[player] = workspace:GetServerTimeNow()
	else
		-- Roblox permits clearing these object references; the API definitions omit nil.
		player.Team = nil :: any; player.RespawnLocation = nil :: any
		player:SetAttribute("TeamId", nil)
		player:SetAttribute("Spectating", true)
		player:SetAttribute("Eliminated", eliminated)
		invalidateCharacter(player)
	end
	if not connections[player] then connections[player] = {
		player.CharacterAdded:Connect(function(character) characterAdded(player, character) end),
		player.CharacterRemoving:Connect(function()
			if deaths[player] then deaths[player]:Disconnect(); deaths[player] = nil end
			if descendants[player] then descendants[player]:Disconnect(); descendants[player] = nil end
		end),
	} end
	if player.Character then characterAdded(player, player.Character) end
end
function TeamService.Eliminate(id: string)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("TeamId") == id then
			player:SetAttribute("Eliminated", true); invalidateCharacter(player)
		end
	end
end
function TeamService.Finish()
	table.clear(pending)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			character:SetAttribute("CombatDisabled", true)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid:Move(Vector3.zero); humanoid.WalkSpeed = 0; humanoid.JumpPower = 0; humanoid.JumpHeight = 0 end
		end
	end
end
function TeamService.Update(now: number)
	local current = state; if not current then return end
	-- Fill vacated lobby slots deterministically. A locked round accepts only its
	-- original members on reconnect; new arrivals wait until the next round.
	if current.phase == "WaitingForPlayers" or current.phase == "Preparing" then
		local waiting = Players:GetPlayers()
		table.sort(waiting, function(a: Player, b: Player) return a.UserId < b.UserId end)
		for _, player in waiting do
			if TeamService.Count() >= #current.order * Config.TeamCapacity then break end
			if player:GetAttribute("Spectating") == true then add(player) end
		end
	end
	for player, due in pending do
		if now >= due and not loading[player] then
			pending[player] = nil
			if not canSpawn(player) then continue end
			local epoch = current.roundId
			loading[player] = epoch
			task.spawn(function()
				local ok, message = pcall(function() player:LoadCharacterAsync() end)
				loading[player] = nil
				if not ok then warn("[Teams] Character load failed: " .. tostring(message)) end
				if epoch ~= current.roundId then
					local model = player.Character
					if model and model:GetAttribute("RoundId") == epoch then model:Destroy(); player.Character = nil end
					if canSpawn(player) then pending[player] = workspace:GetServerTimeNow() end
				elseif not canSpawn(player) then invalidateCharacter(player)
				elseif not ok then pending[player] = workspace:GetServerTimeNow() + 2 end
			end)
		end
	end
end
function TeamService.Start(match: Rules.State, arena: Folder)
	if state then return end; state = match; map = arena; resetRound = match.roundId
	roster = Roster.new(match.order, Config.TeamCapacity)
	Players.CharacterAutoLoads = false
	for _, name in { "SurvivalHeroes", "SurvivalMinions" } do
		if not Physics:IsCollisionGroupRegistered(name) then Physics:RegisterCollisionGroup(name) end
	end
	Physics:CollisionGroupSetCollidable("SurvivalHeroes", "SurvivalMinions", false)
	for _, definition in Config.Teams do
		local existing = Teams:FindFirstChild(definition.Id)
		assert(not existing or existing:IsA("Team"), "Team name occupied")
		local team = (existing or Instance.new("Team")) :: Team
		team.Name = definition.Id; team.TeamColor = BrickColor.new(definition.Color); team.AutoAssignable = false
		team.Parent = Teams; teams[definition.Id] = team
	end
	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(function(player)
		local wasAssigned = roster ~= nil and Roster.teamOf(roster, player.UserId) ~= nil
		if roster then Roster.leave(roster, player.UserId) end
		if wasAssigned and match.phase == "Preparing" then
			match.phase = "WaitingForPlayers"; match.preparationEnds = 0
		end
		syncCounts()
		pending[player] = nil
		if deaths[player] then deaths[player]:Disconnect(); deaths[player] = nil end
		if descendants[player] then descendants[player]:Disconnect(); descendants[player] = nil end
		for _, connection in connections[player] or {} do connection:Disconnect() end
		connections[player] = nil
	end)
	for _, player in Players:GetPlayers() do add(player) end
end
function TeamService.Reset(roundId: number)
	local current = state; assert(current and current.roundId == roundId)
	if roundId <= resetRound then return end; resetRound = roundId
	table.clear(pending); roster = Roster.new(current.order, Config.TeamCapacity)
	for _, team in current.teams do team.count = 0 end
	local players = Players:GetPlayers()
	table.sort(players, function(a: Player, b: Player) return a.UserId < b.UserId end)
	for _, player in players do
		if deaths[player] then deaths[player]:Disconnect(); deaths[player] = nil end
		if descendants[player] then descendants[player]:Disconnect(); descendants[player] = nil end
		local character = player.Character
		if character then character:SetAttribute("CombatDisabled", true); character:Destroy(); player.Character = nil end
		player:SetAttribute("RoundId", roundId)
		add(player)
	end
end
return TeamService
