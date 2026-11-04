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
export type Record = { model: Model, root: BasePart, humanoid: Humanoid, owner: Player, state: Domain.State,
	clone: Domain.Clone, commands: Commands.State, nextHit: number, attackDamage: number,
	autoTarget: Model?, nextScan: number, lastOrder: number, recallUntil: number, returning: boolean }
local Service = { Spawned = Instance.new("BindableEvent") }
local records: { [Model]: Record } = {}
local targetSerial = 0
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
	local spacing = sourceRoot.Size.X * 2
	local offset = sourceRoot.CFrame.RightVector * ((clone.id % 3) - 1) * spacing + sourceRoot.CFrame.LookVector * -spacing
	local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances = { character }; ray.RespectCanCollide = true
	local wall = workspace:Blockcast(sourceRoot.CFrame, sourceRoot.Size, offset, ray)
	if wall and offset.Magnitude > 0 then offset = offset.Unit * math.max(0, wall.Distance - 0.01) end
	local folder = workspace:FindFirstChild("HeroSummons")
	if not folder then folder = Instance.new("Folder"); folder.Name = "HeroSummons"; folder.Parent = workspace end
	Collision.Apply(model)
	model:PivotTo(character:GetPivot() + offset); model.Parent = folder
	local stats = Stats.Get(player)
	records[model] = { model = model, root = root, humanoid = humanoid, owner = player, state = state, clone = clone,
		autoTarget = nil, nextScan = 0, lastOrder = commands.lastRequest, recallUntil = 0, returning = false,
		commands = commands, nextHit = 0, attackDamage = Combat.Profiles.OrangeNinja.CloneDamage * stats.AttackDamageMultiplier + stats.AttackDamageBonus }
	Navigation.Register(model, root, humanoid)
	Fighters.GetOrCreate(model); Service.Spawned:Fire(model)
	return model
end
function Service.Update(now: number, delta: number, sourceStats: (Player) -> (number, number))
	for model, record in records do
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
		if intent.targetId and (intent.mode == "Command" or not record.returning) then
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
				-- Keep a valid target through the swing; reacquire immediately after it dies.
				if not record.autoTarget then
					for _, enemy in Targets.InCone(model, record.root.CFrame, Autonomy.AcquireRadius, -1, false, 8) do
						local candidate = enemy.Parent
						local candidateRoot = if candidate then candidate:FindFirstChild("HumanoidRootPart") else nil
						if candidate and candidate:IsA("Model") and candidateRoot and candidateRoot:IsA("BasePart")
							and (candidateRoot.Position - ownerRoot.Position).Magnitude <= Autonomy.OwnerLeash then
							record.autoTarget = candidate; break
						end
					end
				end
			end
			target = record.autoTarget
		else record.autoTarget = nil end
		model:SetAttribute("SummonBehavior", if target then "Attack" elseif record.returning then "Return" else "Follow")
		model:SetAttribute("SummonTarget", if target then target.Name else "")
		local destination = if target then target:FindFirstChild("HumanoidRootPart") else character:FindFirstChild("HumanoidRootPart")
		if not destination or not destination:IsA("BasePart") then Navigation.Stop(model); continue end
		local distance = destination.Position - record.root.Position
		local flat = distance * Vector3.new(1, 0, 1)
		local stop = if target then Units.toStuds(50) + (record.root.Size.X + destination.Size.X) / 2 else record.root.Size.X * 3
		if flat.Magnitude > 0.001 then record.root.CFrame = CFrame.lookAt(record.root.Position, record.root.Position + flat) end
		if target and Damage.CanDamage(model, target) and distance.Magnitude <= stop + 0.01 and now >= record.nextHit and Targets.Visible(model, target, record.root.Position, destination.Position) then
			record.nextHit = now + 2 -- Hpal ua1c; M1 damage itself retains current prototype combat balance.
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
