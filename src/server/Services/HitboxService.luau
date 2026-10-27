--!strict

local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.CombatConfig)

local HitboxService = {}

function HitboxService.IsFiniteCFrame(frame: CFrame): boolean
	for _, value in { frame:GetComponents() } do
		if value ~= value or math.abs(value) == math.huge then
			return false
		end
	end
	return true
end

local function findHumanoid(part: BasePart): Humanoid?
	-- Accessories and held weapons must not extend the victim's hurtbox.
	if part:FindFirstAncestorWhichIsA("Accessory") or part:FindFirstAncestorWhichIsA("Tool") then
		return nil
	end
	local ancestor: Instance? = part.Parent
	while ancestor and ancestor ~= Workspace do
		if ancestor:IsA("Model") then
			local humanoid = ancestor:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return humanoid
			end
		end
		ancestor = ancestor.Parent
	end
	return nil
end

function HitboxService.GetTargets(attacker: Model, root: BasePart, profile: Config.AttackProfile): ({ Humanoid }, CFrame, Vector3)
	local origin = root.CFrame
	local dimensions, offset = profile.HitboxSize, profile.HitboxOffset
	local size = Vector3.new(dimensions.X, dimensions.Y, dimensions.Z)
	local box = origin * CFrame.new(offset.X, offset.Y, offset.Z)
	if not HitboxService.IsFiniteCFrame(origin) then
		return {}, box, size
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { attacker }
	overlap.MaxParts = 0

	-- Orientation and position are sampled at the authoritative impact time.
	local parts = Workspace:GetPartBoundsInBox(box, size, overlap)
	local targets: { Humanoid } = {}
	local seen: { [Humanoid]: boolean } = {}

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	-- Other fighters in the same swing must not occlude a multi-target hit.
	local occlusionFilter: { Instance } = { attacker }
	local filtered: { [Instance]: boolean } = { [attacker] = true }
	for _, part in parts do
		local humanoid = findHumanoid(part)
		local model = if humanoid then humanoid.Parent else nil
		if model and not filtered[model] then
			filtered[model] = true
			table.insert(occlusionFilter, model)
		end
	end
	rayParams.FilterDescendantsInstances = occlusionFilter
	rayParams.RespectCanCollide = true

	for _, part in parts do
		local humanoid = findHumanoid(part)
		if not humanoid or seen[humanoid] then
			continue
		end
		seen[humanoid] = true
		local character = humanoid.Parent
		if not character or not character:IsA("Model") or character == attacker or humanoid.Health <= 0 then
			continue
		end
		local targetRoot = character:FindFirstChild("HumanoidRootPart")
		if not targetRoot or not targetRoot:IsA("BasePart") or not HitboxService.IsFiniteCFrame(targetRoot.CFrame) then
			continue
		end
		local delta = targetRoot.Position - origin.Position
		if delta.Magnitude > profile.MaxTargetDistance then continue end
		if delta.Magnitude > Config.PositionEpsilon and origin.LookVector:Dot(delta.Unit) < profile.MinimumForwardDot then continue end
		-- A nearby limb alone must not let an attack pass through a solid wall.
		local obstruction = Workspace:Raycast(origin.Position, targetRoot.Position - origin.Position, rayParams)
		if not obstruction or obstruction.Instance:IsDescendantOf(character) then
			table.insert(targets, humanoid)
			if #targets >= profile.MaxTargets then break end
		end
	end
	return targets, box, size
end

return HitboxService
