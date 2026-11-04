--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Definitions = require(Shared.Abilities.NarutoDefinitions)
local Units = require(Shared.Abilities.WorldUnits)
local Domain = require(Shared.Abilities.CloneState)
local Commands = require(Shared.Abilities.CloneCommands)
local Formulas = require(Shared.Abilities.NarutoRules).configure(Definitions)
local Combat = require(Shared.Config.CombatConfig)
local Fighters = require(script.Parent.FighterStateService)
local Damage = require(script.Parent.DamageService)
local Stats = require(script.Parent.CharacterStatsService)
local Targets = require(script.Parent.AbilityTargetService)
local Push = require(script.Parent.AbilityDisplacementService)
local Oil=require(script.Parent.OilStatusService)
local Navigation = require(script.Parent.CloneNavigation)
local Collision = require(script.Parent.SummonCollision)
local Autonomy = require(Shared.Abilities.CloneAutonomyPolicy)
local Formation = require(Shared.Abilities.CloneNavigationPolicy)
export type Record = { model: Model, root: BasePart, humanoid: Humanoid, owner: Player, state: Domain.State,
	clone: Domain.Clone, commands: Commands.State, nextHit: number, attackDamage: number,
	autoTarget: Model?, nextScan: number, lastOrder: number, recallUntil: number, returning: boolean,
	assignedTarget: Model?, lastStrike: number }
local Service = { Spawned = Instance.new("BindableEvent") }
local records: { [Model]: Record } = {}
local targetSerial = 0
local nextFormation = 0
local function coordinate(now: number)
	if now < nextFormation then return end; nextFormation = now + .2
	local groups: { [Model]: { Record } } = {}
	for _, record in records do
		local target = record.assignedTarget
		if target and record.humanoid.Health > 0 and Damage.CanDamage(record.model, target) then
			if not groups[target] then groups[target] = {} end
			table.insert(groups[target], record)
		end
	end
	for target, group in groups do
		-- Clones that have not struck yet get the next free place. Regular attack cooldowns remain intact.
		table.sort(group, function(a: Record, b: Record): boolean
			if a.lastStrike ~= b.lastStrike then return a.lastStrike < b.lastStrike end
			if a.owner.UserId ~= b.owner.UserId then return a.owner.UserId < b.owner.UserId end
			return a.clone.id < b.clone.id
		end)
		for index, record in group do Navigation.SetFrontline(record.model, target, index <= Formation.FrontlineLimit) end
	end
end
local function targetScore(record: Record, target: Model, root: BasePart, assistId: string?): number
	local assigned = 0
	for _, other in records do
		if other ~= record and other.assignedTarget == target and other.humanoid.Health > 0 then assigned += 1 end
	end
	return (root.Position - record.root.Position).Magnitude + assigned * Autonomy.CrowdCost
		- (if assistId and target:GetAttribute("AbilityEntityId") == assistId then Autonomy.AssistBonus else 0)
end
local function targetId(model: Model): string
	local id = model:GetAttribute("AbilityEntityId")
	if typeof(id) == "string" then return id end
	targetSerial += 1; id = "entity-" .. tostring(targetSerial); model:SetAttribute("AbilityEntityId", id); return id :: string
end
function Service.EntityId(model: Model): string return targetId(model) end
function Service.GetAll(): { [Model]: Record } return records end
function Service.GetCount(): number local count = 0; for _ in records do count += 1 end; return count end
function Service.Remove(model: Model)
	local record = records[model]; if not record then return end
	Navigation.Remove(model); records[model] = nil; Domain.remove(record.state, record.clone); Fighters.Remove(model); model:Destroy()
end
function Service.ClearOwner(player: Player)
	for model, record in records do if record.owner == player then Service.Remove(model) end end
