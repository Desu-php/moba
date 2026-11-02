--!strict
local Services = game:GetService("ServerScriptService"):WaitForChild("Server").Services
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Factory = require(Services.MinionFactory)
local Config = require(Shared.Config.MinionConfig)
local checks = 0
local function check(value: boolean, message: string)
	assert(value, "[MinionVisualTests] " .. message); checks += 1
end
local npcs = Instance.new("Folder"); npcs.Name = "NPCs"; npcs.Parent = workspace
local folder = Instance.new("Folder"); folder.Name = "SurvivalMinions"; folder.Parent = npcs
local floor = Instance.new("Part"); floor.Name = "FixtureFloor"; floor.Size = Vector3.new(140, 1, 140)
floor.Anchored = true; floor.Position = Vector3.new(0, -.5, 0); floor.Parent = workspace
local function make(teamId: string, kind: string, position: Vector3): Model
	local stats = Config.Types[kind]
	local model = Factory.Create(kind, teamId, Color3.new(0, 0, 1), position, stats)
	local root = model.PrimaryPart :: BasePart; root.Anchored = true
	model.Parent = folder
	check(root.Size == Vector3.new(2, 2, 1), "root hitbox preserved")
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	check(humanoid.MaxHealth == stats.MaxHealth and humanoid.WalkSpeed == stats.WalkSpeed, "gameplay stats preserved")
	local torso = model:FindFirstChild("Torso") :: BasePart
	check(torso.Size == Vector3.new(2, 2, 1) and torso.CanCollide, "physical torso preserved")
	local cosmetics = model:FindFirstChild("MinionCosmetics") :: Folder
	check(#cosmetics:GetChildren() <= 18, "bounded primitive budget")
	for _, part in cosmetics:GetChildren() do
		check(part:IsA("BasePart") and not part.CanCollide and not part.CanTouch and not part.CanQuery and part.Massless, "cosmetic cannot alter combat/physics")
	end
	local motors = 0
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") then
			motors += 1
			local a, b = item.Part0 :: BasePart, item.Part1 :: BasePart
			check(((a.CFrame * item.C0).Position - (b.CFrame * item.C1).Position).Magnitude < .001, "rest pose unchanged")
		end
	end
	check(motors == 6, "exactly six animated joints")
	return model
end
-- Three full-cap batches exercise bounded instance creation and destruction, without starting combat.
for wave = 1, 3 do
	for index = 1, Config.MaxActiveNPCs do
		make(if index % 2 == 0 then "Blue" else "Red", if index % 3 == 0 then "Ranged" else "Melee", Vector3.new(index % 12 * 6 - 36, 3, math.floor(index / 12) * 6))
	end
	check(#folder:GetChildren() == Config.MaxActiveNPCs, "full wave created")
	task.wait(.25)
	for _, model in folder:GetChildren() do model:Destroy() end
	check(#folder:GetChildren() == 0, "wave destroyed")
	task.wait(.25)
end
local samples: { Model } = {}
for index = 1, 4 do
	local model = make(if index <= 2 then "Blue" else "Red", if index % 2 == 0 then "Ranged" else "Melee", Vector3.new((index - 2.5) * 7, 3, 0))
	table.insert(samples, model)
end
print(string.format("[MinionVisualTests] PASS %d invariant checks; 3 x 108 cleanup; four visual samples remain", checks))
-- Actual displacement drives run; timestamp is the same presentation contract used by AI.
while true do
	for step = 1, 40 do
		for _, model in samples do
			local root = model.PrimaryPart :: BasePart
			root.Anchored = false; root.AssemblyLinearVelocity = Vector3.new(0, 0, -5)
		end
		task.wait(.05)
	end
	for _, model in samples do
		local root = model.PrimaryPart :: BasePart; root.Anchored = true
		model:SetAttribute("MinionAttackAt", workspace:GetServerTimeNow())
	end
	task.wait(1)
	for index, model in samples do model:PivotTo(CFrame.new((index - 2.5) * 7, 3, 0)) end
	task.wait(1)
end
