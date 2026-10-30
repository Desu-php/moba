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
export type Record = { model: Model, root: BasePart, humanoid: Humanoid, owner: Player, state: Domain.State,
	clone: Domain.Clone, commands: Commands.State, nextHit: number, attackDamage: number }
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
	records[model] = nil; Domain.remove(record.state, record.clone); Fighters.Remove(model); model:Destroy()
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
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Tool") or item:IsA("ForceField") then item:Destroy()
		elseif item:IsA("BasePart") then item.CanCollide = false; item.CanTouch = false; item.Massless = true end
	end
	model:SetAttribute("OilUntil",nil); model:SetAttribute("OilMoveMultiplier",nil); model:SetAttribute("OilMissAt",nil); game:GetService("CollectionService"):RemoveTag(model,"GamakichiOilStatus")
	model.Name = "ShadowClone"; model:SetAttribute("EntityKind", "Summon"); model:SetAttribute("NativeNarutoClone", true)
	model:SetAttribute("SummonOwner", player.UserId); model:SetAttribute("CombatDisabled", false)
	model:SetAttribute("AbilityId", ""); model:SetAttribute("AbilityEntityId", nil); model:SetAttribute("LifeId", nil)
	model:SetAttribute("RasenganPhase", ""); model:SetAttribute("RasenganSelfPauseUntil", 0)
	model:SetAttribute("CombatState", "Idle"); model:SetAttribute("RasenganHeld", clone.hasPayload); model:SetAttribute("RasenganVisible", clone.hasPayload)
	model:SetAttribute("RasenganExpiresAt", clone.expiresAt)
	model:SetAttribute("OutgoingDamageMultiplier", clone.outgoingMultiplier); model:SetAttribute("IncomingDamageMultiplier", clone.incomingMultiplier)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
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
	model:PivotTo(character:GetPivot() + offset); model.Parent = folder
	local stats = Stats.Get(player)
	records[model] = { model = model, root = root, humanoid = humanoid, owner = player, state = state, clone = clone,
		commands = commands, nextHit = 0, attackDamage = Combat.Profiles.OrangeNinja.DamageByComboStep[1] * stats.AttackDamageMultiplier }
	Fighters.GetOrCreate(model); Service.Spawned:Fire(model)
	return model
end
function Service.Update(now: number, delta: number, sourceStats: (Player) -> (number, number))
	for model, record in records do
		local clone, owner = record.clone, record.owner
		if not model.Parent or record.humanoid.Health <= 0 or owner.Parent ~= Players or now >= clone.expiresAt
			or record.state.clones[clone.id] ~= clone then Service.Remove(model); continue end
		model:SetAttribute("RasenganHeld", clone.hasPayload); model:SetAttribute("RasenganVisible", clone.hasPayload)
		local fighter = Fighters.Get(model)
		if fighter and fighter.logic.mode == "Stunned" then model:SetAttribute("SummonMoving", false); continue end
		local intent = Commands.resolve(record.commands)
		local character = owner.Character
		if not character or not Damage.CanAct(character) or intent.mode == "Idle" then model:SetAttribute("SummonMoving", false); continue end
		local target: Model? = nil
		if intent.targetId then
			for candidate in Fighters.GetAll() do
				if candidate:GetAttribute("AbilityEntityId") == intent.targetId then target = candidate; break end
			end
			if not target or not Damage.CanDamage(model, target) then Commands.invalidateTarget(record.commands, intent.targetId); target = nil end
		end
		local destination = if target then target:FindFirstChild("HumanoidRootPart") else character:FindFirstChild("HumanoidRootPart")
		if not destination or not destination:IsA("BasePart") then continue end
		local distance = destination.Position - record.root.Position
		local flat = distance * Vector3.new(1, 0, 1)
		local stop = if target then Units.toStuds(50) + (record.root.Size.X + destination.Size.X) / 2 else record.root.Size.X * 3
		if flat.Magnitude > 0.001 then record.root.CFrame = CFrame.lookAt(record.root.Position, record.root.Position + flat) end
		if target and distance.Magnitude <= stop + 0.01 and now >= record.nextHit and Targets.Visible(model, target, record.root.Position, destination.Position) then
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
		-- Movement is horizontal; the attack check is 3D. Reserve vertical separation
		-- inside the same surface-distance budget so followers do not stop out of reach.
		local horizontalStop = math.sqrt(math.max(0, stop * stop - distance.Y * distance.Y))
		local moving = flat.Magnitude > horizontalStop + 0.001
		model:SetAttribute("SummonMoving", moving)
		if moving then
			local move = flat.Unit * math.min(flat.Magnitude - horizontalStop, Units.toStuds(Definitions.NativeInference.BaseSpeedWarcraft) * delta * Oil.Movement(model,now))
			local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances = { model, character }; ray.RespectCanCollide = true
			local wall = workspace:Blockcast(record.root.CFrame, record.root.Size, move, ray)
			if not wall then model:PivotTo(model:GetPivot() + move) end
		end
	end
end
return Service
