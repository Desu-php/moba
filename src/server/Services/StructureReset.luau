--!strict
-- Capture only existing managed visuals. Unknown children are never deleted.
export type Snapshot = { restore: () -> () }
local Reset = {}
function Reset.capture(model: Model): Snapshot
	local actions: { () -> () } = {}
	for _, item in model:GetDescendants() do
		if model:GetAttribute("EntityKind") == "Tower" and item:GetAttribute("StructureCosmetic") == nil
			and (not item:IsA("PointLight") or not item.Parent or item.Parent:GetAttribute("StructureCosmetic") == nil) then continue end
		if item:IsA("BasePart") then
			local color, material, transparency = item.Color, item.Material, item.Transparency
			local collide, query, touch = item.CanCollide, item.CanQuery, item.CanTouch
			local frame, size = item.CFrame, item.Size
			table.insert(actions, function()
				if not item:IsDescendantOf(model) then return end
				item.Color = color; item.Material = material; item.Transparency = transparency
				item.CanCollide = collide; item.CanQuery = query; item.CanTouch = touch
				item.CFrame = frame; item.Size = size
			end)
		elseif item:IsA("PointLight") then
			local enabled, brightness = item.Enabled, item.Brightness
			table.insert(actions, function() if item:IsDescendantOf(model) then item.Enabled = enabled; item.Brightness = brightness end end)
		end
	end
	return { restore = function() for _, action in actions do action() end end }
end
function Reset.humanoid(model: Model, health: number): Humanoid
	local old = model:FindFirstChildOfClass("Humanoid")
	if old then old:Destroy() end
	local humanoid = Instance.new("Humanoid")
	-- Dead humanoids cannot be revived by assigning Health. Use a fresh one.
	humanoid.BreakJointsOnDeath = false; humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = health; humanoid.Health = health; humanoid.Parent = model
	return humanoid
end
return Reset
