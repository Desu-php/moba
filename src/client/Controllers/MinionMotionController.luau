--!strict
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Poses = require(Shared.Combat.MinionPoses)
type Rig = { root: BasePart, humanoid: Humanoid, joints: { Motor6D }, nextAt: number, deathAt: number?, neutral: boolean }
local Motion = {}
local rigs: { [Model]: Rig } = {}
local connection: RBXScriptConnection? = nil
local nextScan = 0
local names = { RootJoint = true, Neck = true, ["Left Shoulder"] = true, ["Right Shoulder"] = true, ["Left Hip"] = true, ["Right Hip"] = true }
local function reset(rig: Rig)
	for _, joint in rig.joints do if joint.Parent then joint.Transform = CFrame.identity end end
	rig.neutral = true
end
local function scan()
	local npcs = workspace:FindFirstChild("NPCs")
	local folder = if npcs then npcs:FindFirstChild("SurvivalMinions") else nil
	if not folder then return end
	for _, model in folder:GetChildren() do
		if not model:IsA("Model") or model:GetAttribute("EntityKind") ~= "Minion" then continue end
		local rig = rigs[model]
		local complete = rig ~= nil and #rig.joints == 6
		if rig then
			for _, joint in rig.joints do if not joint:IsDescendantOf(model) then complete = false; break end end
		end
		if complete then continue end
		local root = model:FindFirstChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid then continue end
		local joints: { Motor6D } = {}
		for _, item in model:GetDescendants() do
			if item:IsA("Motor6D") and names[item.Name] then table.insert(joints, item) end
		end
		if rig then reset(rig) end
		rigs[model] = { root = root, humanoid = humanoid, joints = joints, nextAt = 0, deathAt = if rig then rig.deathAt else nil, neutral = true }
	end
end
function Motion.Stop()
	if connection then connection:Disconnect(); connection = nil end
	for _, rig in rigs do reset(rig) end
	table.clear(rigs); nextScan = 0
end
function Motion.Start()
	if connection then return end
	-- One shared loop, no Animation instances, per-NPC event connections, or server pose replication.
	connection = RunService.PreSimulation:Connect(function()
		local now = workspace:GetServerTimeNow()
		if now >= nextScan then nextScan = now + .5; scan() end
		local camera = workspace.CurrentCamera
		for model, rig in rigs do
			if not model:IsDescendantOf(workspace) or not rig.root:IsDescendantOf(model) or not rig.humanoid:IsDescendantOf(model) then
				reset(rig); rigs[model] = nil; continue
			end
			if now < rig.nextAt then continue end
			local distance = if camera then (camera.CFrame.Position - rig.root.Position).Magnitude else math.huge
			local visible = false
			if camera and distance <= Poses.FarDistance then
				local _, onScreen = camera:WorldToViewportPoint(rig.root.Position); visible = onScreen
			end
			rig.nextAt = now + Poses.Interval(distance, visible)
			if not visible or distance > Poses.FarDistance then
				if not rig.neutral then reset(rig) end
				continue
			end
			local velocity = rig.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			local at = model:GetAttribute("MinionAttackAt")
			local dead = rig.humanoid.Health <= 0 or model:GetAttribute("AIState") == "Dead"
			local state, phase = Poses.State(dead, model:GetAttribute("CombatState") == "Stunned", model:GetAttribute("CombatDisabled") == true,
				velocity.Magnitude, now, if typeof(at) == "number" then at else nil)
			if dead then
				local diedAt = model:GetAttribute("MinionDiedAt")
				rig.deathAt = if typeof(diedAt) == "number" then diedAt else rig.deathAt or now
				phase = math.clamp((now - (rig.deathAt :: number)) / Poses.DeathDuration, 0, 1)
			end
			local angles = Poses.Sample(state, now, phase, model:GetAttribute("MinionType") == "Ranged", model:GetAttribute("MinionVisual") == "WhiteZetsu")
			for _, joint in rig.joints do
				local rotation = angles[joint.Name]
				if joint.Parent and rotation then joint.Transform = CFrame.Angles(rotation[1], rotation[2], rotation[3]) end
			end
			rig.neutral = false
		end
	end)
end
return Motion
