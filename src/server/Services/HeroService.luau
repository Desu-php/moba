--!strict
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.HeroConfig)
local Combat = require(Shared.Config.CombatConfig)
local Ids = require(Shared.Config.AnimationIds)
local Appearance = require(script.Parent.HeroAppearanceService)
local HeroService = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local prepared: { [Model]: boolean } = setmetatable({}, { __mode = "k" })
local started = false
function HeroService.Assign(player: Player, model: Model)
	local id = player:GetAttribute("HeroId")
	if typeof(id) ~= "string" or not Config.Heroes[id] then id = Config.DefaultHero end
	local hero = Config.Heroes[id :: string]
	player:SetAttribute("HeroId", id); model:SetAttribute("HeroId", id)
	model:SetAttribute("CombatProfileId", hero.Profile)
end
local function prepare(player: Player, model: Model)
	HeroService.Assign(player, model)
	task.spawn(function()
		local humanoid = model:WaitForChild("Humanoid", Combat.CharacterReadyTimeout)
		local head = model:WaitForChild("Head", Combat.CharacterReadyTimeout)
		if player.Character ~= model or not head or not humanoid or not humanoid:IsA("Humanoid") then return end
		if humanoid.RigType ~= Enum.HumanoidRigType.R15 then warn("[Heroes] OrangeNinja needs R15; synchronize default.project.json"); return end
		Appearance.Apply(model)
		if prepared[model] then return end; prepared[model] = true
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		local profile = Combat.Profiles[tostring(model:GetAttribute("CombatProfileId"))]
		local set = if profile then Ids[profile.AnimationSet] else nil
		-- Only explicitly configured, accessible tracks suppress the procedural fallback.
		for key, asset in set or {} do
			if not string.match(asset, "^rbxassetid://[1-9]%d*$") then continue end
			task.spawn(function()
				local animation = Instance.new("Animation"); animation.AnimationId = asset
				local loaded = false
				local ok = pcall(function()
					ContentProvider:PreloadAsync({ animation }, function(_, status) loaded = status == Enum.AssetFetchStatus.Success end)
				end)
				animation:Destroy()
				if model.Parent and player.Character == model then model:SetAttribute("TrackReady_" .. key, ok and loaded) end
			end)
		end
	end)
end
local function bind(player: Player)
	if connections[player] then return end
	player:SetAttribute("HeroId", Config.DefaultHero)
	connections[player] = {
		player.CharacterAdded:Connect(function(model) prepare(player, model) end),
		player.CharacterAppearanceLoaded:Connect(function(model) prepare(player, model) end),
	}
	if player.Character then prepare(player, player.Character) end
end
function HeroService.Start()
	if started then return end; started = true
	game:GetService("StarterPlayer").LoadCharacterAppearance = false
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		for _, connection in connections[player] or {} do connection:Disconnect() end
		connections[player] = nil
	end)
	for _, player in Players:GetPlayers() do bind(player) end
end
return HeroService
