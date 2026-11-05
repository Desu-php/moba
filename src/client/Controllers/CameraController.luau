--!strict
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Gui = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.CameraConfig)
local Rules = require(Shared.Combat.CombatCameraRules)
local Kurama = require(Shared.Config.KuramaAvatarConfig)

local Controller = {}
local player = Players.LocalPlayer
local started, focused, active = false, true, false
local enabled = true
local yaw, pitch = 0, math.rad(Config.InitialPitch)
local followed: Model? = nil
local previousHumanoid: Humanoid? = nil
local previousAutoRotate = true
local previousCamera: Camera? = nil
local previousType = Enum.CameraType.Custom
local pivot: Vector3? = nil
local distance = Config.Distance
local reticle: ScreenGui? = nil
local hiddenParts: { [BasePart]: number } = {}
local fadedSummons: { [Model]: { [BasePart]: number } } = {}
local nextOcclusion = 0

local function showSummon(model: Model)
	local parts = fadedSummons[model]
	if not parts then return end
	for part, transparency in parts do
		if part.Parent then part.LocalTransparencyModifier = transparency end
	end
	fadedSummons[model] = nil
end

local function updateSummonOcclusion(camera: Camera)
	local now = os.clock()
	if now < nextOcclusion then return end
	nextOcclusion = now + .05
	local blocking: { [Model]: boolean } = {}
	local summons = workspace:FindFirstChild("HeroSummons")
	local team = player:GetAttribute("TeamId")
	if summons then
		for _, model in summons:GetChildren() do
			if not model:IsA("Model") or not (model:GetAttribute("SummonOwner") == player.UserId
				or (team ~= nil and model:GetAttribute("TeamId") == team)) then continue end
			local root = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then continue end
			local relative = camera.CFrame:PointToObjectSpace(root.Position)
			local depth = -relative.Z
			-- Bounds include the toad's head and a narrow corridor around the reticle.
			-- Only nearby friendly bodies fade; enemies retain normal combat readability.
			local radius = math.max(root.Size.X, root.Size.Y, root.Size.Z) * .65 + 1
			if depth > -radius and depth < 40 and Vector2.new(relative.X, relative.Y).Magnitude < radius + math.max(0,depth)*.035 then
				blocking[model] = true
				local saved = fadedSummons[model]
				if not saved then saved = {}; fadedSummons[model] = saved end
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						if saved[part] == nil then saved[part] = part.LocalTransparencyModifier end
						part.LocalTransparencyModifier = math.max(saved[part], .75)
					end
				end
			end
		end
	end
	for model in fadedSummons do if not blocking[model] then showSummon(model) end end
end

local function showCharacter()
	for part, transparency in hiddenParts do
		if part.Parent then part.LocalTransparencyModifier = transparency end
	end
	table.clear(hiddenParts)
end

function Controller.IsCaptured(): boolean
	return started and enabled and active and Input.KeyboardEnabled and Rules.captured(focused, Gui.MenuIsOpen, Input:GetFocusedTextBox() ~= nil,
		player:GetAttribute("ShopOpen") == true or player:GetAttribute("HeroSelectionOpen")==true, player:GetAttribute("StatsOpen") == true,
		player:GetAttribute("CombatCursorFree") == true or player:GetAttribute("DeveloperConsoleOpen") == true)
end

function Controller.GetAimRay(): Ray?
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	return camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end

local function restore()
	showCharacter()
	for model in fadedSummons do showSummon(model) end
	nextOcclusion = 0
	if previousHumanoid and previousHumanoid.Parent then previousHumanoid.AutoRotate = previousAutoRotate end
	previousHumanoid = nil
	if previousCamera and previousCamera.Parent then previousCamera.CameraType = previousType end
	previousCamera = nil
	followed, pivot, active = nil, nil, false
	Input.MouseBehavior = Enum.MouseBehavior.Default
	Input.MouseIconEnabled = true
	if reticle then reticle.Enabled = false end
end

function Controller.SetEnabled(value: boolean)
	enabled = value
	if not value then restore() end
end

local function setting(name: string, fallback: number, minimum: number, maximum: number): number
	return Rules.setting(player:GetAttribute("CombatCamera" .. name), fallback, minimum, maximum)
end

local function exclusions(character: Model): { Instance }
	local excluded: { Instance } = { character }
	-- Summons, characters and VFX must never pump the camera in and out.
	for _, name in { "HeroSummons", "LocalHeroVFX", "Effects", "JungleCamps", "NPCs" } do
		local object = workspace:FindFirstChild(name)
		if object then table.insert(excluded, object) end
	end
	for _, other in Players:GetPlayers() do
		if other.Character and other.Character ~= character then table.insert(excluded, other.Character) end
	end
	return excluded
end

