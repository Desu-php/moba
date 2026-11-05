--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Poses = require(Shared.Combat.HeroPoses)
local Config = require(Shared.Config.AbilityConfig)
local Combat = require(Shared.Config.CombatConfig)
local Ids = require(Shared.Config.AnimationIds)
local RigJoints = require(Shared.Combat.RigJoints)
local Reaction = require(Shared.Combat.HitReaction)
type Prediction = { id: number, key: string, at: number, duration: number }
type Rig = { model: Model, humanoid: Humanoid, root: BasePart, joints: { RigJoints.Entry }, poses: { [Instance]: CFrame },
	tracks: { [string]: AnimationTrack }, animations: { Animation }, animate: LocalScript?, animateEnabled: boolean,
	key: string, track: AnimationTrack?, owned: boolean }
local Motion = {}
local rigs: { [Model]: Rig } = {}
local prediction: Prediction? = nil
local started = false
local nextScan = 0
function Motion.Predict(id: number, key: string, at: number, duration: number)
	prediction = { id = id, key = key, at = at, duration = duration }
end
function Motion.StopPrediction(id: number?) if not id or (prediction and prediction.id == id) then prediction = nil end end
local function remove(model: Model)
	local rig = rigs[model]; if not rig then return end
	for _, entry in rig.joints do if entry.joint.Parent then entry.joint.Transform = CFrame.identity end end
	for _, track in rig.tracks do track:Stop(0); track:Destroy() end
	for _, animation in rig.animations do animation:Destroy() end
	if rig.animate and rig.animate.Parent then rig.animate.Enabled = rig.animateEnabled end
	rigs[model] = nil
end
local function bind(model: Model)
	if rigs[model] then rigs[model].joints = RigJoints.Collect(model); return end
	local humanoid = model:FindFirstChildOfClass("Humanoid"); local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or humanoid.RigType ~= Enum.HumanoidRigType.R15 or not root or not root:IsA("BasePart") then return end
	local joints = RigJoints.Collect(model)
	if #joints == 0 then return end -- Refresh as streamed limbs arrive; do not require 15 legacy motors.
	local localOwner = model == Players.LocalPlayer.Character
	local animate = model:FindFirstChild("Animate")
	local scriptAnimate = if localOwner and animate and animate:IsA("LocalScript") then animate else nil
	local rig: Rig = { model = model, humanoid = humanoid, root = root, joints = joints, poses = {}, tracks = {}, animations = {},
		animate = scriptAnimate, animateEnabled = if scriptAnimate then scriptAnimate.Enabled else false,
		key = "", track = nil, owned = localOwner }
	if scriptAnimate and model:GetAttribute("HeroId") then
		scriptAnimate.Enabled = false
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then for _, track in animator:GetPlayingAnimationTracks() do if track.Priority == Enum.AnimationPriority.Core then track:Stop(0.1) end end end
	end
	rigs[model] = rig
