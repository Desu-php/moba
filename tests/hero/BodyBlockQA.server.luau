--!strict
-- Opt-in Studio physics regression. Insert client companion first during solo Play.
if not game:GetService("RunService"):IsStudio() or workspace:GetAttribute("RunBodyBlockQA") ~= true then return end
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Services = game.ServerScriptService.Server.Services
local Factory = require(Services.MinionFactory)
local Config = require(game.ReplicatedStorage.Shared.Config.MinionConfig)
local player = Players:GetPlayers()[1]
assert(player and player.Character)
local character = player.Character
local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
local humanoid = character:FindFirstChildOfClass("Humanoid")
assert(humanoid)
local saved, autoRotate = root.CFrame, humanoid.AutoRotate
local folder = Instance.new("Folder"); folder.Name = "BodyBlockQA"; folder.Parent = workspace
local results = {}
local function run()
	assert(not humanoid:GetStateEnabled(Enum.HumanoidStateType.Climbing), "server climbing enabled")
	assert(not humanoid.AutoJumpEnabled, "server auto-jump enabled")
	local floor = Instance.new("Part"); floor.Size = Vector3.new(100, 1, 100)
	floor.Position = Vector3.new(0, 149, 0); floor.Anchored = true; floor.Parent = folder
	humanoid.AutoRotate = false
	for _, clientOwned in { false, true } do
		for _, team in { "Blue", "Red" } do
			for _, kind in { "Melee", "Ranged" } do
				for _, direction in { Vector3.xAxis, Vector3.zAxis, Vector3.new(1, 0, 1).Unit } do
					for _, moving in { false, true } do
						workspace:SetAttribute("BodyBlockQAClientTarget", nil)
						root:SetNetworkOwner(nil)
						local creep = Factory.Create(kind, team, Color3.new(1, 1, 1), Vector3.new(0, 152.5, 0), Config.Types[kind])
						creep.Parent = folder
						local creepRoot = creep.PrimaryPart :: BasePart
						local creepHumanoid = creep:FindFirstChildOfClass("Humanoid") :: Humanoid
						creepRoot.Anchored = not moving
						if moving then creepRoot:SetNetworkOwner(nil) end
						root.CFrame = CFrame.lookAt(Vector3.new(0, 152.5, 0) - direction * 6, Vector3.new(0, 152.5, 0))
						root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
						humanoid:MoveTo(root.Position); task.wait(.25)
						local startY, maxRise, minDistance = root.Position.Y, 0, math.huge
						local target = Vector3.new(0, 152.5, 0) + direction * 8
						if clientOwned then root:SetNetworkOwner(player); workspace:SetAttribute("BodyBlockQAClientTarget", target)
						else humanoid:MoveTo(target) end
						if moving then creepHumanoid:MoveTo(Vector3.new(0, 152.5, 0) - direction * 10) end
						local untilTime = os.clock() + 2
						while os.clock() < untilTime do
							task.wait(.03)
							maxRise = math.max(maxRise, root.Position.Y - startY)
							-- Sliding around the side is valid; passing through the body is not.
							minDistance = math.min(minDistance, ((creepRoot.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude)
							assert(humanoid:GetState() ~= Enum.HumanoidStateType.Climbing, "hero started climbing")
							assert(creepHumanoid:GetState() ~= Enum.HumanoidStateType.Climbing, "creep started climbing")
						end
						local result = { clientOwned = clientOwned, team = team, kind = kind, direction = tostring(direction), moving = moving, maxRise = maxRise, minDistance = minDistance }
						table.insert(results, result)
						assert(maxRise < .6, "hero mounted creep: " .. HttpService:JSONEncode(result))
						-- Opposing rigs have different owners: server snapshots can overlap during
						-- replication. Use stationary blockers for the strict contact assertion.
						if not moving then assert(minDistance > .85, "hero passed through creep: " .. HttpService:JSONEncode(result)) end
						creep:Destroy()
					end
				end
			end
		end
	end
end
local ok, message = pcall(run)
workspace:SetAttribute("BodyBlockQAClientTarget", nil)
root:SetNetworkOwner(nil); humanoid:MoveTo(root.Position); root.CFrame = saved
root.AssemblyLinearVelocity = Vector3.zero; humanoid.AutoRotate = autoRotate; root:SetNetworkOwnershipAuto()
folder:Destroy()
workspace:SetAttribute("BodyBlockQAResult", HttpService:JSONEncode({ ok = ok, results = results, error = if ok then nil else tostring(message) }))
assert(ok, tostring(message)); print("PASS body-block QA: " .. #results .. " sustained collision scenarios")
