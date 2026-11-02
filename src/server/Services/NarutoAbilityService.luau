--!strict
-- Application layer for source-derived base melee variants. Domain modules own timers/rules;
-- Roblox services own entities, input admission, resource transactions and world effects.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Definitions = require(Shared.Abilities.NarutoDefinitions)
local Units = require(Shared.Abilities.WorldUnits)
local Rasengan = require(Shared.Abilities.RasenganState)
local Q = Rasengan.configure(Definitions.Rasengan)
local Variants=require(Shared.Abilities.RasenganVariants)
local Sleep=require(script.Parent.NarutoSleepService)
local Shuriken=require(script.Parent.RasenshurikenMeleeService)
local CloneState = require(Shared.Abilities.CloneState)
local W = CloneState.configure(Definitions.Clones)
local Commands = require(Shared.Abilities.CloneCommands)
local Resource = require(Shared.Abilities.NarutoResources)
local ResourceRules = Resource.configure(Definitions.Hero, Definitions.NativeInference)

local Fighters = require(script.Parent.FighterStateService)
local Combat = require(script.Parent.CombatService)
local Hitboxes = require(script.Parent.HitboxService)
local Damage = require(script.Parent.DamageService)
local Stats = require(script.Parent.CharacterStatsService)
local Progression = require(script.Parent.HeroProgressionService)
local Teams = require(script.Parent.TeamService)
local Summons = require(script.Parent.NarutoSummonService)
local Displacement = require(script.Parent.AbilityDisplacementService)
local RankPolicy=require(Shared.Abilities.NarutoRankPolicy)
local ClonePlan=require(Shared.Abilities.CloneCastPlan)
local Sage=require(Shared.Abilities.SageState)
local Meditation=require(Shared.Abilities.MeditationState)
local MeditationClones=require(script.Parent.MeditationCloneService)
local GamaDomain=require(Shared.Abilities.GamakichiState)
local Gama=require(script.Parent.GamakichiService)
local Kcm=require(script.Parent.NarutoKcmService)
local Kurama=require(script.Parent.NarutoKuramaService)
type Session = { variants: Variants.State, shurikenSnapshot: number, meditation: Meditation.State, meditationMode: boolean, meditationRecallAt: number, sage: Sage.State, gama: GamaDomain.State, q: Rasengan.State, clones: CloneState.State, commands: Commands.State, pool: Resource.Pool,
	character: Model?, target: Model?, life: number, selfStun: boolean, selfControlUntil: number,
	preparationStunned: boolean, nextPublish: number, connections: { RBXScriptConnection } }
local Service = { Visual = Instance.new("BindableEvent") }
local sessions: { [Player]: Session } = {}
local started = false
-- KCM worker injects its authoritative current form, without dependency cycles.
-- Called at clone creation; existing clones retain their original profile on morph.
local meditationForm: (Player)->Meditation.Form = function(_player) return "Ordinary" end
function Service.ConfigureMeditationForms(provider: (Player)->Meditation.Form) meditationForm=provider end
local function roundId(): number local match = Teams.GetState(); return if match then match.roundId else 0 end
local function values(player: Player): Resource.Values
	local character = player.Character
	local bonus = if character then character:GetAttribute("StrengthBonus") else nil
	return ResourceRules.values(Stats.Get(player).Level, if typeof(bonus) == "number" and bonus == bonus and math.abs(bonus) < math.huge then bonus else 0)
end
function Service.GetStats(player: Player): (number, number) return Stats.Get(player).Level, values(player).strength end
function Service.Get(player: Player): Session? return sessions[player] end
function Service.IsAbility(id: string): boolean return Kcm.IsAbility(id) or id == "MeditationToggle" or id == "MeditationRecall" or id == "ShadowSleep" or id == "Odama" or id == "Rasenshuriken" or id == "SageMode" or id == "GamakichiOil" or id == "GamakichiChop" or id == "Gamakichi" or id == "Rasengan" or id == "ShadowClones" or id == "CloneCommand" end
function Service.Ready(player: Player): { [string]: number }
	local session = sessions[player]; local toad=Gama.Get(player)
	return if session then { KuramaForm=if player.Character then (player.Character:GetAttribute("Ready_KuramaForm") or 0) :: number else 0, KCM=if player.Character then (player.Character:GetAttribute("Ready_KCM") or 0) :: number else 0, KcmDash=if player.Character then (player.Character:GetAttribute("Ready_KcmDash") or 0) :: number else 0, MeditationRecall=session.meditationRecallAt, Odama=session.variants.cooldowns.Odama or 0, Rasenshuriken=session.variants.cooldowns.Rasenshuriken or 0, SageMode=session.sage.cooldownAt, Rasengan = session.q.cooldownAt, ShadowClones = session.clones.cooldownAt, Gamakichi=session.gama.cooldownAt, GamakichiOil=if toad then toad.spells.oilReady else 0, GamakichiChop=if toad then toad.spells.chopReady else 0 } else {}
