--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.CombatConfig)
local Debug = require(Shared.Config.DebugConfig)
local Protocol = require(Shared.Combat.CombatProtocol)
local State = require(Shared.Combat.CombatState)
local Fighters = require(script.Parent.FighterStateService)
local Hitboxes = require(script.Parent.HitboxService)
local Knockback = require(script.Parent.KnockbackService)
local RequestLimiter = require(script.Parent.RequestLimiter)
local Damage = require(script.Parent.DamageService)
local Stats = require(script.Parent.CharacterStatsService)

type Session = { bucket: RequestLimiter.Bucket, lastRequestId: number, lastRejectAt: number }
local CombatService = {}
local sessions: { [Player]: Session } = {}
local eventRemote: RemoteEvent? = nil
local started = false

local function broadcastState(fighter: Fighters.Fighter)
	local remote = eventRemote
	if remote then
		remote:FireAllClients({ kind = "State", snapshot = Fighters.Snapshot(fighter) })
	end
end

local function reject(player: Player, requestId: number, character: Model?, reason: string)
	local remote = eventRemote
	if not remote then return end
	local fighter = if character then Fighters.Get(character) else nil
	remote:FireClient(player, {
		kind = "Rejected", requestId = requestId, character = character, reason = reason,
		snapshot = if fighter then Fighters.Snapshot(fighter) else nil,
	})
end

local function announceStart(fighter: Fighters.Fighter)
	local attack, remote = fighter.logic.active, eventRemote
	if not attack or not remote then return end
	Fighters.Publish(fighter)
	remote:FireAllClients({ kind = "Started", snapshot = Fighters.Snapshot(fighter), attack = attack })
	if Debug.LogCombat then
		print(string.format("[Combat] %s M1-%d request=%d", fighter.character.Name, attack.step, attack.requestId))
	end
end

local function canAttack(fighter: Fighters.Fighter): boolean
	return fighter.character:IsDescendantOf(Workspace)
		and Damage.CanAct(fighter.character)
		and fighter.humanoid.Health > 0
		and fighter.humanoid:GetState() ~= Enum.HumanoidStateType.Dead
		and fighter.root:IsDescendantOf(fighter.character)
		and not fighter.root.Anchored
		and Hitboxes.IsFiniteCFrame(fighter.root.CFrame)
end

-- Only request identity and the exact current character may come from the client.
function CombatService.TryAttack(player: Player, ...: any): string
	if player.Parent ~= Players then return "Rejected" end
	local now = Workspace:GetServerTimeNow()
	local session = sessions[player]
	if not session then
		session = {
			bucket = RequestLimiter.new(Config.RemoteLimit.Burst, Config.RemoteLimit.RequestsPerSecond, now),
			lastRequestId = 0, lastRejectAt = 0,
		}
		sessions[player] = session
	end
	local allowed = RequestLimiter.Consume(session.bucket, now)
	local requestId, characterValue = ...
	local validId = typeof(requestId) == "number" and requestId == requestId
		and requestId >= 1 and requestId <= Config.MaxRequestId and requestId % 1 == 0
	if not validId then return "Rejected" end
	if not allowed then
		if now - session.lastRejectAt >= Config.RemoteLimit.RejectReplyInterval then
			session.lastRejectAt = now
			reject(player, requestId, player.Character, "RateLimited")
		end
		return "Rejected"
	end
	if select("#", ...) ~= 2 or typeof(characterValue) ~= "Instance" then
		reject(player, requestId, player.Character, "Malformed")
		return "Rejected"
	end
	local character = characterValue :: Instance
	if not character:IsA("Model") or character ~= player.Character then
		reject(player, requestId, player.Character, "Malformed")
		return "Rejected"
	end
	if requestId <= session.lastRequestId then
		reject(player, requestId, character, "Replay")
		return "Rejected"
	end
	session.lastRequestId = requestId
	local fighter = Fighters.GetOrCreate(character)
	if not fighter or not canAttack(fighter) then
		reject(player, requestId, character, "Unavailable")
		return "Rejected"
	end
	Fighters.Update(fighter, now)
	local result, reason = State.Request(fighter.logic, fighter.profile, now, requestId)
	if result == "Started" then
		announceStart(fighter)
	elseif result == "Buffered" then
		local remote = eventRemote
		if remote then remote:FireClient(player, { kind = "Buffered", requestId = requestId, snapshot = Fighters.Snapshot(fighter) }) end
	else
		reject(player, requestId, character, reason or "Unavailable")
	end
	return result