end
function Service.Reset() for model in records do Service.Remove(model) end end
function Service.Spawn(player: Player, character: Model, state: Domain.State, clone: Domain.Clone, commands: Commands.State): Model?
	local sourceRoot = character:FindFirstChild("HumanoidRootPart"); local sourceHumanoid = character:FindFirstChildOfClass("Humanoid")
	if not sourceRoot or not sourceRoot:IsA("BasePart") or not sourceHumanoid or sourceHumanoid.Health <= 0 then Domain.remove(state, clone); return nil end
	local previous = character.Archivable; character.Archivable = true
	local model = character:Clone(); character.Archivable = previous
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.EvaluateStateMachine = false
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Tool") or item:IsA("ForceField") then item:Destroy()
		elseif item:IsA("BasePart") then item.CanCollide = false; item.CanTouch = false; item.Massless = true end
	end
	model:SetAttribute("OilUntil",nil); model:SetAttribute("OilMoveMultiplier",nil); model:SetAttribute("OilMissAt",nil); game:GetService("CollectionService"):RemoveTag(model,"GamakichiOilStatus")
	for _,key in {"SagePhase","SageRank","SageReadyAt","SageExpiresAt","SageAuraUntil"} do model:SetAttribute(key,nil) end
 game:GetService("CollectionService"):RemoveTag(model,"NarutoSage")
 model:SetAttribute("SleepUntil",nil); model:SetAttribute("RasenganVariant",nil); model:SetAttribute("RasenganVariantUntil",nil)
 require(script.Parent.HeroAppearanceService).Apply(model)
 model.Name = "ShadowClone"; model:SetAttribute("EntityKind", "Summon"); model:SetAttribute("NativeNarutoClone", true)
	model:SetAttribute("SummonOwner", player.UserId); model:SetAttribute("CombatDisabled", false)
	model:SetAttribute("AbilityId", ""); model:SetAttribute("AbilityEntityId", nil); model:SetAttribute("LifeId", nil)
	model:SetAttribute("RasenganPhase", ""); model:SetAttribute("RasenganSelfPauseUntil", 0)
	model:SetAttribute("CombatState", "Idle"); model:SetAttribute("RasenganHeld", clone.hasPayload); model:SetAttribute("RasenganVisible", clone.hasPayload)
	model:SetAttribute("RasenganExpiresAt", clone.expiresAt)
	model:SetAttribute("OutgoingDamageMultiplier", clone.outgoingMultiplier); model:SetAttribute("IncomingDamageMultiplier", clone.incomingMultiplier)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	-- Navigation owns movement. Collision groups also protect against copied-rig
	-- initialization restoring CanCollide after these explicit flags are set.
	-- Explicit prototype inheritance policy: copy current/max HP once, without .05 scaling.
	humanoid.WalkSpeed=Stats.Get(player).WalkSpeed; humanoid.MaxHealth = sourceHumanoid.MaxHealth; humanoid.Health = sourceHumanoid.Health
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None; humanoid.BreakJointsOnDeath = false
	root.Anchored = true; model.PrimaryPart = root
	-- Give each new clone its own spawn position, including a mass cast.
	local offset = Vector3.zero
	for index = 1, 80 do
		local x, z = Formation.slot(index, math.max(4.2, sourceRoot.Size.X * 2), 3)
		local candidate = sourceRoot.CFrame:VectorToWorldSpace(Vector3.new(x, 0, z))
		local free = true
		for _, other in records do
			if (other.root.Position - (sourceRoot.Position + candidate)).Magnitude < 2.5 then free = false; break end
		end
		if free then offset = candidate; break end
	end
	local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances = { character }; ray.RespectCanCollide = true
	local wall = workspace:Blockcast(sourceRoot.CFrame, sourceRoot.Size, offset, ray)
	if wall and offset.Magnitude > 0 then offset = offset.Unit * math.max(0, wall.Distance - 0.01) end
	local folder = workspace:FindFirstChild("HeroSummons")
	if not folder then folder = Instance.new("Folder"); folder.Name = "HeroSummons"; folder.Parent = workspace end
	Collision.Apply(model)
	model:PivotTo(character:GetPivot() + offset); model.Parent = folder
	local stats = Stats.Get(player)
	records[model] = { model = model, root = root, humanoid = humanoid, owner = player, state = state, clone = clone,
		assignedTarget = nil, lastStrike = 0,
		autoTarget = nil, nextScan = 0, lastOrder = commands.lastRequest, recallUntil = 0, returning = false,
		commands = commands, nextHit = 0, attackDamage = Combat.Profiles.OrangeNinja.CloneDamage * stats.AttackDamageMultiplier + stats.AttackDamageBonus }
	Navigation.Register(model, root, humanoid)
	Fighters.GetOrCreate(model); Service.Spawned:Fire(model)
	return model
