--!strict
-- Application layer for the limited rank-I prototype. Domain modules own timers/rules;
-- Roblox services own entities, input admission, resource transactions and world effects.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Definitions = require(Shared.Abilities.NarutoDefinitions)
local Units = require(Shared.Abilities.WorldUnits)
local Rasengan = require(Shared.Abilities.RasenganState)
local Q = Rasengan.configure(Definitions.Rasengan)
local CloneState = require(Shared.Abilities.CloneState)
local W = CloneState.configure(Definitions.Clones)
local Commands = require(Shared.Abilities.CloneCommands)
local Resource = require(Shared.Abilities.NarutoResources)
local ResourceRules = Resource.configure(Definitions.Hero, Definitions.NativeInference)
local Formulas = require(Shared.Abilities.NarutoRules).configure(Definitions)
local Fighters = require(script.Parent.FighterStateService)
local Combat = require(script.Parent.CombatService)
local Hitboxes = require(script.Parent.HitboxService)
local Damage = require(script.Parent.DamageService)
local Stats = require(script.Parent.CharacterStatsService)
local Progression = require(script.Parent.HeroProgressionService)
local Teams = require(script.Parent.TeamService)
local Summons = require(script.Parent.NarutoSummonService)
local Displacement = require(script.Parent.AbilityDisplacementService)
local GamaDomain=require(Shared.Abilities.GamakichiState)
local Gama=require(script.Parent.GamakichiService)
type Session = { gama: GamaDomain.State, q: Rasengan.State, clones: CloneState.State, commands: Commands.State, pool: Resource.Pool,
	character: Model?, target: Model?, life: number, selfStun: boolean, selfControlUntil: number,
	preparationStunned: boolean, nextPublish: number, connections: { RBXScriptConnection } }
local Service = { Visual = Instance.new("BindableEvent") }
local sessions: { [Player]: Session } = {}
local started = false
local function roundId(): number local match = Teams.GetState(); return if match then match.roundId else 0 end
local function values(player: Player): Resource.Values
	local character = player.Character
	local bonus = if character then character:GetAttribute("StrengthBonus") else nil
	return ResourceRules.values(Stats.Get(player).Level, if typeof(bonus) == "number" and bonus == bonus and math.abs(bonus) < math.huge then bonus else 0)
end
function Service.GetStats(player: Player): (number, number) return Stats.Get(player).Level, values(player).strength end
function Service.Get(player: Player): Session? return sessions[player] end
function Service.IsAbility(id: string): boolean return id == "GamakichiOil" or id == "GamakichiChop" or id == "Gamakichi" or id == "Rasengan" or id == "ShadowClones" or id == "CloneCommand" end
function Service.Ready(player: Player): { [string]: number }
	local session = sessions[player]; local toad=Gama.Get(player)
	return if session then { Rasengan = session.q.cooldownAt, ShadowClones = session.clones.cooldownAt, Gamakichi=session.gama.cooldownAt, GamakichiOil=if toad then toad.spells.oilReady else 0, GamakichiChop=if toad then toad.spells.chopReady else 0 } else {}
end
local function publish(player: Player, session: Session, now: number)
	local model = session.character; if not model or model ~= player.Character then return end
	local cast = session.q.active
	model:SetAttribute("Ready_Gamakichi",session.gama.cooldownAt)
	model:SetAttribute("GamakichiCount",if Gama.Get(player) then 1 else 0)
	model:SetAttribute("Mana", session.pool.mana); model:SetAttribute("MaxMana", session.pool.maximum)
	model:SetAttribute("Strength", values(player).strength); model:SetAttribute("NativeStatsProvisional", true)
	model:SetAttribute("Ready_Rasengan", session.q.cooldownAt); model:SetAttribute("Ready_ShadowClones", session.clones.cooldownAt)
	model:SetAttribute("RasenganPhase", if cast then cast.phase else "")
	model:SetAttribute("RasenganHeld", Q.hasMarker(session.q, now))
	model:SetAttribute("RasenganVisible", Q.hasMarker(session.q, now) and cast ~= nil and now >= cast.startedAt + Definitions.Rasengan.HandEffectDelay)
	model:SetAttribute("RasenganStartedAt", if cast then cast.startedAt else 0)
	model:SetAttribute("RasenganReadyAt", if cast then cast.readyAt else 0)
	model:SetAttribute("RasenganImpactAt", if cast then cast.impactAt or 0 else 0)
	model:SetAttribute("RasenganSelfPauseUntil", session.selfControlUntil)
	model:SetAttribute("RasenganExpiresAt", if cast then cast.expiresAt else 0)
	model:SetAttribute("NarutoCastId", session.q.serial)
	local cloneCount = 0; for _ in session.clones.clones do cloneCount += 1 end
	model:SetAttribute("NativeCloneCount", cloneCount)
	model:SetAttribute("NarutoPausedUntil", session.selfControlUntil)
	if model:GetAttribute("NativePose") == true then
		local ends = model:GetAttribute("AbilityEndsAt")
		if not cast or typeof(ends) ~= "number" or now >= ends then
			model:SetAttribute("NativePose", nil); model:SetAttribute("AbilityId", "")
		end
	end
	session.nextPublish = now + 0.1
