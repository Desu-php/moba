--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.CombatConfig)
local AnimationIds = require(Shared.Config.AnimationIds)
local Motion = require(script.Parent.HeroMotionController)

type Loaded = { track: AnimationTrack, animation: Animation, marker: RBXScriptConnection }
local AnimationController = {}
local animator: Animator? = nil
local tracks: { [string]: Loaded } = {}
local warned: { [string]: boolean } = {}
local current: AnimationTrack? = nil
local currentRequest = 0
local currentStep = 0
local currentSet = ""
local endsAt = 0
local generation = 0
local diedConnection: RBXScriptConnection? = nil
local markerCallback: (() -> ())? = nil
local logicalPlayCount = 0
local started = false

function AnimationController.Stop(requestId: number?)
	if requestId and requestId ~= currentRequest then return end
	Motion.StopPrediction(requestId)
	if current then current:Stop(Config.AnimationFadeTime) end
	current = nil
	currentRequest = 0
	endsAt = 0
end

local function clearCharacter()
	generation += 1
	AnimationController.Stop()
	if diedConnection then diedConnection:Disconnect(); diedConnection = nil end
	for _, loaded in tracks do
		loaded.marker:Disconnect()
		loaded.track:Destroy()
		loaded.animation:Destroy()
	end
	table.clear(tracks)
	animator = nil
end

local function warnOnce(key: string, message: string)
	if warned[key] then return end
	warned[key] = true
	warn("[CombatAnimations] " .. message)
end

local function loadTrack(profile: Config.AttackProfile, step: number): AnimationTrack?
	local animationKey = profile.AnimationKeys[step]
	local key = profile.AnimationSet .. "." .. animationKey
	local cached = tracks[key]
	if cached then return cached.track end
	local set = AnimationIds[profile.AnimationSet]
	local assetId = if set then set[animationKey] else nil
	if not assetId or not string.match(assetId, "^rbxassetid://[1-9]%d*$") then
		return nil
	end
	local owner = animator
	if not owner then return nil end
	local animation = Instance.new("Animation")
	animation.Name = animationKey
	animation.AnimationId = assetId
	local success, result = pcall(function() return owner:LoadAnimation(animation) end)
	if not success then
		animation:Destroy()
		warnOnce(key, "Cannot load " .. key .. ": " .. tostring(result))
		return nil
	end
	local track = result :: AnimationTrack
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	local marker = track:GetMarkerReachedSignal("Hit"):Connect(function()
		-- This marker may drive a local cue, never a request or damage decision.
		if current == track and markerCallback then markerCallback() end
	end)
	tracks[key] = { track = track, animation = animation, marker = marker }
	return track
end

local function bindCharacter(model: Model)
	clearCharacter()
	local token = generation
	task.spawn(function()
		local humanoid = model:WaitForChild("Humanoid", Config.CharacterReadyTimeout)
		if token ~= generation or not humanoid or not humanoid:IsA("Humanoid") then return end
		if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			warnOnce("Rig", "R15 is required for the configured animations. Set the experience avatar type to R15.")
			return
		end
		local serverAnimator = humanoid:WaitForChild("Animator", Config.CharacterReadyTimeout)
		if token ~= generation then return end
		if not serverAnimator or not serverAnimator:IsA("Animator") then
			warnOnce("Animator", "Server-created Animator missing; local Animator will not be created.")
			return
		end
		animator = serverAnimator
		diedConnection = humanoid.Died:Connect(function() AnimationController.Stop() end)
		local profile = Config.Profiles[Config.DefaultProfile]
		for step = 1, #profile.AnimationKeys do loadTrack(profile, step) end
	end)
end

function AnimationController.Play(requestId: number, step: number, profile: Config.AttackProfile, startedAt: number): boolean
	local now = workspace:GetServerTimeNow()
	local elapsed = math.max(0, now - startedAt)
	if elapsed >= profile.AttackDurationByComboStep[step] then return false end
	if currentRequest == requestId and currentStep == step then
		-- Confirm the prediction without replaying the track from frame zero.
		if currentSet ~= profile.AnimationSet then
			if current then current:Stop(Config.AnimationFadeTime) end
			currentSet = profile.AnimationSet
			current = loadTrack(profile, step)
			if current then
				current:Play(Config.AnimationFadeTime)
				if current.Length > 0 then current.TimePosition = math.min(elapsed, current.Length) end
			end
		end
		if current and current.Length > 0 and math.abs(current.TimePosition - elapsed) > Config.AnimationCorrectionThreshold then
			current.TimePosition = math.min(elapsed, current.Length)
		end
		endsAt = startedAt + profile.AttackDurationByComboStep[step]
		Motion.Predict(requestId, profile.AnimationKeys[step], startedAt, profile.AttackDurationByComboStep[step])
		return false
	end
	AnimationController.Stop()
	currentRequest, currentStep, currentSet = requestId, step, profile.AnimationSet
	endsAt = startedAt + profile.AttackDurationByComboStep[step]
	logicalPlayCount += 1
	Motion.Predict(requestId, profile.AnimationKeys[step], startedAt, profile.AttackDurationByComboStep[step])
	local track = loadTrack(profile, step)
	if track then
		current = track
		track:Play(Config.AnimationFadeTime)
		if track.Length > 0 then track.TimePosition = math.min(elapsed, track.Length) end
	end
	return true
end

function AnimationController.GetLogicalPlayCount(): number
	return logicalPlayCount
end

function AnimationController.Start(onMarker: () -> ())
	if started then return end
	started = true
	Motion.Start()
	markerCallback = onMarker
	Players.LocalPlayer.CharacterAdded:Connect(bindCharacter)
	Players.LocalPlayer.CharacterRemoving:Connect(clearCharacter)
	if Players.LocalPlayer.Character then bindCharacter(Players.LocalPlayer.Character) end
	RunService.Heartbeat:Connect(function()
		if currentRequest ~= 0 and workspace:GetServerTimeNow() >= endsAt then AnimationController.Stop() end
	end)
end

return AnimationController
