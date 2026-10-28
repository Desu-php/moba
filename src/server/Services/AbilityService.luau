--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.AbilityConfig)
local Heroes = require(Shared.Config.HeroConfig)
local Rules = require(Shared.Combat.AbilityState)
local Structures = require(Shared.Game.StructureRules)
local Fighters = require(script.Parent.FighterStateService)
local Damage = require(script.Parent.DamageService)
local Stats = require(script.Parent.CharacterStatsService)
local Targets = require(script.Parent.AbilityTargetService)
local Hitboxes = require(script.Parent.HitboxService)
local Knockback = require(script.Parent.KnockbackService)
local Clones = require(script.Parent.CloneService)
local Limiter = require(script.Parent.RequestLimiter)
local Teams = require(script.Parent.TeamService)
local RoundProtocol = require(Shared.Game.RoundProtocol)
type Session = { state: Rules.State, character: Model?, bucket: Limiter.Bucket, lastId: number, lastReply: number,
	connections: { RBXScriptConnection } }
local Ability = {}
local sessions: { [Player]: Session } = {}
local remote: RemoteEvent? = nil
local started = false
local function sendAll(message: any)
	local match = Teams.GetState(); if not remote or not match then return end
	message.roundId = match.roundId; remote:FireAllClients(message)
end
local function publish(session: Session)
	-- CharacterAdded may precede parenting to Workspace on a cached respawn.
	local model = session.character; if not model then return end
	local cast = session.state.active
	model:SetAttribute("AbilityId", if cast then cast.abilityId else "")
	model:SetAttribute("AbilityCastId", session.state.serial)
	model:SetAttribute("AbilityStartedAt", if cast then cast.startedAt else 0)
	model:SetAttribute("AbilityEndsAt", if cast then cast.endsAt else 0)
	for _, id in Config.Order do model:SetAttribute("Ready_" .. id, session.state.ready[id] or 0) end
end
local function cancel(session: Session)
	Rules.cancel(session.state); publish(session)
end
local function bind(player: Player): Session
	local existing = sessions[player]; if existing then return existing end
	local session: Session = { state = Rules.new(0), character = nil, bucket = Limiter.new(Config.Burst, Config.RequestsPerSecond, workspace:GetServerTimeNow()),
		lastId = 0, lastReply = 0, connections = {} }
	sessions[player] = session
	local function added(model: Model)
		cancel(session); Clones.ClearOwner(player)
		session.character = model; Rules.newLife(session.state, session.state.life + 1); publish(session)
	end
	session.connections = {
		player.CharacterAdded:Connect(added),
		player.CharacterRemoving:Connect(function(model)
			if session.character == model then cancel(session); session.character = nil; Clones.ClearOwner(player) end
		end),
	}
	if player.Character then added(player.Character) end
	return session
end
local function eligible(player: Player, model: Model): boolean
	local match = Teams.GetState()
	return player.Character == model and match ~= nil and match.phase == "InProgress"
		and player:GetAttribute("Eliminated") ~= true and Teams.IsActive(Teams.GetId(model)) and Damage.CanAct(model)
end
local function result(player: Player, session: Session, id: number, accepted: boolean, reason: string)
	local now = workspace:GetServerTimeNow()
	if not accepted and now - session.lastReply < Config.ReplyInterval then return end
	session.lastReply = now
	local match = Teams.GetState()
	if remote then remote:FireClient(player, { kind = "Result", requestId = id, character = player.Character, roundId = if match then match.roundId else nil,
		accepted = accepted, reason = reason, ready = table.clone(session.state.ready) }) end
end
function Ability.TryCast(player: Player, ...: any): (boolean, string)
	if player.Parent ~= Players then return false, "Unavailable" end
	local session = bind(player); local now = workspace:GetServerTimeNow()
	local allowed = Limiter.Consume(session.bucket, now)
	local id, value, abilityId = ...
	local valid = typeof(id) == "number" and id == id and id >= 1 and id <= Config.MaxRequestId and id % 1 == 0
	if not valid then return false, "Malformed" end
	local function reject(reason: string): (boolean, string) result(player, session, id, false, reason); return false, reason end
	if not allowed then return reject("RateLimited") end
	if select("#", ...) ~= 3 or typeof(value) ~= "Instance" then return reject("Malformed") end
	local instance = value :: Instance
	if not instance:IsA("Model") or instance ~= player.Character
		or typeof(abilityId) ~= "string" or #abilityId > 32 or not Config.Abilities[abilityId] then return reject("Malformed") end
	if id <= session.lastId then return reject("Replay") end; session.lastId = id
	local model = value :: Model
	local heroId = model:GetAttribute("HeroId")
	local hero = if typeof(heroId) == "string" then Heroes.Heroes[heroId] else nil
	if not hero or heroId ~= player:GetAttribute("HeroId") or not table.find(hero.Abilities, abilityId) then return reject("Hero") end
	local fighter = Fighters.GetOrCreate(model)
	if not fighter or not eligible(player, model) or fighter.root.Anchored or not fighter.root:IsDescendantOf(model)
		or fighter.humanoid:GetState() == Enum.HumanoidStateType.Dead or not Hitboxes.IsFiniteCFrame(fighter.root.CFrame) then return reject("Unavailable") end
	Fighters.Update(fighter, now)
	local cast, reason = Rules.request(session.state, abilityId, Config.Abilities[abilityId], now, id, fighter.logic.mode, fighter.logic.nextAttackAt, true)
	if not cast then return reject(reason) end
	fighter.logic.buffered = nil
	fighter.logic.nextAttackAt = math.max(fighter.logic.nextAttackAt, cast.endsAt)
	publish(session); Fighters.Publish(fighter)
	result(player, session, id, true, "Accepted")
	return true, "Accepted"