end
local function active(rig: Rig, now: number): (string, number, number)
	local model = rig.model
	local throwAt=model:GetAttribute("RasenshurikenThrowAt")
 if typeof(throwAt)=="number" and now>=throwAt and now<throwAt+.8 then return "RasenshurikenThrow",throwAt,.8 end
	local variant = model:GetAttribute("RasenganVariant")
	local technique = if variant == "Odama" or variant == "Rasenshuriken" then variant else "Rasengan"
	local function attackKey(key: string): string
		return if model:GetAttribute("RasenganHeld") == true and (string.match(key,"^Punch%d$") or key == "HeavyPunch") then technique.."Strike" else key
	end
	if model:GetAttribute("NativeMeditationClone")==true then return "Meditation",now,1 end
	local sageReady=model:GetAttribute("SageReadyAt")
 if model:GetAttribute("SagePhase")=="Preparing" and typeof(sageReady)=="number" and now<sageReady then return "SagePrepare",now,1 end
 local rangedUntil=model:GetAttribute("RangedPreparingUntil");local rangedAt=model:GetAttribute("RangedCastStartedAt")
 if typeof(rangedUntil)=="number" and typeof(rangedAt)=="number" and now<rangedUntil then
  if now<rangedAt+1.3 then return "RasenganPrepare",rangedAt,1.3 else return "RasenganStrike",rangedAt+1.3,.2 end
 end
 local selfPause = model:GetAttribute("RasenganSelfPauseUntil")
	local ownPause = typeof(selfPause)=="number" and now<selfPause
	local phase = model:GetAttribute("RasenganPhase")
	local impact = model:GetAttribute("RasenganImpactAt")
	if phase=="Consumed" and ownPause and typeof(impact)=="number" and impact>now then
		local impactDelay = if technique == "Rasenshuriken" then .5 else 1
		return technique.."Strike",impact-impactDelay,impactDelay
	end
	local rasenganAt = model:GetAttribute("RasenganStartedAt"); local ready = model:GetAttribute("RasenganReadyAt")
	-- Begin gathering immediately, including the one-second selection window.
	-- Presentation alone never introduces a new movement or input lock.
	if phase=="Preparing" and typeof(rasenganAt)=="number" and typeof(ready)=="number" and now>=rasenganAt and now<ready then return technique.."Prepare",rasenganAt,ready-rasenganAt end
	if model:GetAttribute("RasenganHelper")==true then return "RasenganHelper",0,1 end
	if model:GetAttribute("CombatState") == "Stunned" then return "Stun", now, 1 end
	local ability = model:GetAttribute("AbilityId")
	if typeof(ability) == "string" and ability ~= "" then
		local at = model:GetAttribute("AbilityStartedAt"); local ends = model:GetAttribute("AbilityEndsAt")
		if typeof(at) == "number" and typeof(ends) == "number" and now < ends then return ability, at, ends - at end
	end
	local intent = if rig.owned then prediction else nil
	if intent and now < intent.at + intent.duration then return attackKey(intent.key), intent.at, intent.duration end
	local swingAt = model:GetAttribute("SummonSwingAt")
	if typeof(swingAt) == "number" and now < swingAt + 0.28 then return "Punch" .. tostring(model:GetAttribute("SummonSwingStep") or 1), swingAt, 0.28 end
	local ends, at = model:GetAttribute("CombatAttackEndsAt"), model:GetAttribute("CombatLastAttackAt")
	if typeof(ends) == "number" and typeof(at) == "number" and now < ends then
		return attackKey("Punch1"), at, ends - at
	end
	local velocity = rig.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	return if velocity.Magnitude > 1.5 or model:GetAttribute("SummonMoving") == true then "Run" else "Idle", 0, 1
end
local function hasPublished(rig: Rig, key: string, at: number, duration: number): boolean
	local animator = rig.humanoid:FindFirstChildOfClass("Animator"); if not animator then return false end
	local profile = Combat.Profiles[tostring(rig.model:GetAttribute("CombatProfileId"))] or Combat.Profiles.Default
	local set = Ids[profile.AnimationSet]; local id = if set then set[key] else nil
	if not id or id == "" or rig.model:GetAttribute("EntityKind") == "Summon" then return false end
	local m1 = key == "HeavyPunch" or string.match(key, "^Punch%d$") ~= nil
	-- M1 tracks belong to AnimationController, including local prediction. Observers only inspect replication.
	if rig.owned and not m1 and rig.model:GetAttribute("TrackReady_" .. key) == true then
		local track = rig.tracks[key]
		if not track then
			local animation = Instance.new("Animation"); animation.AnimationId = id; table.insert(rig.animations, animation)
			local ok, loaded = pcall(function() return animator:LoadAnimation(animation) end)
			if ok then track = loaded; rig.tracks[key] = loaded end
		end
		if track and track.Length > 0 then
			if rig.track ~= track or rig.key ~= key then
				if rig.track then rig.track:Stop(Combat.AnimationFadeTime) end
				track.Looped = key == "Idle" or key == "Run" or key == "Stun"
				track.Priority = if key == "Idle" then Enum.AnimationPriority.Idle elseif key == "Run" then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action
				track:Play(Combat.AnimationFadeTime)
				if not track.Looped then track.TimePosition = math.min(math.max(0, workspace:GetServerTimeNow() - at), duration) end
				rig.track = track
			end
		end
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Animation and track.Animation.AnimationId == id and track.Length > 0 and track.IsPlaying then return true end
	end
	return false
