--!strict
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Physics = game:GetService("PhysicsService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.GameModeConfig)
local Rules = require(Shared.Game.MatchState)
local TeamService = {}
local state: Rules.State? = nil
local map: Folder? = nil
local teams: { [string]: Team } = {}
local roster: { [number]: string } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local deaths: { [Player]: RBXScriptConnection } = {}
local descendants: { [Player]: RBXScriptConnection } = {}
local pending: { [Player]: number } = {}
local loading: { [Player]: boolean } = {}
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
	return player.Parent == Players and current ~= nil and current.phase ~= "Finished"
		and typeof(id) == "string" and TeamService.IsActive(id)
end
local function characterAdded(player: Player, character: Model)
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
		if not canSpawn(player) then invalidateCharacter(player); return end
		local respawn = player.RespawnLocation
		if respawn then character:PivotTo(respawn.CFrame + Vector3.new(0, 4, 0)) end
		character:SetAttribute("CombatDisabled", false)
		deaths[player] = humanoid.Died:Connect(function()
			if canSpawn(player) then pending[player] = workspace:GetServerTimeNow() + Config.RespawnTime end
		end)
	end)
end
local function add(player: Player)
	local current, arena = state, map
	assert(current and arena)
	local id = Rules.assign(current, roster[player.UserId])
	player.Neutral = true
	if id then
		roster[player.UserId] = id; current.teams[id].count += 1
		player.Team = teams[id]; player.Neutral = false
		player:SetAttribute("TeamId", id); player:SetAttribute("Eliminated", false)
		local points = arena:FindFirstChild("SpawnPoints"); assert(points)
		local teamPoints = points:FindFirstChild(id); assert(teamPoints)
		local spawn = teamPoints:FindFirstChild("Hero")
		assert(spawn and spawn:IsA("SpawnLocation"), "Hero spawn missing for " .. id)
		player.RespawnLocation = spawn
		pending[player] = workspace:GetServerTimeNow()
	else
		player:SetAttribute("TeamId", roster[player.UserId])
		player:SetAttribute("Eliminated", true)
	end
	connections[player] = {
		player.CharacterAdded:Connect(function(character) characterAdded(player, character) end),
		player.CharacterRemoving:Connect(function()
			if deaths[player] then deaths[player]:Disconnect(); deaths[player] = nil end
			if descendants[player] then descendants[player]:Disconnect(); descendants[player] = nil end
		end),
	}
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
	for player, due in pending do
		if now >= due and not loading[player] then
			pending[player] = nil
			if not canSpawn(player) then continue end
			loading[player] = true
			task.spawn(function()
				local ok, message = pcall(function() player:LoadCharacterAsync() end)
				loading[player] = nil
				if not ok then warn("[Teams] Character load failed: " .. tostring(message)) end
				if not canSpawn(player) then invalidateCharacter(player) end
			end)
		end
	end
end
function TeamService.Start(match: Rules.State, arena: Folder)
	assert(not state, "TeamService already started"); state = match; map = arena
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
		local id = player:GetAttribute("TeamId")
		if typeof(id) == "string" and match.teams[id] and not player:GetAttribute("Eliminated") then
			match.teams[id].count = math.max(0, match.teams[id].count - 1)
		end
		pending[player] = nil
		if deaths[player] then deaths[player]:Disconnect(); deaths[player] = nil end
		if descendants[player] then descendants[player]:Disconnect(); descendants[player] = nil end
		for _, connection in connections[player] or {} do connection:Disconnect() end
		connections[player] = nil
	end)
	for _, player in Players:GetPlayers() do add(player) end
end
return TeamService
