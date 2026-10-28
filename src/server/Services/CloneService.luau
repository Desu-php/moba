--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.AbilityConfig).Clones
local Damage = require(script.Parent.DamageService)
local Stats = require(script.Parent.CharacterStatsService)
local Targets = require(script.Parent.AbilityTargetService)
local Hitboxes = require(script.Parent.HitboxService)
export type Clone = { model: Model, root: BasePart, humanoid: Humanoid, owner: Player, character: Model,
	expires: number, nextHit: number, hits: number }
local CloneService = { Spawned = Instance.new("BindableEvent") }
local records: { [Model]: Clone } = {}
local count, nextUpdate = 0, 0
function CloneService.GetCount(): number return count end
function CloneService.GetAll(): { [Model]: Clone } return records end
function CloneService.Remove(model: Model)
	if not records[model] then return end
	records[model] = nil; count -= 1; model:Destroy()
end
function CloneService.ClearOwner(player: Player)
	for model, record in records do if record.owner == player then CloneService.Remove(model) end end
end
function CloneService.Reset()
	for model in records do CloneService.Remove(model) end
	nextUpdate = 0
end
function CloneService.Spawn(player: Player, character: Model): number
	if player.Character ~= character or not Damage.CanAct(character) then return 0 end
	CloneService.ClearOwner(player)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or not Hitboxes.IsFiniteCFrame(root.CFrame) then return 0 end
	local folder = workspace:FindFirstChild("HeroSummons")
	if not folder then folder = Instance.new("Folder"); folder.Name = "HeroSummons"; folder.Parent = workspace end
	local spawned = 0
	for i = 1, Config.Count do
		if count >= Config.GlobalLimit then break end
		local previous = character.Archivable; character.Archivable = true
		local model = character:Clone(); character.Archivable = previous
		for _, item in model:GetDescendants() do
			if item:IsA("LuaSourceContainer") or item:IsA("Tool") or item:IsA("ForceField") then item:Destroy()
			elseif item:IsA("BasePart") then item.CanCollide = false; item.CanTouch = false; item.CanQuery = false; item.Massless = true end
		end
		model.Name = "ShadowClone"; model:SetAttribute("EntityKind", "Summon"); model:SetAttribute("SummonOwner", player.UserId)
		model:SetAttribute("CombatDisabled", false); model:SetAttribute("CombatState", "Idle")
		model:SetAttribute("AbilityId", ""); model:SetAttribute("LifeId", nil)
		model:SetAttribute("CombatLastAttackAt", 0); model:SetAttribute("CombatAttackEndsAt", 0)
		local cloneRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None; humanoid.BreakJointsOnDeath = false
		humanoid.MaxHealth = 100; humanoid.Health = 100
		cloneRoot.Anchored = true; model.PrimaryPart = cloneRoot
		model:PivotTo(root.CFrame)
		local offset = root.CFrame.RightVector * (if i % 2 == 0 then Config.SpawnOffset else -Config.SpawnOffset) + root.CFrame.LookVector * Config.SpawnForward
		local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances = { character, folder :: Instance }; ray.RespectCanCollide = true
		local wall = workspace:Blockcast(root.CFrame, Vector3.new(2, 4, 2), offset, ray)
		if wall then offset = offset.Unit * math.max(0, wall.Distance - 0.3) end
		model:PivotTo(root.CFrame + offset); model.Parent = folder
		local now = workspace:GetServerTimeNow()
		records[model] = { model = model, root = cloneRoot, humanoid = humanoid, owner = player, character = character,
			expires = now + Config.Lifetime, nextHit = now + Config.Interval, hits = 0 }
		count += 1; spawned += 1; CloneService.Spawned:Fire(model)
	end
	return spawned
end
function CloneService.Update(now: number)
	-- Cleanup is checked every server tick; target search is shared and capped at 10 Hz.
	for model, record in records do
		if not model.Parent or record.owner.Parent ~= Players or record.owner.Character ~= record.character
			or not Damage.CanAct(record.character) or now >= record.expires then CloneService.Remove(model) end
	end
	if now < nextUpdate then return end; nextUpdate = now + Config.UpdateInterval
	for model, record in records do
		local target = if record.hits < Config.MaxHits then Targets.Nearest(record.character, record.root.CFrame, Config.Radius, -1, false) else nil
		local targetModel = if target then target.Parent else nil
		local targetRoot = if targetModel then targetModel:FindFirstChild("HumanoidRootPart") else nil
		if not target or not targetModel or not targetModel:IsA("Model") or not targetRoot or not targetRoot:IsA("BasePart") then model:SetAttribute("SummonMoving", false); continue end
		local delta = targetRoot.Position - record.root.Position
		local horizontal = delta * Vector3.new(1, 0, 1)
		if horizontal.Magnitude > 0.001 then record.root.CFrame = CFrame.lookAt(record.root.Position, record.root.Position + horizontal) end
		if delta.Magnitude <= Config.Range then
			model:SetAttribute("SummonMoving", false)
			if now >= record.nextHit and Targets.Visible(record.character, targetModel, record.root.Position, targetRoot.Position) then
				record.nextHit = now + Config.Interval; record.hits += 1
				model:SetAttribute("SummonSwingAt", now); model:SetAttribute("SummonSwingStep", (record.hits - 1) % 2 + 1)
				local stats = Stats.GetForModel(record.character)
				Damage.Apply(record.character, target, Config.Damage * (if stats then stats.AttackDamageMultiplier else 1))
			end
		else
			model:SetAttribute("SummonMoving", true)
			if horizontal.Magnitude < 0.001 then continue end
			local step = horizontal.Unit * math.min(horizontal.Magnitude - Config.Range * 0.8, Config.Speed * Config.UpdateInterval)
			local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude
			ray.FilterDescendantsInstances = { record.character, model.Parent :: Instance, targetModel }; ray.RespectCanCollide = true
			local wall = workspace:Blockcast(record.root.CFrame, Vector3.new(2, 4, 2), step, ray)
			if not wall then model:PivotTo(record.root.CFrame + step) end
		end
	end
end
Players.PlayerRemoving:Connect(CloneService.ClearOwner)
return CloneService