end
function Motion.GetDiagnostics(model: Model): (string?, number)
	local rig = rigs[model]; if not rig then return nil, 0 end
	local moved = 0
	for _, entry in rig.joints do local x, y, z = entry.joint.Transform:ToOrientation(); if math.abs(x) + math.abs(y) + math.abs(z) > 0.05 then moved += 1 end end
	return rig.key, moved
end
function Motion.Start()
	if started then return end; started = true
	Players.LocalPlayer.CharacterRemoving:Connect(function(model) prediction = nil; remove(model) end)
	-- Animator evaluates after PreAnimation. Apply fallback joint transforms in PreSimulation.
	RunService.PreSimulation:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		if now >= nextScan then
			nextScan = now + 0.25
			for _, player in Players:GetPlayers() do if player.Character then bind(player.Character) end end
			local summons = workspace:FindFirstChild("HeroSummons")
			if summons then for _, model in summons:GetChildren() do if model:IsA("Model") then bind(model) end end end
			local visuals = workspace:FindFirstChild("LocalHeroVFX")
			if visuals then for _, model in visuals:GetChildren() do if model:IsA("Model") and model:GetAttribute("RasenganHelper")==true then bind(model) end end end
		end
		for model, rig in rigs do
			if not model:IsDescendantOf(workspace) or rig.humanoid.Health <= 0 then remove(model); continue end
			if rig.owned and model:GetAttribute("HeroId") then
				local animate = model:FindFirstChild("Animate")
				if animate and animate:IsA("LocalScript") then
					if not rig.animate then rig.animate = animate; rig.animateEnabled = animate.Enabled end
					animate.Enabled = false
				end
			end
			local camera = workspace.CurrentCamera
			if camera and (camera.CFrame.Position - rig.root.Position).Magnitude > Config.Visual.ViewDistance and not rig.owned then continue end
			local key, at, duration = active(rig, now)
			if rig.track and rig.key ~= key then rig.track:Stop(Combat.AnimationFadeTime); rig.track = nil end
			local holding = model:GetAttribute("RasenganVisible")==true and (key=="Idle" or key=="Run")
			local published = not holding and hasPublished(rig, key, at, duration)
			rig.key = key
			if published then
				for _,entry in rig.joints do entry.joint.Transform*=Reaction.Offset(model,entry.key,now) end
				table.clear(rig.poses); continue
			end
			if not model:GetAttribute("HeroId") and (key == "Idle" or key == "Run") then
				for _, entry in rig.joints do if entry.joint.Parent then entry.joint.Transform = Reaction.Offset(model,entry.key,now) end end
				table.clear(rig.poses); continue
			end
			local pose = Poses.sample(key, now, math.clamp((now - at) / math.max(0.001, duration), 0, 1))
			if model:GetAttribute("HeroId")=="Sasuke" then pose=require(Shared.Combat.SasukePoses).sample(model,key,now,math.clamp((now-at)/math.max(.001,duration),0,1),pose) end
			if holding then pose = Poses.holdRasengan(pose,now,tostring(model:GetAttribute("RasenganVariant"))) end
			if (key == "RasenganPrepare" or key == "OdamaPrepare" or key == "RasenshurikenPrepare")
				and rig.humanoid.WalkSpeed > 0 and (rig.root.AssemblyLinearVelocity*Vector3.new(1,0,1)).Magnitude > 1.5 then
				local run = Poses.sample("Run",now,0)
				for _, joint in {"LeftHip","RightHip","LeftKnee","RightKnee"} do pose[joint] = run[joint] end
			end
			local alpha = 1 - math.exp(-Config.Visual.BlendSpeed * dt)
			for _, entry in rig.joints do
				local motor = entry.joint
				if not motor.Parent then continue end
				local angle = pose[entry.key]
				local target = if angle then CFrame.Angles(angle[1], angle[2], angle[3]) else CFrame.identity
				local current = (rig.poses[motor] or CFrame.identity):Lerp(target, alpha)
				motor.Transform = current*Reaction.Offset(model,entry.key,now); rig.poses[motor] = current
			end
		end
	end)
end
return Motion
