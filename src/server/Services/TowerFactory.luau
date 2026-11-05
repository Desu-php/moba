--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.TowerConfig)
local Map = require(Shared.Config.MapConfig)
local Mode = require(Shared.Config.GameModeConfig)
local Factory = {}
function Factory.Build(map: Folder): Folder
	local existing = map:FindFirstChild("Towers")
	assert(not existing or existing:IsA("Folder"), "Map.Towers must be a Folder")
	local container = existing or Instance.new("Folder"); container.Name = "Towers"; container.Parent = map
	local layouts = Config.Positions :: { [string]: { [string]: { { number } } } }
	for _, team in Mode.Teams do for _, lane in Map.LaneOrder do for tier, profile in Config.Tiers do
		local name = team.Id .. "_" .. lane .. (if tier == 1 then "" else "_T" .. tier)
		local previous = container:FindFirstChild(name)
		if previous then
			assert(previous:IsA("Model") and previous:GetAttribute("ManagedTower") == true, "Unknown object occupies tower slot " .. name)
			continue
		end
		local positions = layouts[team.Id] and layouts[team.Id][lane]
		local coordinates = positions and positions[tier]; assert(coordinates, "Tower layout missing: " .. name)
		local origin = Map.Origin + Vector3.new(coordinates[1], coordinates[2], coordinates[3])
		local model = Instance.new("Model"); model.Name = name
		model:SetAttribute("ManagedTower", true); model:SetAttribute("EntityKind", "Tower"); model:SetAttribute("TeamId", team.Id)
		model:SetAttribute("Lane", lane); model:SetAttribute("IsDestroyed", false); model:SetAttribute("TowerState", "Idle")
		model:SetAttribute("TowerTier", tier); model:SetAttribute("TowerTitle", profile.Name)
		model:SetAttribute("AttackDamage", Config.Damage * profile.DamageMultiplier)
		model:SetAttribute("AttackInterval", Config.AttackInterval * profile.IntervalMultiplier)
		model:SetAttribute("AttackRange", Config.Range)
		model:SetAttribute("CrystalSize", 2.6 + (tier-1)*.35)
		local function part(partName: string, size: Vector3, offset: Vector3, color: Color3, hurtbox: boolean): Part
			local item = Instance.new("Part"); item.Name = partName; item.Size = size; item.Position = origin + offset
			item.Anchored = true; item.CanCollide = hurtbox; item.CanQuery = hurtbox; item.CanTouch = false
			item:SetAttribute("StructureCosmetic", not hurtbox); item.Color = color; item.Material = Enum.Material.Metal
			item.TopSurface = Enum.SurfaceType.Smooth; item.BottomSurface = Enum.SurfaceType.Smooth; item.Parent = model; return item
		end
		local root = part("HumanoidRootPart", Vector3.new(5, 6, 5), Vector3.zero, Color3.fromRGB(55, 64, 78), true)
		model.PrimaryPart = root
		part("Plinth", Vector3.new(8+tier-1, 1, 8+tier-1), Vector3.new(0, -2.5, 0), Color3.fromRGB(36, 43, 54), false)
		if profile.Height > 0 then
			part("UpperPillar", Vector3.new(5, profile.Height, 5), Vector3.new(0, 3+profile.Height/2, 0), Color3.fromRGB(55, 64, 78), false)
		end
		part("Capital", Vector3.new(7+tier-1, 1, 7+tier-1), Vector3.new(0, 3.5+profile.Height, 0), team.Color, false)
		for level = 1, tier do
			part("RankBand"..level, Vector3.new(5.3,.25,5.3), Vector3.new(0,1.4+(level-1)*1.5,0), Color3.fromRGB(230,192,98), false).Material=Enum.Material.Neon
		end
		for _, side in { -1, 1 } do
			part("TeamStripe", Vector3.new(0.22, 4, 2), Vector3.new(side * 2.6, 0, 0), team.Color, false).Material = Enum.Material.Neon
			part("Fin", Vector3.new(0.6, 4, 0.6), Vector3.new(side * 2.5, 5+profile.Height, 0), team.Color, false)
		end
		local crystal = part("Crystal", Vector3.one*(2.6+(tier-1)*.35), Vector3.new(0, 6.3+profile.Height, 0), team.Color, false)
		crystal.Material = Enum.Material.Neon; crystal.CFrame *= CFrame.Angles(0, math.pi / 4, math.pi / 4)
		local light = Instance.new("PointLight"); light.Color = team.Color; light.Brightness = 0.8; light.Range = 12; light.Parent = crystal
		local humanoid = Instance.new("Humanoid"); humanoid.RequiresNeck = false; humanoid.BreakJointsOnDeath = false
		humanoid.MaxHealth = Config.Health*profile.HealthMultiplier; humanoid.Health = humanoid.MaxHealth; humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.Parent = model; model.Parent = container
	end end end
	return container :: Folder
end
return Factory