function Controller.Start()
	if started or not Input.KeyboardEnabled then return end
	started = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatReticle"; gui.ResetOnSpawn = false; gui.ScreenInsets = Enum.ScreenInsets.None; gui.DisplayOrder = 5
	for _, axis in { true, false } do
		local line = Instance.new("Frame")
		line.Name = if axis then "Horizontal" else "Vertical"
		line.AnchorPoint = Vector2.new(0.5, 0.5); line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.fromOffset(if axis then 11 else 2, if axis then 2 else 11)
		line.BorderSizePixel = 0; line.BackgroundColor3 = Color3.fromRGB(240, 244, 250); line.BackgroundTransparency = 0.2
		local outline = Instance.new("UIStroke"); outline.Thickness = 1; outline.Transparency = 0.35; outline.Parent = line
		line.Parent = gui
	end
	gui.Parent = player:WaitForChild("PlayerGui"); reticle = gui
	Input.WindowFocusReleased:Connect(function() focused = false; player:SetAttribute("CombatCursorFree", false) end)
	Input.WindowFocused:Connect(function() focused = true end)
	Input.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.LeftAlt and not processed and not Input:GetFocusedTextBox() then player:SetAttribute("CombatCursorFree", true) end
	end)
	Input.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt then player:SetAttribute("CombatCursorFree", false) end
	end)
	player.CharacterRemoving:Connect(restore)
	RunService:BindToRenderStep("CombatShoulderCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not enabled then return end
		local model = player.Character
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
		local camera = workspace.CurrentCamera
		if not model or not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 or not camera then
			if active then restore() end
			return
		end
		if followed ~= model then
			local look = root.CFrame.LookVector
			yaw = math.atan2(-look.X, -look.Z); pitch = math.rad(Config.InitialPitch)
			followed = model; pivot = nil; distance = Config.Distance
			previousHumanoid = humanoid; previousAutoRotate = humanoid.AutoRotate
		end
		if previousCamera ~= camera then
			if previousCamera and previousCamera.Parent then previousCamera.CameraType = previousType end
			previousCamera, previousType = camera, camera.CameraType
		end
		active = true
		camera.CameraType = Enum.CameraType.Scriptable
		humanoid.AutoRotate = false
		local captured = Controller.IsCaptured()
		Input.MouseBehavior = if captured then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
		Input.MouseIconEnabled = not captured; gui.Enabled = captured
		local hitUntil = player:GetAttribute("CombatHitUntil")
		local validTarget = player:GetAttribute("AimTargetValid")
		local color = if typeof(hitUntil) == "number" and hitUntil > workspace:GetServerTimeNow() then Color3.fromRGB(255, 211, 101)
			elseif validTarget == true then Color3.fromRGB(119, 234, 157)
			elseif validTarget == false then Color3.fromRGB(244, 102, 100) else Color3.fromRGB(240, 244, 250)
		for _, line in gui:GetChildren() do if line:IsA("Frame") then line.BackgroundColor3 = color end end
		if captured then
			local delta = Input:GetMouseDelta()
			local sensitivity = math.rad(setting("Sensitivity", Config.Sensitivity, 0.03, 1))
			yaw -= delta.X * sensitivity
			pitch = math.clamp(pitch - delta.Y * sensitivity, math.rad(Config.MinimumPitch), math.rad(Config.MaximumPitch))
		end
		local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		local fox = model:GetAttribute("HeroVisualForm") == "Kurama"
  local susanoo=((model:GetAttribute("SusanooForm") or 0) :: number)>=3
		local desiredPivot = root.Position + Vector3.new(0, if fox then Kurama.CameraHeight elseif susanoo then 8 else setting("Height", Config.Height, 0.5, 6), 0)
		local oldPivot = pivot
		pivot = if not oldPivot or (oldPivot - desiredPivot).Magnitude > Config.TeleportDistance then desiredPivot
			else oldPivot:Lerp(desiredPivot, Rules.alpha(setting("Smoothing", Config.Smoothing, 0, 60), dt))
		local focus = (pivot :: Vector3) + CFrame.Angles(0, yaw, 0):VectorToWorldSpace(humanoid.CameraOffset)
		local desiredOffset = -rotation.LookVector * (if fox then Kurama.CameraDistance elseif susanoo then 23 else setting("Distance", Config.Distance, 4, 24))
			+ rotation.RightVector * setting("Shoulder", Config.Shoulder, -3, 3)
		local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclusions(model); params.RespectCanCollide = true
		local wall = workspace:Spherecast(focus, Config.CollisionRadius, desiredOffset, params)
		local safeDistance = if wall then math.max(0, wall.Distance - Config.CollisionPadding) else desiredOffset.Magnitude
		-- A new obstruction retracts immediately; leaving a wall restores distance gradually.
		distance = if safeDistance < distance then safeDistance else distance + (safeDistance - distance) * Rules.alpha(Config.ReturnSpeed, dt)
		camera.CFrame = CFrame.new(focus + desiredOffset.Unit * distance) * rotation
		camera.Focus = CFrame.new(focus)
		updateSummonOcclusion(camera)
		-- At a very close wall the camera can enter the avatar. Hide only local
		-- character geometry until there is room again; other players still see it.
		if distance < 2 then
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					if hiddenParts[part] == nil then hiddenParts[part] = part.LocalTransparencyModifier end
					part.LocalTransparencyModifier = 1
				end
			end
		elseif next(hiddenParts) ~= nil then showCharacter() end
		-- Server-owned control/knockback keeps its orientation. Never unanchor or change WalkSpeed.
		if captured and humanoid.WalkSpeed > 0 and not humanoid.PlatformStand and not humanoid.Sit and not root.Anchored
			and model:GetAttribute("CombatState") ~= "Stunned" then
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
		end
	end)
end

return Controller
