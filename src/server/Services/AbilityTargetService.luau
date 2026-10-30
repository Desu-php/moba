--!strict
local Fighters = require(script.Parent.FighterStateService)
local Damage = require(script.Parent.DamageService)
local Hitboxes = require(script.Parent.HitboxService)
local Structures = require(script.Parent.StructureService)
local StructureRules = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Game.StructureRules)
type Candidate = { humanoid: Humanoid, distance: number }
local Targets = {}
function Targets.Visible(attacker: Model, target: Model, origin: Vector3, destination: Vector3): boolean
	local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: { Instance } = { attacker, target }
	for model in Fighters.GetAll() do table.insert(excluded, model) end
	local summons = workspace:FindFirstChild("HeroSummons"); if summons then table.insert(excluded, summons) end
	ray.FilterDescendantsInstances = excluded; ray.RespectCanCollide = true
	return workspace:Raycast(origin, destination - origin, ray) == nil
end
function Targets.InCone(attacker: Model, origin: CFrame, range: number, forwardDot: number, includeStructures: boolean, maximum: number): { Humanoid }
	if not Hitboxes.IsFiniteCFrame(origin) then return {} end
	local candidates: { Candidate } = {}
	local seen: { [Humanoid]: boolean } = {}
	local function consider(model: Model, humanoid: Humanoid, root: BasePart)
		local kind = model:GetAttribute("EntityKind")
		if kind ~= "Hero" and kind ~= "Minion" and model:GetAttribute("NativeNarutoClone") ~= true
			and not (includeStructures and StructureRules.isStructure(kind)) then return end
		if not Damage.CanDamage(attacker, model) or not Hitboxes.IsFiniteCFrame(root.CFrame) then return end
		local delta = root.Position - origin.Position
		if delta.Magnitude > range or seen[humanoid] then return end
		if delta.Magnitude > 0.001 and origin.LookVector:Dot(delta.Unit) < forwardDot then return end
		if not Targets.Visible(attacker, model, origin.Position, root.Position) then return end
		seen[humanoid] = true; table.insert(candidates, { humanoid = humanoid, distance = delta.Magnitude })
	end
	for model, fighter in Fighters.GetAll() do consider(model, fighter.humanoid, fighter.root) end
	if includeStructures then
		for model, record in Structures.GetAll() do consider(model, record.humanoid, record.root) end
	end
	table.sort(candidates, function(a: Candidate, b: Candidate) return a.distance < b.distance end)
	local result: { Humanoid } = {}
	for index = 1, math.min(maximum, #candidates) do table.insert(result, candidates[index].humanoid) end
	return result
end
function Targets.Nearest(attacker: Model, origin: CFrame, range: number, forwardDot: number, includeStructures: boolean): Humanoid?
	return Targets.InCone(attacker, origin, range, forwardDot, includeStructures, 1)[1]
end
return Targets