end
local function publish(player: Player, session: Session, now: number)
	local model = session.character; if not model or model ~= player.Character then return end
	local cast = session.q.active
	local sage=session.sage.active
 model:SetAttribute("MeditationMode",session.meditationMode)
 model:SetAttribute("Ready_MeditationRecall",session.meditationRecallAt)
 local meditationCount=0; for _ in session.meditation.clones do meditationCount+=1 end
 model:SetAttribute("MeditationCloneCount",meditationCount)
 model:SetAttribute("SageHealthProvisional",sage~=nil and sage.rank==3)
 model:SetAttribute("RasenganVariant",if cast then cast.variant else "")
 model:SetAttribute("RasenganVariantUntil",if cast and cast.variant~="Rasenshuriken" then cast.startedAt+1 else 0)
 model:SetAttribute("Ready_Odama",session.variants.cooldowns.Odama or 0)
 model:SetAttribute("Ready_Rasenshuriken",session.variants.cooldowns.Rasenshuriken or 0)
 model:SetAttribute("Ready_SageMode",session.sage.cooldownAt)
 model:SetAttribute("SagePhase",if sage then sage.phase else "")
 model:SetAttribute("SageRank",if sage then sage.rank else 0)
 model:SetAttribute("SageReadyAt",if sage then sage.readyAt else 0)
 model:SetAttribute("SageExpiresAt",if sage then sage.expiresAt else 0)
 model:SetAttribute("SageAuraUntil",if sage then sage.auraUntil else 0)
 if sage then game:GetService("CollectionService"):AddTag(model,"NarutoSage") else game:GetService("CollectionService"):RemoveTag(model,"NarutoSage") end
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
	Variants.cancel(session.variants); Rasengan.cancel(session.q); session.target = nil; session.selfControlUntil = 0; publish(player, session, now)
end
local function selfStun(session: Session, fighter: Fighters.Fighter, now: number, duration: number)
	session.selfControlUntil = now + duration; session.selfStun = true
	Fighters.StunSpell(fighter, duration)
	session.selfStun = false
end
local function clearSage(session: Session)
 Sage.cancel(session.sage)
 local model=session.character
 if model then
  Stats.SetLayer(model,"NarutoSage",nil)
  game:GetService("CollectionService"):RemoveTag(model,"NarutoSage")
  for _,key in {"SagePhase","SageRank","SageReadyAt","SageExpiresAt","SageAuraUntil"} do model:SetAttribute(key,nil) end
 end
end
local function invalidate(player: Player, session: Session)
 MeditationClones.ClearOwner(player)
 Meditation.invalidate(session.meditation,roundId(),session.life+1)
 Variants.cancel(session.variants)
 clearSage(session)
	Gama.Remove(player); GamaDomain.cancel(session.gama)
	session.life += 1; Sage.newLife(session.sage,roundId(),session.life); Rasengan.newLife(session.q, session.life); CloneState.newLife(session.clones, session.life)
	Commands.suspend(session.commands); session.target = nil; session.selfControlUntil = 0
	publish(player, session, workspace:GetServerTimeNow())
