--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.CombatConfig)
local Debug = require(Shared.Config.DebugConfig)
local Protocol = require(Shared.Combat.CombatProtocol)
local Animations = require(script.Parent.AnimationController)
local VFX = require(script.Parent.VFXController)

type Pending = { id: number, step: number, sentAt: number, startAt: number, played: boolean, character: Model }
local CombatController = {}
local attackRemote: RemoteEvent? = nil
local snapshot: Protocol.Snapshot? = nil
local pending: Pending? = nil
local requestSerial = 0
local localNextAttackAt = 0
local localStep = 0
local localLastAttackAt = 0
local queuedUntil = 0
local currentProfile = Config.Profiles[Config.DefaultProfile]
local seenStarted: { [Model]: number } = setmetatable({}, { __mode = "k" })
local seenHits: { [Model]: number } = setmetatable({}, { __mode = "k" })
local abilityConnection: RBXScriptConnection? = nil

function CombatController.NextRequestId(): number
	requestSerial += 1
	assert(requestSerial <= Config.MaxRequestId, "Combat request ID limit reached")
	return requestSerial
end

local function reset()
	Animations.Stop()
	snapshot, pending = nil, nil
	localNextAttackAt, localStep, localLastAttackAt, queuedUntil = 0, 0, 0, 0
	currentProfile = Config.Profiles[Config.DefaultProfile]
end

local function reconcile(incoming: Protocol.Snapshot): boolean
	if incoming.character ~= Players.LocalPlayer.Character then return false end
	if snapshot and incoming.revision < snapshot.revision then return false end
	snapshot = incoming
	local profiles: { read [string]: Config.AttackProfile } = Config.Profiles
	currentProfile = profiles[incoming.profileId] or Config.Profiles[Config.DefaultProfile]
	localNextAttackAt = incoming.nextAttackAt
	localStep = incoming.comboStep
	localLastAttackAt = incoming.lastAttackAt
	if incoming.mode == "Stunned" or incoming.mode == "Dead" then
		Animations.Stop()
		pending = nil
		queuedUntil = 0
	end
	return true
end

local function playPrediction(intent: Pending)
	if intent.played then return end
	intent.played = true
	Animations.Play(intent.id, intent.step, currentProfile, intent.startAt)
	VFX.Swing(intent.character, intent.step)
end

local function onEvent(message: Protocol.Event)
	local incoming = message.snapshot
	local character = if incoming then incoming.character else message.character
	if message.kind == "Rejected" then
		if incoming then reconcile(incoming) end
		if pending and pending.id == message.requestId and character == pending.character then
			Animations.Stop(pending.id)
			pending = nil
			queuedUntil = 0
			localNextAttackAt = if snapshot then snapshot.nextAttackAt else workspace:GetServerTimeNow()
		end
		return
	end
	if not incoming or not character then return end
	local localCharacter = character == Players.LocalPlayer.Character
	if localCharacter and not reconcile(incoming) then return end

	if message.kind == "Buffered" then
		-- Keep one pending intent. It is played at the due time, never at the early click.
		if pending and pending.id == message.requestId then pending.startAt = incoming.nextAttackAt end
	elseif message.kind == "Started" then
		local attack = message.attack
		if not attack or (seenStarted[character] or 0) >= attack.id then return end
		seenStarted[character] = attack.id
		if localCharacter then
			local predicted = pending
			local alreadyPlayed = predicted and predicted.id == attack.requestId and predicted.played and predicted.step == attack.step
			Animations.Play(attack.requestId, attack.step, currentProfile, attack.startedAt)
			if not alreadyPlayed and workspace:GetServerTimeNow() < attack.endsAt then VFX.Swing(character, attack.step) end
			if predicted and predicted.id == attack.requestId then pending = nil end
		else
			VFX.Swing(character, attack.step)
		end
		if Debug.LogCombat then print(string.format("[Combat] confirmed %s M1-%d", character.Name, attack.step)) end
	elseif message.kind == "Hit" then
		local attackId, step, hits = message.attackId, message.step, message.hits
		if not attackId or not step or not hits or (seenHits[character] or 0) >= attackId then return end
		seenHits[character] = attackId
		local profiles: { read [string]: Config.AttackProfile } = Config.Profiles
		local profile = profiles[incoming.profileId] or Config.Profiles[Config.DefaultProfile]
		local heavy = step == #profile.DamageByComboStep
		for _, hit in hits do
			if hit.character.Parent then VFX.Hit(hit.character, hit.position, heavy) end
		end
		if localCharacter and #hits > 0 then VFX.Shake(heavy) end
		if message.hitboxCFrame and message.hitboxSize then VFX.DebugBox(message.hitboxCFrame, message.hitboxSize) end
	end
