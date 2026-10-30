--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.JungleConfig)
local MapConfig = require(Shared.Config.MapConfig)
local Rules = require(Shared.Game.JungleRules)
local Factory = require(script.Parent.MinionFactory)
local Fighters = require(script.Parent.FighterStateService)
local Damage = require(script.Parent.DamageService)
local Teams = require(script.Parent.TeamService)
local Life = require(script.Parent.CombatLifeService)
type Camp = { id: string, home: Vector3, logic: Rules.Camp, model: Model?, target: Model?, nextAttack: number, returnAt: number, deadAt: number }
local Jungle = {}
local camps: { Camp } = {}
local container: Folder? = nil
function Jungle.GetAll(): { Camp } return camps end
local function remove(camp: Camp)
	local model = camp.model; if not model then return end
	Teams.RemoveNeutral(model); Fighters.Remove(model); Life.Remove(model); model:Destroy(); camp.model = nil
end
local function spawn(camp: Camp, now: number)
	local state = Teams.GetState(); if not state or state.phase ~= "InProgress" then return end
	remove(camp)
	local model = Factory.Create("Jungle", Config.TeamId, Color3.fromRGB(156, 121, 75), camp.home, Config.Stats)
	model.Name = "ForestGuardian_" .. camp.id; model:SetAttribute("NeutralCampId", camp.id)
	model:SetAttribute("RoundId", state.roundId)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = "Лесной страж"
	model.Parent = container; camp.model = model; camp.logic = Rules.new(); camp.target = nil; camp.nextAttack = now + 0.5; camp.returnAt = 0
	Teams.RegisterNeutral(model); Fighters.GetOrCreate(model); Life.Register(model)
	local root = model.PrimaryPart :: BasePart
	if root:CanSetNetworkOwnership() then root:SetNetworkOwner(nil) end
end
function Jungle.Stop()
	for _, camp in camps do
		camp.target = nil
		if camp.model then
			camp.model:SetAttribute("CombatDisabled", true)
			local humanoid = camp.model:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid:Move(Vector3.zero); humanoid.WalkSpeed = 0 end
		end
	end
end
function Jungle.Start(arena: Folder)
	if container then return end
	local folder = Instance.new("Folder"); folder.Name = "JungleCamps"; folder.Parent = workspace; container = folder
	local markers = Instance.new("Folder"); markers.Name = "Jungle"; markers.Parent = arena
	for _, definition in Config.Camps do
		local home = MapConfig.Origin + definition.Offset
		local marker = Instance.new("Part"); marker.Name = definition.Id; marker.Anchored = true
		marker.CanCollide = false; marker.CanQuery = false; marker.CanTouch = false
		marker.Size = Vector3.new(15, 0.15, 15); marker.Position = home - Vector3.new(0, 2.9, 0)
		marker.Color = Color3.fromRGB(93, 79, 54); marker.Material = Enum.Material.Ground; marker.Parent = markers
		table.insert(camps, { id = definition.Id, home = home, logic = {mode="Dead",respawnAt=0}, model=nil, target=nil, nextAttack=0, returnAt=0, deadAt=0 })
	end
	Damage.Applied.Event:Connect(function(attacker: Model, target: Model)
		for _, camp in camps do
			if camp.model ~= target or camp.logic.mode == "Returning" or camp.logic.mode == "Dead" then continue end
			local root = attacker:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.Position-camp.home).Magnitude <= Config.Leash then camp.target = attacker end
		end
	end)
end
function Jungle.Update(now: number)
	local state = Teams.GetState(); if not state or state.phase ~= "InProgress" then return end
	for _, camp in camps do
		local model = camp.model
		if model and not model.Parent then remove(camp); Rules.die(camp.logic, now, Config.RespawnDelay); model = nil end
		if model and model.Parent then
			local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			if humanoid.Health <= 0 and camp.logic.mode ~= "Dead" then Rules.die(camp.logic, now, Config.RespawnDelay); camp.deadAt = now; camp.target = nil end
			if camp.logic.mode == "Dead" and now - camp.deadAt >= Config.CorpseLifetime then remove(camp); model = nil end
		end
		if camp.logic.mode == "Dead" then
			if Rules.step(camp.logic, now, true, 0, false, 0, Config.Leash) == "Spawn" then spawn(camp, now) end
			continue
		end
		if not model or not model.Parent then remove(camp); Rules.die(camp.logic, now, Config.RespawnDelay); continue end
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		local root = model.PrimaryPart :: BasePart
		local fighter = Fighters.Get(model)
		if fighter and fighter.logic.mode ~= "Stunned" then humanoid.WalkSpeed = Config.Stats.WalkSpeed end
		local target = camp.target
		if target and not Damage.CanDamage(model, target) then target = nil end
		if not target and camp.logic.mode ~= "Returning" then
			local nearest = Config.DetectionRange
			for candidate, candidateFighter in Fighters.GetAll() do
				if not Damage.CanDamage(model, candidate) then continue end
				local distance = (candidateFighter.root.Position - root.Position).Magnitude
				if distance < nearest then nearest = distance; target = candidate end
			end
		end
		local targetRoot = if target then target:FindFirstChild("HumanoidRootPart") else nil
		local valid = targetRoot ~= nil and targetRoot:IsA("BasePart")
		local targetPosition = if valid then (targetRoot :: BasePart).Position else camp.home
		local mode = Rules.step(camp.logic, now, true, (root.Position-camp.home).Magnitude, valid, (targetPosition-camp.home).Magnitude, Config.Leash)
		model:SetAttribute("AIState", mode); model:SetAttribute("CombatDisabled", mode == "Returning")
		if mode == "Returning" then
			camp.target = nil
			if camp.returnAt == 0 then camp.returnAt = now end
			-- Bounded recovery when terrain/physics prevents reaching the camp.
			if now - camp.returnAt > 6 then model:PivotTo(CFrame.new(camp.home)) end
			humanoid:MoveTo(camp.home)
		else
			camp.returnAt = 0; camp.target = target
			if mode == "Idle" then humanoid.Health = humanoid.MaxHealth; humanoid:MoveTo(camp.home) end
			if mode == "Chasing" and target and fighter and fighter.logic.mode ~= "Stunned" then
				if (targetPosition-root.Position).Magnitude > Config.AttackRange then humanoid:MoveTo(targetPosition)
				else
					humanoid:MoveTo(root.Position)
					if now >= camp.nextAttack then
						camp.nextAttack = now + Config.Stats.AttackCooldown
						local victim = target:FindFirstChildOfClass("Humanoid")
						if victim then Damage.Apply(model, victim, Config.Stats.Damage) end
					end
				end
			end
		end
	end
end
return Jungle