end
local function bind(player: Player): Session
	local existing = sessions[player]; if existing then return existing end
	local now, owner = workspace:GetServerTimeNow(), tostring(player.UserId)
	local session: Session = { variants=Variants.new(), shurikenSnapshot=0, meditation=Meditation.new(owner,roundId(),0), meditationMode=false, meditationRecallAt=0, sage=Sage.new(owner,roundId(),0), gama=GamaDomain.new(), q = Rasengan.new(owner, roundId(), 0), clones = CloneState.new(owner, roundId(), 0),
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
	if id=="ShadowSleep" then if typeof(targetValue)~="Instance" then return false,"Target" end; id="ShadowClones" end
	local session = bind(player); local model = player.Character
	local fighter = if model then Fighters.GetOrCreate(model) else nil
	if not model or not fighter then return false, "Unavailable" end
	if fighter.sleep and fighter.sleep.active then return false, "Busy" end
	Resource.recalculate(session.pool, values(player), now)
	if Kcm.IsAbility(id) then return Kcm.TryCast(player,id,requestId,now,targetValue) end
	if Kcm.Blocked(model,id) then return false,"Form" end
 if id=="MeditationToggle" or id=="MeditationRecall" then
  if targetValue~=nil then return false,"Malformed" end
  if fighter.logic.mode~="Idle" or session.selfControlUntil>now then return false,"Busy" end
  if id=="MeditationToggle" then
   session.meditationMode=not session.meditationMode
  else
   if now<session.meditationRecallAt then return false,"Cooldown" end
   if next(session.meditation.clones)==nil then return false,"Unavailable" end
   session.meditationRecallAt=now+Meditation.Policy.RecallCooldown
   MeditationClones.Recall(player,now)
  end
  publish(player,session,now); return true,"Accepted"
 end
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
	if (fighter.sleep and fighter.sleep.active) or fighter.logic.mode ~= "Idle" or fighter.logic.nextAttackAt > now or session.selfControlUntil > now
		or (model:GetAttribute("AbilityId") ~= nil and model:GetAttribute("AbilityId") ~= "") then return false, "Busy" end
	if id=="Odama" or id=="Rasenshuriken" then
        if targetValue~=nil then return false,"Malformed" end
        if session.sage.active or meditationForm(player)~="Ordinary" then return false,"FormAdapterUnverified" end
        local cast=session.q.active; if not cast or cast.phase=="Consumed" then return false,"Window" end
        local profile=Progression.Get(player)
        local rank=if profile then profile.Learned.Rasengan or 0 else 0
        local choice,reason,debit=Variants.select(session.variants,id,rank,cast.startedAt,now,session.pool.mana,cast.variant=="Rasengan")
        if not choice then return false,reason end
        assert(Resource.spend(session.pool,debit))
        cast.variant=id; cast.startedAt=now; cast.readyAt=choice.readyAt; cast.expiresAt=choice.expiresAt
        cast.stun=Variants.stun(id); cast.impactDelay=if id=="Rasenshuriken" then .5 else 1
        session.preparationStunned=false
        if id=="Rasenshuriken" then session.shurikenSnapshot=values(player).strength; selfStun(session,fighter,now,1.5) end
        publish(player,session,now); return true,"Accepted"
    elseif id=="SageMode" then
        if targetValue~=nil then return false,"Malformed" end
        if session.q.active then return false,"Busy" end
        local profile=Progression.Get(player)
        local sage,reason,debit=Sage.request(session.sage,now,requestId,if profile then profile.Learned.SageMode or 0 else 0,Stats.Get(player).Level,session.pool.mana,session.meditationMode)
        if not sage then return false,reason end
        assert(Resource.spend(session.pool,debit))
        selfStun(session,fighter,now,sage.readyAt-now)
        publish(player,session,now); return true,"Accepted"
    elseif id == "Gamakichi" then
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
		Variants.cancel(session.variants)
		assert(Resource.spend(session.pool, debit), "Q debit must commit without yielding")
		session.preparationStunned = false
		publish(player, session, now); return true, "Accepted"
	elseif id == "ShadowClones" then
        local profile=Progression.Get(player)
        local rank=if profile then profile.Learned.ShadowClones or 0 else 0
        if session.pool.mana<200 then return false,"Mana" end
        local variant="OrdinarySelf"
        if typeof(targetValue)=="Instance" then
            if not (targetValue :: Instance):IsA("Model") then return false,"Target" end
            local target=targetValue :: Model
            if rank<2 or not Damage.CanDamage(model,target) or target:FindFirstChildOfClass("ForceField") then return false,"Target" end
            local root=target:FindFirstChild("HumanoidRootPart")
            if not root or not root:IsA("BasePart") or (root.Position-fighter.root.Position).Magnitude>Units.toStuds(2000) then return false,"Target" end
            if now<session.clones.cooldownAt or session.clones.burst then return false,"Cooldown" end
            if not Sleep.Apply(model,target,now) then return false,"Target" end
            assert(Resource.spend(session.pool,200)); session.clones.cooldownAt=now+Definitions.Clones.Cooldowns[rank]
            publish(player,session,now); return true,"Accepted"
        elseif targetValue~=nil then
            if typeof(targetValue)~="Vector3" or not Hitboxes.IsFiniteCFrame(CFrame.new(targetValue)) then return false,"Target" end
            if (targetValue-fighter.root.Position).Magnitude>Units.toStuds(2000) then return false,"Target" end
            variant="OrdinaryPoint"
        end
        local plan,planReason=RankPolicy.ordinaryClonePlan(rank,variant)
        if not plan then return false,planReason end
        local resourcePlan=ClonePlan.create(rank,if variant=="OrdinarySelf" then "Self" else "Point",session.pool.mana,session.pool.maximum)
        if not resourcePlan then return false,"Mana" end
        plan.count=resourcePlan.count
        local extra=resourcePlan.extraManaDrain
        if session.pool.mana<plan.manaCost then return false,"Mana" end
		local burst, reason = W.begin(session.clones, now, requestId, plan.count, plan.cooldown)
		if not burst then return false, reason end
		assert(Resource.spend(session.pool, plan.manaCost+extra), "W debit must commit without yielding")
		model:SetAttribute("NativePose", true); model:SetAttribute("AbilityId", "ShadowClones")
		model:SetAttribute("AbilityStartedAt", now); model:SetAttribute("AbilityEndsAt", now + 0.25)
		publish(player, session, now); return true, "Accepted"
	end
	return false, "Unsupported"
end
function Service.Reset()
	Kcm.Reset()
	Sleep.Reset(); Shuriken.Reset(); Summons.Reset(); Gama.Reset(); Displacement.Reset(); MeditationClones.Reset()
	for player, session in sessions do
		Meditation.invalidate(session.meditation,roundId(),session.life+1); session.meditationMode=false; session.meditationRecallAt=0
		session.variants=Variants.new(); clearSage(session); Sage.reset(session.sage,roundId(),session.life+1); session.gama=GamaDomain.new()
		session.life += 1; Rasengan.reset(session.q, roundId(), session.life); CloneState.reset(session.clones, roundId(), session.life)
		Commands.newLife(session.commands, roundId(), session.life); session.target = nil; session.selfControlUntil = 0
		session.pool = Resource.new(values(player), workspace:GetServerTimeNow()); publish(player, session, workspace:GetServerTimeNow())
	end
end
function Service.Update(now: number)
	Kcm.Update()
	for player, session in sessions do
		Resource.recalculate(session.pool, values(player), now)
		local model = session.character; local fighter = if model then Fighters.Get(model) else nil
		if model and fighter then
			if not Damage.CanAct(model) or fighter.logic.mode == "Dead" then
				if session.sage.active or next(session.meditation.clones) or session.q.active or session.clones.burst or session.commands.active then invalidate(player, session) end
			else
                local preparing=session.sage.active
                if preparing and preparing.meditation and not preparing.clonesSpawned and now>=preparing.cloneSpawnAt and now<preparing.readyAt then
                    preparing.clonesSpawned=true
                    local ownerCharacter=model; local life=session.life; local epoch=roundId()
                    local clones=Meditation.spawn(session.meditation,now,preparing.rank,Stats.Get(player).Level,meditationForm(player))
                    MeditationClones.Spawn(player,model,session.meditation,clones,function()
                        local humanoid=ownerCharacter:FindFirstChildOfClass("Humanoid")
                        return sessions[player]==session and player.Parent==Players and player.Character==ownerCharacter and session.life==life and roundId()==epoch and humanoid~=nil and humanoid.Health>0 and Damage.CanAct(ownerCharacter)
                    end,function(amount: number)
                        Resource.recalculate(session.pool,values(player),workspace:GetServerTimeNow())
                        session.pool.mana=math.min(session.pool.maximum,session.pool.mana+amount)
                    end)
                end
				if Sage.expire(session.sage,now) then
                    Stats.SetLayer(model,"NarutoSage",nil)
                    game:GetService("CollectionService"):RemoveTag(model,"NarutoSage")
                end
                local activated=Sage.activate(session.sage,now)
                if activated then
                    Kcm.SageActivated(player)
                    local modifier=Sage.modifier(activated.rank); assert(modifier)
                    Stats.SetLayer(model,"NarutoSage",{health=modifier.health,armor=modifier.armor,attack=modifier.attack,speed=Units.toStuds(modifier.speedWarcraft)})
                    if not activated.meditation then session.pool.mana=math.min(session.pool.maximum,session.pool.mana+Sage.Source.ManaRestore[activated.rank]) end
                    publish(player,session,now)
                end
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
						if victim then Fighters.StunSpell(victim, cast.stun) end
						selfStun(session, fighter, now, if cast.variant=="Rasenshuriken" then 1.5 else cast.impactDelay)
						local round, life = session.q.round, session.q.life
						local consumedCast: Rasengan.Cast = cast
						if cast.variant~="Rasenshuriken" then Displacement.Begin(model, target, now, 2, 1, 1, 18, 0.03, function()
							return session.q.round == round and session.q.life == life and (session.q.active == consumedCast or consumedCast.impacted) and Damage.CanDamage(model, target)
						end, function() Service.Visual:Fire({kind="RasenganFinish",position=target:GetPivot().Position}) end,
						function() Service.Visual:Fire({kind="RasenganTrail",position=target:GetPivot().Position}) end) end
					end
					local impacted = Q.claimImpact(session.q, cast, now)
					if impacted and target then
						local humanoid = target:FindFirstChildOfClass("Humanoid")
						local level, strength = Service.GetStats(player); local raw = Variants.damage(cast.variant,level,strength)
						if humanoid and raw then
							if cast.variant=="Rasenshuriken" then
                                local round,life=session.q.round,session.q.life
                                Shuriken.Begin(model,target,now,function() return session.q.round==round and session.q.life==life and Damage.CanAct(model) end,function() return values(player).strength end,session.shurikenSnapshot)
                            else Damage.Apply(model, humanoid, raw) end
						end
						session.target = nil
					end
				end
				local burst = session.clones.burst
				if burst then
					local clone = W.spawnOne(session.clones, burst, now, true, Q.hasMarker(session.q, now) and (session.q.active :: Rasengan.Cast).variant~="Rasenshuriken")
					if clone then Summons.Spawn(player, model, session.clones, clone, session.commands) end
				end
			end
		end
		CloneState.expire(session.clones, now)
		if now >= session.nextPublish then publish(player, session, now) end
	end
	Sleep.Update(now); Shuriken.Update(now); Displacement.Update(now)
end
function Service.Start()
	if started then return end; started = true
	Kcm.Start({
		mana=function(player) local s=sessions[player]; return if s then s.pool.mana else 0 end,
		restoreMana=function(player,amount) local s=sessions[player]; if s then s.pool.mana=math.min(s.pool.maximum,s.pool.mana+amount) end end,
		spendMana=function(player,amount) local s=sessions[player]; return s~=nil and Resource.spend(s.pool,amount) end,
		busy=function(player)
			local s=sessions[player]; if not s then return true end
			local sage=s.sage.active
			return s.q.active~=nil or s.clones.burst~=nil or s.selfControlUntil>workspace:GetServerTimeNow() or (sage~=nil and sage.phase=="Preparing")
		end,
		sage=function(player)
			local s=sessions[player]; local cast=if s then s.sage.active else nil; local now=workspace:GetServerTimeNow()
			return if cast and cast.phase=="Active" then math.max(0,cast.expiresAt-now) else 0, cast~=nil and cast.phase=="Active" and cast.auraUntil>now
		end,
	})
 Service.ConfigureMeditationForms(Kcm.MeditationForm)
 Kurama.ConfigureSummonManaReceiver(MeditationClones.RestoreMana)
 Shuriken.Visual.Event:Connect(function(message) Service.Visual:Fire(message) end)
 Gama.Visual.Event:Connect(function(message) Service.Visual:Fire(message) end)
	Players.PlayerAdded:Connect(function(player) bind(player) end)
	Players.PlayerRemoving:Connect(function(player)
		Kcm.Remove(player)
		local session = sessions[player]; if not session then return end
		MeditationClones.ClearOwner(player); Meditation.invalidate(session.meditation,roundId(),session.life+1)
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
			elseif fighter.logic.mode == "Stunned" or (fighter.sleep and fighter.sleep.active) then cancelQ(player, session, workspace:GetServerTimeNow()) end
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
		Kcm.OnAttackStarted(player,chosen~=nil)
  if chosen then Commands.assist(session.commands, Summons.EntityId(chosen), true) end
		local cast = session.q.active
		local targetRoot = if chosen then chosen:FindFirstChild("HumanoidRootPart") else nil
		if cast and chosen and targetRoot and targetRoot:IsA("BasePart")
			and nearest <= Units.toStuds(50) + (fighter.root.Size.X + targetRoot.Size.X) / 2 then
			local kind = chosen:GetAttribute("EntityKind")
			if Q.attack(session.q, cast, workspace:GetServerTimeNow(), Summons.EntityId(chosen), true, kind ~= "Hero" and kind ~= "Minion" and kind ~= "Summon") then
				session.target = chosen; session.selfControlUntil = workspace:GetServerTimeNow() + 0.01 + cast.impactDelay
				publish(player, session, workspace:GetServerTimeNow())
			end
		end
	end)
	local last = workspace:GetServerTimeNow()
	game:GetService("RunService").Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow(); local delta = math.max(0, now - last); last = now
		Summons.Update(now, delta, Service.GetStats)
		Gama.Update(now,delta)
        MeditationClones.Update(now)
	end)
	for _, player in Players:GetPlayers() do bind(player) end
end
return Service