end
local function cancelQ(player: Player, session: Session, now: number)
	Rasengan.cancel(session.q); session.target = nil; session.selfControlUntil = 0; publish(player, session, now)
end
local function selfStun(session: Session, fighter: Fighters.Fighter, now: number, duration: number)
	session.selfControlUntil = now + duration; session.selfStun = true
	Fighters.StunSpell(fighter, duration)
	session.selfStun = false
end
local function invalidate(player: Player, session: Session)
	Gama.Remove(player); GamaDomain.cancel(session.gama)
	session.life += 1; Rasengan.newLife(session.q, session.life); CloneState.newLife(session.clones, session.life)
	Commands.suspend(session.commands); session.target = nil; session.selfControlUntil = 0
	publish(player, session, workspace:GetServerTimeNow())
end
local function bind(player: Player): Session
	local existing = sessions[player]; if existing then return existing end
	local now, owner = workspace:GetServerTimeNow(), tostring(player.UserId)
	local session: Session = { gama=GamaDomain.new(), q = Rasengan.new(owner, roundId(), 0), clones = CloneState.new(owner, roundId(), 0),
		commands = Commands.new(owner, roundId(), 0), pool = Resource.new(values(player), now), character = nil, target = nil,
		life = 0, selfStun = false, selfControlUntil = 0, preparationStunned = false, nextPublish = 0, connections = {} }
	sessions[player] = session
	local function added(model: Model)
		invalidate(player, session); session.character = model; session.preparationStunned = false
		session.pool = Resource.new(values(player), workspace:GetServerTimeNow())
		Commands.newLife(session.commands, roundId(), session.life)
		publish(player, session, workspace:GetServerTimeNow())
	end
	session.connections = {
		player.CharacterAdded:Connect(added),
		player.CharacterRemoving:Connect(function(model)
			if session.character == model then invalidate(player, session); session.character = nil end
		end),
	}
	if player.Character then added(player.Character) end
	return session
