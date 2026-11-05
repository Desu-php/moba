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
local selections:{[Player]:number}={}
local choosing:{[Player]:boolean}={}
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
 local selection=Instance.new("RemoteEvent");selection.Name="HeroSelection";selection.Parent=game.ReplicatedStorage
 selection.OnServerEvent:Connect(function(player:Player,id:any,...:any)
  if select("#",...)~=0 or typeof(id)~="string" or not Config.Heroes[id] or choosing[player] then return end
  local now=os.clock();if now-(selections[player] or -10)<2 then return end;selections[player]=now
  local model=player.Character;local root=if model then model:FindFirstChild("HumanoidRootPart") else nil
  local hp=if model then model:FindFirstChildOfClass("Humanoid") else nil
  if not hp or hp.Health<=0 then selection:FireClient(player,false,"Дождитесь возрождения героя");return end
  local spawn=player.RespawnLocation;local state=require(script.Parent.TeamService).GetState()
  if not state or not model or not root or not root:IsA("BasePart") or not spawn or (root.Position-spawn.Position).Magnitude>30 then selection:FireClient(player,false,"Выбор героя доступен на своей базе");return end
  if player:GetAttribute("HeroChosenRound")==state.roundId and not game:GetService("RunService"):IsStudio() then selection:FireClient(player,false,"Герой уже выбран на этот матч");return end
  if model:GetAttribute("CombatState")=="Stunned" then return end
  choosing[player]=true;player:SetAttribute("HeroChosenRound",state.roundId);player:SetAttribute("HeroId",id)
  local progression=require(script.Parent.HeroProgressionService);local profile=progression.Get(player)
  if profile then profile.Learned={};profile.SkillPoints=profile.Level;progression.Publish(player) end
  selection:FireClient(player,true,id)
  task.spawn(function() local ok,err=pcall(function() player:LoadCharacterAsync() end);choosing[player]=nil;if not ok then warn("[Heroes] Respawn failed",err) end end)
 end)
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		for _, connection in connections[player] or {} do connection:Disconnect() end
		connections[player] = nil
	end)
	for _, player in Players:GetPlayers() do bind(player) end
end
return HeroService
