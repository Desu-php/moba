--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.MapConfig)
local Mode = require(Shared.Config.GameModeConfig)
local Progression = require(Shared.Config.ProgressionConfig)
local TowerFactory = require(script.Parent.TowerFactory)
local MapScenery = require(script.Parent.MapScenery)
local MapBuilder = {}
function MapBuilder.EnsureShops(map: Folder)
	local existing = map:FindFirstChild("Shops")
	assert(not existing or existing:IsA("Folder"), "Map.Shops must be a Folder")
	local shops = existing or Instance.new("Folder"); shops.Name = "Shops"; shops.Parent = map
	local spawns = map:FindFirstChild("SpawnPoints"); assert(spawns)
	for _, team in Mode.Teams do
		if shops:FindFirstChild(team.Id) then continue end
		local points = spawns:FindFirstChild(team.Id); assert(points)
		local hero = points:FindFirstChild("Hero"); assert(hero and hero:IsA("BasePart"))
		local offset = Progression.ShopOffset
		local shop = Instance.new("Part"); shop.Name = team.Id; shop.Size = Vector3.new(5, 3, 5); shop.Anchored = true
		shop.Position = hero.Position + Vector3.new(offset.X, offset.Y, offset.Z)
		shop.Color = Color3.fromRGB(226, 181, 68); shop.Material = Enum.Material.Metal
		shop:SetAttribute("TeamId", team.Id); shop.Parent = shops
		local prompt = Instance.new("ProximityPrompt"); prompt.Name = "ShopPrompt"; prompt.ActionText = "Магазин"
		prompt.ObjectText = team.Id .. " • предметы за Gold"; prompt.MaxActivationDistance = Progression.ShopPromptDistance
		prompt.HoldDuration = 0; prompt.RequiresLineOfSight = false; prompt.Parent = shop
	end
end
local function folder(parent: Instance, name: string): Folder
	local item = Instance.new("Folder"); item.Name = name; item.Parent = parent; return item
end
local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local item = Instance.new("Part")
	item.Name = name; item.Anchored = true; item.Size = size; item.Position = Config.Origin + position
	item.Color = color; item.Material = Enum.Material.SmoothPlastic; item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth; item.Parent = parent; return item