end
local function deal(fighter: Fighters.Fighter, humanoid: Humanoid, damage: number, stun: number, push: number, lift: number): number
	local target = humanoid.Parent; if not target or not target:IsA("Model") then return 0 end
	local stats = Stats.GetForModel(fighter.character)
	local dealt = Damage.Apply(fighter.character, humanoid, damage * (if stats then stats.AttackDamageMultiplier else 1))
	if dealt > 0 and not Structures.isStructure(target:GetAttribute("EntityKind")) and humanoid.Health > 0 then
		local victim = Fighters.GetOrCreate(target)
		if victim then Fighters.Stun(victim, stun, false); Knockback.Apply(fighter.root, victim.root, fighter.profile, push, lift) end
	end
	return dealt
end
local function impact(player: Player, session: Session, cast: Rules.Cast, fighter: Fighters.Fighter, now: number)
	if cast.abilityId == "SpiralSphere" then
		-- A short melee contact window catches a target entering the extended palm; one cast still deals damage once.
		if not Rules.contactOpen(session.state, cast, now, Config.Sphere.ContactWindow) then return end
		local humanoid = Targets.Nearest(fighter.character, fighter.root.CFrame, Config.Sphere.Range, Config.Sphere.ForwardDot, true)
		if not humanoid or not Rules.claim(session.state, cast, now) then return end
		local target = humanoid.Parent; if not target or not target:IsA("Model") then return end
		local dealt = deal(fighter, humanoid, Config.Sphere.Damage, Config.Sphere.Stun, Config.Sphere.Knockback, Config.Sphere.UpVelocity)
		if dealt <= 0 then return end
		sendAll({ kind = "SphereHit", position = target:GetPivot().Position, character = fighter.character, castId = cast.id, damage = dealt })
	elseif Rules.claim(session.state, cast, now) then
		if cast.abilityId == "ShadowClones" then Clones.Spawn(player, fighter.character)
		elseif cast.abilityId == "WindPalm" then
			local wind = Config.Wind
			for _, humanoid in Targets.InCone(fighter.character, fighter.root.CFrame, wind.Range, wind.ForwardDot, false, wind.MaxTargets) do
				deal(fighter, humanoid, wind.Damage, wind.Stun, wind.Knockback, wind.UpVelocity)
			end
			local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { fighter.character }; params.RespectCanCollide = true
			local wall = workspace:Raycast(fighter.root.Position, fighter.root.CFrame.LookVector * wind.Range, params)
			sendAll({ kind = "WindBurst", frame = fighter.root.CFrame, distance = if wall then wall.Distance else wind.Range })
		end
	end
end
function Ability.Update(now: number)
	for player, session in sessions do
		local model, cast = session.character, session.state.active
		if not cast then continue end
		local fighter = if model then Fighters.Get(model) else nil
		if not model or not fighter or not eligible(player, model) or not fighter.root:IsDescendantOf(model) or not Hitboxes.IsFiniteCFrame(fighter.root.CFrame)
			or fighter.logic.mode == "Stunned" or fighter.logic.mode == "Dead" then cancel(session); continue end
		impact(player, session, cast, fighter, now)
		if Rules.finish(session.state, cast, now) then
			publish(session)
		end
	end
	Clones.Update(now)
end
function Ability.Reset()
	for player, session in sessions do cancel(session); table.clear(session.state.ready); publish(session); Clones.ClearOwner(player) end
	Clones.Reset()
end
function Ability.HandleRequest(player: Player, ...: any): (boolean, string)
	local args = table.pack(...)
	local match = Teams.GetState()
	if not match or not RoundProtocol.accepts(match.roundId, args[args.n]) then return false, "StaleRound" end
	return Ability.TryCast(player, table.unpack(args, 1, args.n - 1))
end
function Ability.GetState(player: Player): Rules.State? local session = sessions[player]; return if session then session.state else nil end
function Ability.Start()
	if started then return end; started = true
	local event = Instance.new("RemoteEvent"); event.Name = "HeroAbility"; event.Parent = ReplicatedStorage; remote = event
	event.OnServerEvent:Connect(function(player, ...: any) Ability.HandleRequest(player, ...) end)
	Players.PlayerAdded:Connect(function(player) bind(player) end)
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]; if not session then return end
		cancel(session); for _, connection in session.connections do connection:Disconnect() end; sessions[player] = nil
	end)
	Fighters.Changed.Event:Connect(function(fighter: Fighters.Fighter)
		local player = fighter.player; local session = if player then sessions[player] else nil
		if session and session.character == fighter.character and (fighter.logic.mode == "Stunned" or fighter.logic.mode == "Dead") then
			cancel(session)
			if player and fighter.logic.mode == "Dead" then Clones.ClearOwner(player) end
		end
	end)
	Clones.Spawned.Event:Connect(function(model: Model)
		local match = Teams.GetState()
		if match and model.Parent and model:GetAttribute("RoundId") == match.roundId then sendAll({ kind = "Smoke", position = model:GetPivot().Position }) end
	end)
	for _, player in Players:GetPlayers() do bind(player) end
	RunService.Heartbeat:Connect(function() Ability.Update(workspace:GetServerTimeNow()) end)
end
return Ability