end

function CombatController.TryAttack(): boolean
	local remote = attackRemote
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not remote or not character or not humanoid or humanoid.Health <= 0 then return false end
	if character:GetAttribute("CombatDisabled") == true then return false end
	if character:GetAttribute("AbilityId") and character:GetAttribute("AbilityId") ~= "" then return false end
	local match = ReplicatedStorage:FindFirstChild("SurvivalState")
	if match and match:GetAttribute("Phase") ~= "InProgress" then return false end
	local now = workspace:GetServerTimeNow()
	local authoritative = snapshot
	if not authoritative then
		currentProfile = Config.Profiles[tostring(character:GetAttribute("CombatProfileId"))] or currentProfile
	end
	if authoritative and (authoritative.mode == "Dead" or (authoritative.mode == "Stunned" and now < authoritative.stunUntil)) then return false end
	if not authoritative and character:GetAttribute("CombatState") == "Stunned" then return false end
	if pending then
		-- Only an additional real click near recovery can occupy this one local slot.
		if queuedUntil == 0 and now >= localNextAttackAt - currentProfile.InputBufferWindow and now <= localNextAttackAt then
			queuedUntil = localNextAttackAt + currentProfile.InputBufferWindow
		end
		return false
	end
	if now < localNextAttackAt - currentProfile.InputBufferWindow then return false end
	local step = if localStep >= #currentProfile.DamageByComboStep or now - localLastAttackAt >= currentProfile.ComboResetTime then 1 else localStep + 1
	local dueAt = math.max(now, localNextAttackAt)
	local intent: Pending = {
		id = CombatController.NextRequestId(), step = step, sentAt = now,
		startAt = dueAt, played = false, character = character,
	}
	pending = intent
	queuedUntil = 0
	if dueAt <= now then
		playPrediction(intent)
		localStep = step
		localLastAttackAt = now
		localNextAttackAt = now + (if step == #currentProfile.DamageByComboStep then currentProfile.FinisherCooldown else currentProfile.AttackCooldown)
	end
	remote:FireServer(intent.id, character)
	return true
end

function CombatController.GetDiagnostics()
	return { comboStep = localStep, pendingRequestId = if pending then pending.id else 0, queued = queuedUntil > 0 }
end

function CombatController.Start()
	if attackRemote then return end
	local folder = ReplicatedStorage:WaitForChild(Protocol.FolderName, Config.CharacterReadyTimeout)
	assert(folder, "CombatRemotes missing: check Server/Main")
	local request = folder:WaitForChild(Protocol.BasicAttackName, Config.CharacterReadyTimeout)
	local events = folder:WaitForChild(Protocol.EventName, Config.CharacterReadyTimeout)
	assert(request and request:IsA("RemoteEvent") and events and events:IsA("RemoteEvent"), "Combat protocol v2 remotes missing")
	attackRemote = request
	VFX.Start()
	Animations.Start(function()
		local character = Players.LocalPlayer.Character
		if character then VFX.Swing(character, localStep) end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(reset)
	Players.LocalPlayer.CharacterRemoving:Connect(reset)
	local function bindAbilities(character: Model)
		if abilityConnection then abilityConnection:Disconnect() end
		abilityConnection = character:GetAttributeChangedSignal("AbilityId"):Connect(function()
			if character ~= Players.LocalPlayer.Character then return end
			if character:GetAttribute("AbilityId") ~= "" then Animations.Stop(); pending = nil; queuedUntil = 0 end
		end)
	end
	Players.LocalPlayer.CharacterAdded:Connect(bindAbilities)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		if abilityConnection then abilityConnection:Disconnect(); abilityConnection = nil end
	end)
	if Players.LocalPlayer.Character then bindAbilities(Players.LocalPlayer.Character) end
	events.OnClientEvent:Connect(onEvent)
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		local intent = pending
		if intent then
			if intent.character ~= Players.LocalPlayer.Character or now - intent.sentAt > Config.PredictionTimeout then
				Animations.Stop(intent.id)
				pending = nil
				queuedUntil = 0
				localNextAttackAt = if snapshot then snapshot.nextAttackAt else now
			elseif not intent.played and now >= intent.startAt then
				playPrediction(intent)
			end
		elseif queuedUntil > 0 then
			if now > queuedUntil then
				queuedUntil = 0
			elseif now >= localNextAttackAt - currentProfile.InputBufferWindow then
				queuedUntil = 0
				CombatController.TryAttack()
			end
		end
	end)
end

return CombatController
