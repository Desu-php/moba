--!strict
-- Registry and protection only: no dependencies on damage, combat, or tower scheduling.
local Rules = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Game.StructureRules)
export type Structure = { model: Model, humanoid: Humanoid, root: BasePart, teamId: string, lane: string, kind: string }
local Service = {}
local records: { [Model]: Structure } = {}
function Service.Register(model: Model): Structure
	if records[model] then return records[model] end
	local humanoid = model:FindFirstChildOfClass("Humanoid"); local root = model:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and root:IsA("BasePart") and Rules.isStructure(model:GetAttribute("EntityKind")), "Invalid structure")
	local record: Structure = { model = model, humanoid = humanoid, root = root, teamId = tostring(model:GetAttribute("TeamId")),
		lane = tostring(model:GetAttribute("Lane") or ""), kind = tostring(model:GetAttribute("EntityKind")) }
	records[model] = record; return record
end
function Service.GetAll(): { [Model]: Structure } return records end
function Service.Alive(record: Structure): boolean
	return record.model:IsDescendantOf(workspace) and record.root:IsDescendantOf(record.model)
		and record.humanoid.Parent == record.model and record.humanoid.Health > 0 and record.model:GetAttribute("IsDestroyed") ~= true
end
function Service.Remaining(teamId: string): number
	local count = 0
	for _, record in records do if record.kind == "Tower" and record.teamId == teamId and Service.Alive(record) then count += 1 end end
	return count
end
function Service.CanReceive(model: Model): boolean
	if model:GetAttribute("EntityKind") ~= "Base" then return true end
	return Rules.canReceive(model:GetAttribute("EntityKind"), Service.Remaining(tostring(model:GetAttribute("TeamId"))))
end
function Service.Remove(model: Model) records[model] = nil end
return Service