end
function Service.TryCast(player: Player, id: string, requestId: number, now: number, targetValue: any): (boolean, string)
	local session = bind(player); local model = player.Character
	local fighter = if model then Fighters.GetOrCreate(model) else nil
	if not model or not fighter then return false, "Unavailable" end
	Resource.recalculate(session.pool, values(player), now)
	if id=="GamakichiOil" or id=="GamakichiChop" then return Gama.TrySpell(player,id,requestId,now,targetValue) end
	if id == "CloneCommand" then
		if typeof(targetValue) ~= "Instance" then return false, "Target" end
		local instance = targetValue :: Instance
		if not instance:IsA("Model") then return false, "Target" end
		local target = instance :: Model; local root = target:FindFirstChild("HumanoidRootPart")
		local valid = root ~= nil and root:IsA("BasePart") and Damage.CanDamage(model, target)
			and (root.Position - fighter.root.Position).Magnitude <= Units.toStuds(Definitions.Clones.RangeWarcraft)
		if not valid or not Fighters.Get(target) then return false, "Target" end
		return Commands.command(session.commands, tostring(player.UserId), roundId(), session.life, requestId, Summons.EntityId(target), true)
	end
	if fighter.logic.mode ~= "Idle" or fighter.logic.nextAttackAt > now or session.selfControlUntil > now
		or (model:GetAttribute("AbilityId") ~= nil and model:GetAttribute("AbilityId") ~= "") then return false, "Busy" end
	if id == "Gamakichi" then
        if targetValue~=nil then return false,"Malformed" end
        local profile=Progression.Get(player)
        local cast,reason,debit=GamaDomain.request(session.gama,now,requestId,if profile then profile.Learned.Gamakichi or 0 else 0,session.pool.mana)
        if not cast then return false,reason end
        assert(Resource.spend(session.pool,debit))
        Gama.Spawn(player,model,session.gama,cast,session.commands)
        publish(player,session,now); return true,"Accepted"
    elseif id == "Rasengan" then
        if Stats.Get(player).Level < Definitions.Rasengan.RequiredLevel then return false, "Level" end
		if targetValue ~= nil then return false, "Malformed" end
		local cast, reason, debit = Q.request(session.q, now, requestId, session.pool.mana, true)
		if not cast then return false, reason end
		assert(Resource.spend(session.pool, debit), "Q debit must commit without yielding")
		session.preparationStunned = false
		publish(player, session, now); return true, "Accepted"
	elseif id == "ShadowClones" then
		-- Rank I is an explicitly granted prototype capability; native learn levels remain unverified.
		local kind = "Self"
		if targetValue ~= nil then
			if typeof(targetValue) ~= "Vector3" or not Hitboxes.IsFiniteCFrame(CFrame.new(targetValue)) then return false, "UnsupportedTarget" end
			if (targetValue - fighter.root.Position).Magnitude > Units.toStuds(Definitions.Clones.RangeWarcraft) then return false, "Target" end
			kind = "Point"
		end
		if session.pool.mana < Definitions.Clones.ManaCost then return false, "Mana" end
		-- Provisional post-cost application policy, immaterial to rank-I ordinary count.
		local plan = Formulas.clonePlan(1, kind, session.pool.mana - Definitions.Clones.ManaCost, session.pool.maximum)
		assert(plan and plan.kind == "Burst")
		local burst, reason = W.begin(session.clones, now, requestId, plan.count, plan.cooldown)
		if not burst then return false, reason end
		assert(Resource.spend(session.pool, plan.nativeManaCost), "W debit must commit without yielding")
		model:SetAttribute("NativePose", true); model:SetAttribute("AbilityId", "ShadowClones")
		model:SetAttribute("AbilityStartedAt", now); model:SetAttribute("AbilityEndsAt", now + 0.25)
		publish(player, session, now); return true, "Accepted"
	end
	return false, "Unsupported"
end
function Service.Reset()
	Summons.Reset(); Gama.Reset(); Displacement.Reset()
	for player, session in sessions do
		session.gama=GamaDomain.new()
		session.life += 1; Rasengan.reset(session.q, roundId(), session.life); CloneState.reset(session.clones, roundId(), session.life)
		Commands.newLife(session.commands, roundId(), session.life); session.target = nil; session.selfControlUntil = 0
		session.pool = Resource.new(values(player), workspace:GetServerTimeNow()); publish(player, session, workspace:GetServerTimeNow())
	end
end
function Service.Update(now: number)
	for player, session in sessions do
		Resource.recalculate(session.pool, values(player), now)
		local model = session.character; local fighter = if model then Fighters.Get(model) else nil
		if model and fighter then
			if not Damage.CanAct(model) or fighter.logic.mode == "Dead" then
				if session.q.active or session.clones.burst or session.commands.active then invalidate(player, session) end
			else
				-- A lobby/temporary combat lock may have suspended intents before the
				-- round became playable. Resume only the current live owner's clean group.
				if not session.commands.active then Commands.newLife(session.commands, roundId(), session.life) end
				local cast = session.q.active
				if cast and not session.preparationStunned and now >= cast.startedAt + 1 and now < cast.readyAt then
					session.preparationStunned = true; selfStun(session, fighter, now, math.max(0, cast.readyAt - now))
				end
				Q.update(session.q, now); cast = session.q.active
				if cast then
					local targetId = Q.claimControl(session.q, cast, now)
					local target = session.target
					if targetId and target and Damage.CanDamage(model, target) then
						local targetRoot = target:FindFirstChild("HumanoidRootPart")
						if targetRoot and targetRoot:IsA("BasePart") then
							local facing = (targetRoot.Position - fighter.root.Position) * Vector3.new(1,0,1)
							if facing.Magnitude > .001 then fighter.root.CFrame = CFrame.lookAt(fighter.root.Position, fighter.root.Position + facing) end
						end
						local victim = Fighters.GetOrCreate(target)
						if victim then Fighters.StunSpell(victim, Definitions.Rasengan.Stun) end
						selfStun(session, fighter, now, Definitions.Rasengan.ImpactDelay)
						local round, life = session.q.round, session.q.life
						local consumedCast: Rasengan.Cast = cast
						Displacement.Begin(model, target, now, 2, 1, 1, 18, 0.03, function()
							return session.q.round == round and session.q.life == life and (session.q.active == consumedCast or consumedCast.impacted) and Damage.CanDamage(model, target)
						end, function() Service.Visual:Fire({kind="RasenganFinish",position=target:GetPivot().Position}) end,
						function() Service.Visual:Fire({kind="RasenganTrail",position=target:GetPivot().Position}) end)
					end
					local impacted = Q.claimImpact(session.q, cast, now)
					if impacted and target then
						local humanoid = target:FindFirstChildOfClass("Humanoid")
						local level, strength = Service.GetStats(player); local raw = Formulas.rasenganDamage(level, strength)
						if humanoid and raw then
							Damage.Apply(model, humanoid, raw)
						end
						session.target = nil
					end
				end
				local burst = session.clones.burst
				if burst then
					local clone = W.spawnOne(session.clones, burst, now, true, Q.hasMarker(session.q, now))
					if clone then Summons.Spawn(player, model, session.clones, clone, session.commands) end
				end
			end
		end
		CloneState.expire(session.clones, now)
		if now >= session.nextPublish then publish(player, session, now) end
	end
	Displacement.Update(now)
