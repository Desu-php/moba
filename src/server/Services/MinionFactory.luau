--!strict
local Physics = game:GetService("PhysicsService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.MinionConfig)
local Factory = {}
local registered = false
function Factory.Create(kind: string, teamId: string, color: Color3, position: Vector3, stats: Config.Stats): Model
	if not registered then
		if not Physics:IsCollisionGroupRegistered("SurvivalMinions") then Physics:RegisterCollisionGroup("SurvivalMinions") end
		Physics:CollisionGroupSetCollidable("SurvivalMinions", "SurvivalMinions", false)
		registered = true
	end
	local model = Instance.new("Model"); model.Name = teamId .. kind
	model:SetAttribute("TeamId", teamId); model:SetAttribute("EntityKind", "Minion"); model:SetAttribute("MinionType", kind)
	local function part(name: string, size: Vector3, offset: Vector3, visible: boolean): Part
		local item = Instance.new("Part"); item.Name = name; item.Size = size; item.Position = position + offset
		item.Color = color; item.Material = Enum.Material.SmoothPlastic
		item.TopSurface = Enum.SurfaceType.Smooth; item.BottomSurface = Enum.SurfaceType.Smooth
		item.CollisionGroup = "SurvivalMinions"; item.CanCollide = name == "Torso"; item.CanTouch = false
		item.Transparency = if visible then 0 else 1; item.Parent = model
		return item
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, false)
	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.zero, true)
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), true)
	head.Color = if kind == "Ranged" then Color3.fromRGB(255, 217, 105) else color:Lerp(Color3.new(1, 1, 1), 0.3)
	local function joint(name: string, parent: BasePart, child: BasePart, offset: Vector3)
		local motor = Instance.new("Motor6D"); motor.Name = name; motor.Part0 = parent; motor.Part1 = child
		motor.C0 = CFrame.new(offset); motor.Parent = parent
	end
	joint("RootJoint", root, torso, Vector3.zero); joint("Neck", torso, head, Vector3.new(0, 1.5, 0))
	for _, side in { -1, 1 } do
		local label = if side == -1 then "Left" else "Right"
		local arm = part(label .. " Arm", Vector3.new(1, 2, 1), Vector3.new(side * 1.5, 0, 0), true)
		local leg = part(label .. " Leg", Vector3.new(1, 2, 1), Vector3.new(side * 0.5, -2, 0), true)
		joint(label .. " Shoulder", torso, arm, Vector3.new(side * 1.5, 0, 0))
		joint(label .. " Hip", torso, leg, Vector3.new(side * 0.5, -2, 0))
	end
	local humanoid = Instance.new("Humanoid"); humanoid.MaxHealth = stats.MaxHealth; humanoid.Health = stats.MaxHealth
	humanoid.WalkSpeed = stats.WalkSpeed; humanoid.BreakJointsOnDeath = false; humanoid.DisplayName = teamId .. " " .. kind
	humanoid.HealthDisplayDistance = 45; humanoid.NameDisplayDistance = 30; humanoid.Parent = model
	model.PrimaryPart = root
	return model
end
return Factory