end
function MapBuilder.Build(): Folder
	local existing = workspace:FindFirstChild("Map")
	if existing then
		assert(existing:IsA("Folder") and (existing:GetAttribute("SurvivalMapVersion") == Config.Version or existing:GetAttribute("AuthoredSurvivalMap") == true),
			"Workspace.Map is not a supported survival map; rename your existing container or supply an authored map")
		MapBuilder.EnsureShops(existing)
		TowerFactory.Build(existing)
		MapScenery.Ensure(existing)
		return existing
	end
	assert(Config.Generated, "Generated map disabled: provide Workspace.Map with AuthoredSurvivalMap=true")
	local map = Instance.new("Folder"); map.Name = "Map"; map:SetAttribute("SurvivalMapVersion", Config.Version)
	local ground = folder(map, "Ground"); local lanes = folder(map, "Lanes")
	local bases = folder(map, "Bases"); local spawns = folder(map, "SpawnPoints")
	local waypoints = folder(map, "Waypoints"); local decorations = folder(map, "Decorations")
	part(ground, "Arena", Config.GroundSize, Vector3.zero, Color3.fromRGB(82, 100, 66)).Material = Enum.Material.Grass
	local battlefield=part(ground,"ScorchedFront",Vector3.new(610,.06,130),Vector3.new(0,1.035,-270),Color3.fromRGB(134,122,98))
	battlefield.Material=Enum.Material.Ground;battlefield.CanCollide=false;battlefield.CanQuery=false
	-- Visible perimeter ridges stop characters from falling off the generated arena.
	for side=-1,1,2 do
		part(ground,"NorthSouthRidge"..side,Vector3.new(Config.GroundSize.X+12,18,8),Vector3.new(0,3,side*(Config.GroundSize.Z/2+4)),Color3.fromRGB(101,109,86)).Material=Enum.Material.Rock
		part(ground,"EastWestRidge"..side,Vector3.new(8,18,Config.GroundSize.Z),Vector3.new(side*(Config.GroundSize.X/2+4),3,0),Color3.fromRGB(101,109,86)).Material=Enum.Material.Rock
	end
	local routes = Config.Routes :: { [string]: { Vector3 } }
	for _, name in Config.LaneOrder do
		local lane = folder(lanes, name); local points = folder(waypoints, name)
		local route = routes[name]
		for index, position in route do
			local marker = part(points, tostring(index), Vector3.one, position, Color3.new(1, 1, 1))
			marker.Transparency = 1; marker.CanCollide = false; marker.CanQuery = false; marker.CanTouch = false
			if index < #route then
				local nextPosition = route[index + 1]
				local delta = nextPosition - position
				local road = part(lane, "Road" .. index, Vector3.new(Config.LaneWidth, 0.2, delta.Magnitude + Config.LaneWidth),
					(position + nextPosition) / 2 - Vector3.new(0, 2.85, 0), Color3.fromRGB(139, 124, 94))
				road.CFrame = CFrame.lookAt(road.Position, road.Position + delta)
				road.Material = Enum.Material.Ground
			end
		end
	end
	local paths=folder(map,"JunglePaths")
	for name,route in Config.Paths do
		local container=folder(paths,name)
		for i=1,#route-1 do
			local a,b=route[i],route[i+1];local delta=b-a
			local road=part(container,"Path"..i,Vector3.new(18,.08,delta.Magnitude+18),(a+b)/2-Vector3.new(0,2.88,0),Color3.fromRGB(109,107,77))
			road.CFrame=CFrame.lookAt(road.Position,road.Position+delta);road.Material=Enum.Material.Ground
			road.CanCollide=false;road.CanQuery=false
		end
	end
	local settings = Config.Teams :: { [string]: { Base: Vector3, Hero: Vector3, Reverse: boolean } }
	for _, team in Mode.Teams do
		local layout = settings[team.Id]; assert(layout, "Map layout missing for " .. team.Id)
		local model = Instance.new("Model"); model.Name = team.Id .. "Base"; model:SetAttribute("TeamId", team.Id)
		model:SetAttribute("EntityKind", "Base"); model.Parent = bases
		local root = part(model, "HumanoidRootPart", Vector3.new(6, 6, 6), layout.Base, team.Color)
		root.Material = Enum.Material.Neon; model.PrimaryPart = root
		local humanoid = Instance.new("Humanoid"); humanoid.RequiresNeck = false; humanoid.BreakJointsOnDeath = false
		humanoid.MaxHealth = Mode.BaseHealth; humanoid.Health = Mode.BaseHealth; humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.Parent = model
		part(decorations, team.Id .. "Foundation", Vector3.new(23, 0.3, 23), layout.Base - Vector3.new(0, 2.85, 0), team.Color)
		local teamSpawns = folder(spawns, team.Id)
		local spawn = Instance.new("SpawnLocation"); spawn.Name = "Hero"; spawn.Anchored = true
		spawn.Size = Vector3.new(8, 1, 8); spawn.Position = Config.Origin + layout.Hero
		local facing = Config.Origin + layout.Base
		spawn.CFrame = CFrame.lookAt(spawn.Position, Vector3.new(facing.X, spawn.Position.Y, facing.Z))
		spawn.Color = team.Color; spawn.TeamColor = BrickColor.new(team.Color); spawn.Neutral = false
		spawn.AllowTeamChangeOnTouch = false; spawn.Duration = 0; spawn.Parent = teamSpawns
		for _, lane in Config.LaneOrder do
			local route = routes[lane]; local location = route[if layout.Reverse then #route else 1]
			local marker = part(teamSpawns, lane, Vector3.one, location, team.Color)
			marker.Transparency = 1; marker.CanCollide = false; marker.CanQuery = false; marker.CanTouch = false
		end
	end
	for index, position in Config.Obstacles do
		part(decorations, "Rock" .. index, Vector3.new(15, 8, 12), position, Color3.fromRGB(65, 72, 77)).Material = Enum.Material.Rock
	end
	map.Parent = workspace
	MapBuilder.EnsureShops(map)
	TowerFactory.Build(map)
	MapScenery.Ensure(map)
	return map
end
function MapBuilder.Route(map: Folder, lane: string, reverse: boolean): { Vector3 }
	local waypoints = map:FindFirstChild("Waypoints"); assert(waypoints, "Waypoints missing")
	local container = waypoints:FindFirstChild(lane); assert(container, "Route missing")
	local ordered = container:GetChildren()
	table.sort(ordered, function(a, b) return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0) end)
	local route = {}
	for _, item in ordered do if item:IsA("BasePart") then table.insert(route, item.Position) end end
	assert(#route >= 2, "Route requires at least two points")
	if reverse then
		local reversed = {}; for index = #route, 1, -1 do table.insert(reversed, route[index]) end
		return reversed
	end
	return route
end
return MapBuilder