end
function Service.Start()
	if started then return end; started = true
 Gama.Visual.Event:Connect(function(message) Service.Visual:Fire(message) end)
	Players.PlayerAdded:Connect(function(player) bind(player) end)
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]; if not session then return end
		Gama.Remove(player)
		invalidate(player, session); Summons.ClearOwner(player)
		for _, connection in session.connections do connection:Disconnect() end
		sessions[player] = nil
	end)
	Progression.Changed.Event:Connect(function(player: Player, reason: string)
		local session = sessions[player]; if not session then return end
		if reason == "Reset" then session.pool = Resource.new(values(player), workspace:GetServerTimeNow()) end
	end)
	Fighters.Changed.Event:Connect(function(fighter: Fighters.Fighter)
		local player = fighter.player; local session = if player then sessions[player] else nil
		if player and session and session.character == fighter.character and not session.selfStun then
			if fighter.logic.mode == "Dead" then invalidate(player, session)
			elseif fighter.logic.mode == "Stunned" then cancelQ(player, session, workspace:GetServerTimeNow()) end
		end
	end)
	Combat.AttackStarted.Event:Connect(function(fighter: Fighters.Fighter)
		local player = fighter.player; local session = if player then sessions[player] else nil
		if not player or not session then return end
		local candidates = Hitboxes.GetTargets(fighter.character, fighter.root, fighter.profile)
		local chosen: Model? = nil; local nearest = math.huge
		for _, humanoid in candidates do
			local target = humanoid.Parent
			if target and target:IsA("Model") and not target:FindFirstChildOfClass("ForceField") and Damage.CanDamage(fighter.character, target) then
				local root = target:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local distance = (root.Position - fighter.root.Position).Magnitude
					if distance < nearest then nearest = distance; chosen = target end
				end
			end
		end
		if chosen then Commands.assist(session.commands, Summons.EntityId(chosen), true) end
		local cast = session.q.active
		local targetRoot = if chosen then chosen:FindFirstChild("HumanoidRootPart") else nil
		if cast and chosen and targetRoot and targetRoot:IsA("BasePart")
			and nearest <= Units.toStuds(50) + (fighter.root.Size.X + targetRoot.Size.X) / 2 then
			local kind = chosen:GetAttribute("EntityKind")
			if Q.attack(session.q, cast, workspace:GetServerTimeNow(), Summons.EntityId(chosen), true, kind ~= "Hero" and kind ~= "Minion" and kind ~= "Summon") then
				session.target = chosen; session.selfControlUntil = workspace:GetServerTimeNow() + 0.01 + Definitions.Rasengan.ImpactDelay
				publish(player, session, workspace:GetServerTimeNow())
			end
		end
	end)
	local last = workspace:GetServerTimeNow()
	game:GetService("RunService").Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow(); local delta = math.max(0, now - last); last = now
		Summons.Update(now, delta, Service.GetStats)
		Gama.Update(now,delta)
	end)
	for _, player in Players:GetPlayers() do bind(player) end
end
return Service