end

local function resolveHit(fighter: Fighters.Fighter, attack: State.Attack)
	if not canAttack(fighter) then return end
	local profile = fighter.profile
	local targets, box, size = Hitboxes.GetTargets(fighter.character, fighter.root, profile)
	local hits = {}
	local heavy = attack.step == #profile.DamageByComboStep
	local stats = Stats.GetForModel(fighter.character)
	local multiplier = if stats then stats.AttackDamageMultiplier else 1
	for _, humanoid in targets do
		local character = humanoid.Parent
		if not character or not character:IsA("Model") then continue end
		local isBase = character:GetAttribute("EntityKind") == "Base"
		local victim = if isBase then nil else Fighters.GetOrCreate(character)
		if not isBase and not victim then continue end
		local dealt = Damage.Apply(fighter.character, humanoid, profile.DamageByComboStep[attack.step] * multiplier)
		-- ForceField-protected targets must not be stunned or pushed.
		if dealt <= 0 then continue end
		local position = character:GetPivot().Position
		table.insert(hits, { character = character, position = position })
		if victim and humanoid.Health > 0 then
			Fighters.Stun(victim, if heavy then profile.FinisherStunDuration else profile.HitStunDuration, heavy)
			if heavy then Knockback.Apply(fighter.root, victim.root, profile) end
		end
	end
	local remote = eventRemote
	if remote then
		remote:FireAllClients({
			kind = "Hit", snapshot = Fighters.Snapshot(fighter), attackId = attack.id,
			step = attack.step, hits = hits,
			hitboxCFrame = if Debug.DebugHitboxes then box else nil,
			hitboxSize = if Debug.DebugHitboxes then size else nil,
		})
	end
end

local function heartbeat()
	local now = Workspace:GetServerTimeNow()
	for character, fighter in Fighters.GetAll() do
		if not character:IsDescendantOf(Workspace) then
			Fighters.Remove(character)
			continue
		end
		Fighters.Update(fighter, now)
		local attack = State.ClaimHit(fighter.logic, now)
		if attack then resolveHit(fighter, attack) end
		local requestId, valid = State.TakeBuffer(fighter.logic, now)
		if requestId then
			if valid and canAttack(fighter) then
				local result = State.Request(fighter.logic, fighter.profile, now, requestId)
				if result == "Started" then announceStart(fighter) end
			elseif fighter.player then
				reject(fighter.player, requestId, character, "BufferExpired")
			end
		end
	end
end

function CombatService.Start()
	if started then return end
	local existingFolder = ReplicatedStorage:FindFirstChild(Protocol.FolderName)
	assert(not existingFolder or existingFolder:IsA("Folder"), "CombatRemotes must be a Folder")
	local folder = existingFolder or Instance.new("Folder")
	folder.Name = Protocol.FolderName
	local function makeRemote(name: string): RemoteEvent
		local existing = folder:FindFirstChild(name)
		assert(not existing or existing:IsA("RemoteEvent"), name .. " must be a RemoteEvent")
		local remote = (existing or Instance.new("RemoteEvent")) :: RemoteEvent
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	local request = makeRemote(Protocol.BasicAttackName)
	eventRemote = makeRemote(Protocol.EventName)
	request.OnServerEvent:Connect(function(player: Player, ...: any)
		CombatService.TryAttack(player, ...)
	end)
	Players.PlayerRemoving:Connect(function(player: Player) sessions[player] = nil end)
	Fighters.Changed.Event:Connect(broadcastState)
	Fighters.Start()
	RunService.Heartbeat:Connect(heartbeat)
	started = true
	folder.Parent = ReplicatedStorage
end

return CombatService