end
function Service.Update(now: number, delta: number, sourceStats: (Player) -> (number, number))
	coordinate(now)
	for model, record in records do
		record.assignedTarget = nil
		local clone, owner = record.clone, record.owner
		if not model.Parent or record.humanoid.Health <= 0 or owner.Parent ~= Players or now >= clone.expiresAt
			or record.root.Position.Y < workspace.FallenPartsDestroyHeight
			or record.state.clones[clone.id] ~= clone then Service.Remove(model); continue end
		model:SetAttribute("RasenganHeld", clone.hasPayload); model:SetAttribute("RasenganVisible", clone.hasPayload)
		local character = owner.Character
		-- Gravity runs before orders/control locks, so Hold and owner death cannot freeze a falling clone.
		if not Navigation.Settle(model, character or model, delta) then
			model:SetAttribute("SummonBehavior", "Landing"); Navigation.Stop(model); continue
		end
		local fighter = Fighters.Get(model)
		if fighter and (fighter.logic.mode == "Stunned" or (fighter.sleep and fighter.sleep.active)) then Navigation.Stop(model); continue end
		local intent = Commands.resolve(record.commands)
		if record.lastOrder ~= record.commands.lastRequest then
			record.lastOrder = record.commands.lastRequest; record.autoTarget = nil; record.nextScan = 0
			record.returning = intent.mode == "Follow"
			record.recallUntil = if record.returning then now + Autonomy.RecallGrace else 0
		end
		if not character or not Damage.CanAct(character) or intent.mode == "Idle" or intent.mode == "Hold" then
			record.autoTarget = nil; model:SetAttribute("SummonBehavior", intent.mode); Navigation.Stop(model); continue
		end
		local ownerRoot = character:FindFirstChild("HumanoidRootPart")
		if not ownerRoot or not ownerRoot:IsA("BasePart") then Navigation.Stop(model); continue end
		local ownerDistance = (ownerRoot.Position - record.root.Position).Magnitude
		if ownerDistance > Autonomy.OwnerLeash then record.returning = true end
		if record.returning and ownerDistance < Autonomy.ReturnRadius and now >= record.recallUntil then record.returning = false end
		local target: Model? = nil
		if intent.targetId and intent.mode == "Command" then
			for candidate in Fighters.GetAll() do
				if candidate:GetAttribute("AbilityEntityId") == intent.targetId then target = candidate; break end
			end
			if not target or not Damage.CanDamage(model, target) then Commands.invalidateTarget(record.commands, intent.targetId); target = nil end
		end
		if not target and not record.returning then
			local current = record.autoTarget
			local currentRoot = if current then current:FindFirstChild("HumanoidRootPart") else nil
			if not current or not currentRoot or not currentRoot:IsA("BasePart") or not Damage.CanDamage(model, current)
				or (currentRoot.Position - record.root.Position).Magnitude > Autonomy.PursueRadius
				or (currentRoot.Position - ownerRoot.Position).Magnitude > Autonomy.OwnerLeash then record.autoTarget = nil end
			if now >= record.nextScan then
				record.nextScan = now + Autonomy.ScanInterval
				-- Rebalance with hysteresis: a moving crowd cannot strand clones on one enemy,
				-- while small distance changes do not make the entire group swap targets.
				local best = record.autoTarget
				local bestRoot = if best then best:FindFirstChild("HumanoidRootPart") else nil
				local bestScore = if best and bestRoot and bestRoot:IsA("BasePart") then targetScore(record, best, bestRoot, intent.targetId) - Autonomy.SwitchMargin else math.huge
				if now >= record.nextHit - 1.7 then
					for _, enemy in Targets.InCone(model, record.root.CFrame, Autonomy.AcquireRadius, -1, false, 16) do
						local candidate = enemy.Parent
						local candidateRoot = if candidate then candidate:FindFirstChild("HumanoidRootPart") else nil
						if candidate and candidate:IsA("Model") and candidateRoot and candidateRoot:IsA("BasePart")
							and (candidateRoot.Position - ownerRoot.Position).Magnitude <= Autonomy.OwnerLeash then
							local score = targetScore(record, candidate, candidateRoot, intent.targetId)
							if score < bestScore then best = candidate; bestScore = score end
						end
					end
				end
				record.autoTarget = best
			end
			target = record.autoTarget
		else record.autoTarget = nil end
		record.assignedTarget = target
		model:SetAttribute("SummonBehavior", if target then "Attack" elseif record.returning then "Return" else "Follow")
		model:SetAttribute("SummonTarget", if target then target.Name else "")
		local destination = if target then target:FindFirstChild("HumanoidRootPart") else character:FindFirstChild("HumanoidRootPart")
		if not destination or not destination:IsA("BasePart") then Navigation.Stop(model); continue end
		local distance = destination.Position - record.root.Position
		local flat = distance * Vector3.new(1, 0, 1)
		local stop = if target then Units.toStuds(50) + (record.root.Size.X + destination.Size.X) / 2 else record.root.Size.X * 3
		if flat.Magnitude > 0.001 then record.root.CFrame = CFrame.lookAt(record.root.Position, record.root.Position + flat) end
		if target and Navigation.CanStrike(model, target) and Damage.CanDamage(model, target) and distance.Magnitude <= stop + 0.01 and now >= record.nextHit and Targets.Visible(model, target, record.root.Position, destination.Position) then
			record.nextHit = now + 2 -- Hpal ua1c; M1 damage itself retains current prototype combat balance.
			record.lastStrike = now
			model:SetAttribute("SummonSwingAt", now); model:SetAttribute("SummonSwingStep", 1)
			local humanoid = target:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local payload = Domain.takePayload(record.state, clone, now, targetId(target), true, target:GetAttribute("EntityKind") ~= "Hero" and target:GetAttribute("EntityKind") ~= "Minion" and target:GetAttribute("EntityKind") ~= "Summon")
				if payload and Domain.claimPayload(record.state, payload) then
					local level, strength = sourceStats(owner)
					local raw = Formulas.clonePayloadDamage(level, strength)
					if raw then Damage.Apply(character, humanoid, raw) end
					local round, life = record.state.round, record.state.life
					Push.Begin(character, target, now, 0.5, 0.5, 12, 12, 0.01, function()
						return record.state.round == round and record.state.life == life and Damage.CanDamage(character, target :: Model)
					end)
				end
				Damage.ApplyAttack(model, humanoid, record.attackDamage)
			end
		end
		local moving = Navigation.Step(model, character, target or character, destination, stop, now, delta,
			Units.toStuds(Definitions.NativeInference.BaseSpeedWarcraft) * Oil.Movement(model, now))
		model:SetAttribute("SummonMoving", moving)
	end
end
return Service
