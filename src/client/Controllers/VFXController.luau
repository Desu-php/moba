--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.VFXConfig)
local Debug = require(Shared.Config.DebugConfig)
local Rounds = require(script.Parent.RoundController)

type Effect = { object: Instance, expiresAt: number, tweens: { Tween } }
local VFXController = {}
local effects: { Effect } = {}
local debugEffects: { Effect } = {}
local folder: Folder? = nil
local started = false
local shakeEnabled = Config.CameraShakeEnabled
local shakeUntil = 0
local shakeDuration = 0
local shakeAmplitude = 0
local shakeHumanoid: Humanoid? = nil
local cameraOffset = Vector3.zero

local function dispose(effect: Effect)
	for _, tween in effect.tweens do tween:Cancel() end
	effect.object:Destroy()
end
function VFXController.Clear()
	for _, effect in effects do dispose(effect) end; table.clear(effects)
	for _, effect in debugEffects do dispose(effect) end; table.clear(debugEffects)
	shakeUntil = 0; shakeAmplitude = 0
	if shakeHumanoid and shakeHumanoid.Parent then shakeHumanoid.CameraOffset = Vector3.zero end
	shakeHumanoid = nil; cameraOffset = Vector3.zero
end
Rounds.Watch(VFXController.Clear)

local function remember(object: Instance, lifetime: number, tweens: { Tween }, debugEffect: boolean?)
	local list = if debugEffect then debugEffects else effects
	local limit = if debugEffect then Debug.MaxDebugHitboxes else Config.MaxEffects
	while #list >= limit do
		local oldest = table.remove(list, 1)
		if oldest then dispose(oldest) end
	end
	table.insert(list, { object = object, expiresAt = os.clock() + lifetime, tweens = tweens })
end

local function part(name: string, position: Vector3, size: Vector3, color: Color3): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Anchored = true
	object.CanCollide = false
	object.CanQuery = false
	object.CanTouch = false
	object.CastShadow = false
	object.Material = Enum.Material.Neon
	object.Color = color
	object.Size = size
	object.Position = position
	return object
end

function VFXController.Swing(character: Model, step: number)
	local handName = if step % 2 == 0 then "LeftHand" else "RightHand"
	local hand = character:FindFirstChild(handName) or character:FindFirstChild("Right Arm")
	if not hand then return end
	local glow = Instance.new("Highlight")
	glow.Name = "PredictedSwingCue"
	glow.Adornee = hand
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.FillColor = Config.NormalColor
	glow.FillTransparency = 0.45
	glow.OutlineTransparency = 1
	glow.Parent = folder
	remember(glow, Config.SwingLifetime, {})
end

function VFXController.Projectile(origin: Vector3, destination: Vector3, color: Color3, duration: number)
	local shot = part("MinionProjectile", origin, Vector3.one * 0.45, color)
	shot.Shape = Enum.PartType.Ball; shot.Parent = folder
	local tween = TweenService:Create(shot, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Position = destination })
	tween:Play(); remember(shot, duration, { tween })
end

function VFXController.Hit(character: Model, position: Vector3, heavy: boolean)
	local lifetime = if heavy then Config.HeavyLifetime else Config.HitLifetime
	local color = if heavy then Config.HeavyColor else Config.NormalColor
	local group = Instance.new("Folder")
	group.Name = "ConfirmedHit"
	group.Parent = folder
	local tweens: { Tween } = {}
	local sphere = part("Flash", position, Vector3.one * Config.HitSize, color)
	sphere.Shape = Enum.PartType.Ball
	sphere.Parent = group
	local flashTween = TweenService:Create(sphere, TweenInfo.new(lifetime), {
		Size = Vector3.one * (if heavy then Config.HeavyExpansion else Config.HitExpansion), Transparency = 1,
	})
	table.insert(tweens, flashTween)
	flashTween:Play()
	local reaction = Instance.new("Highlight")
	reaction.Adornee = character
	reaction.DepthMode = Enum.HighlightDepthMode.Occluded
	reaction.FillColor = Config.ReactionColor
	reaction.FillTransparency = 0.65
	reaction.OutlineTransparency = 1
	reaction.Parent = group
	for index = 1, Config.SparkCount do
		local angle = (index / Config.SparkCount) * math.pi * 2
		local direction = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local spark = part("Spark", position, Vector3.new(0.06, 0.06, Config.SparkLength), color)
		spark.CFrame = CFrame.lookAt(position, position + direction)
		spark.Parent = group
		local tween = TweenService:Create(spark, TweenInfo.new(lifetime), {
			Position = position + direction * Config.SparkTravel, Transparency = 1,
		})
		table.insert(tweens, tween)
		tween:Play()
	end
	remember(group, lifetime, tweens)
end

local function stopShake()
	if shakeHumanoid and shakeHumanoid.Parent then shakeHumanoid.CameraOffset = cameraOffset end
	shakeHumanoid = nil
	shakeUntil = 0
	shakeAmplitude = 0
end

function VFXController.Shake(heavy: boolean)
	if not shakeEnabled then return end
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then return end
	if shakeHumanoid ~= humanoid then
		stopShake()
		shakeHumanoid = humanoid
		cameraOffset = humanoid.CameraOffset
	end
	shakeDuration = if heavy then Config.HeavyShakeDuration else Config.ShakeDuration
	shakeUntil = os.clock() + shakeDuration
	shakeAmplitude = math.max(shakeAmplitude, if heavy then Config.HeavyShakeAmplitude else Config.ShakeAmplitude)
end

function VFXController.SetCameraShakeEnabled(enabled: boolean)
	shakeEnabled = enabled
	if not enabled then stopShake() end
end

function VFXController.DebugBox(frame: CFrame, size: Vector3)
	if not Debug.DebugHitboxes then return end
	local box = part("DebugHitbox", frame.Position, size, Color3.fromRGB(85, 215, 255))
	box.CFrame = frame
	box.Transparency = 0.8
	box.Parent = folder
	remember(box, Debug.HitboxLifetime, {}, true)
end

function VFXController.GetActiveCount(): number
	return #effects
end

function VFXController.Start()
	if started then return end
	started = true
	local container = Instance.new("Folder")
	container.Name = "LocalCombatVFX"
	local existing = workspace:FindFirstChild("Effects")
	local effectsRoot = if existing and existing:IsA("Folder") then existing else Instance.new("Folder")
	effectsRoot.Name = "Effects"; effectsRoot.Parent = workspace
	container.Parent = effectsRoot
	folder = container
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		stopShake()
		for _, list in { effects, debugEffects } do
			for _, effect in list do dispose(effect) end
			table.clear(list)
		end
	end)
	RunService:BindToRenderStep("CombatCameraFeedback", Enum.RenderPriority.Camera.Value - 1, function()
		local humanoid = shakeHumanoid
		if not humanoid then return end
		local now = os.clock()
		if now >= shakeUntil or not humanoid.Parent or humanoid.Health <= 0 then stopShake(); return end
		local amplitude = shakeAmplitude * math.clamp((shakeUntil - now) / shakeDuration, 0, 1)
		humanoid.CameraOffset = cameraOffset + Vector3.new(math.sin(now * Config.ShakeFrequency), math.cos(now * Config.ShakeFrequency * 1.3), 0) * amplitude
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, list in { effects, debugEffects } do
			for index = #list, 1, -1 do
				if now >= list[index].expiresAt then
					local expired = table.remove(list, index)
					if expired then dispose(expired) end
				end
			end
		end
	end)
end

return VFXController
