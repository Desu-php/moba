--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.CombatConfig)
local Workspace = game:GetService("Workspace")
local KnockbackService = {}

-- Stun acquires temporary server ownership before this impulse is applied.
function KnockbackService.Apply(attacker: BasePart, target: BasePart, profile: Config.AttackProfile)
	if target.Anchored or not target.Parent then return end
	local delta = target.Position - attacker.Position
	local horizontal = Vector3.new(delta.X, 0, delta.Z)
	if horizontal.Magnitude < Config.PositionEpsilon then
		local look = attacker.CFrame.LookVector
		horizontal = Vector3.new(look.X, 0, look.Z)
	end
	if horizontal.Magnitude < Config.PositionEpsilon then return end
	local direction = horizontal.Unit
	local speed = profile.KnockbackVelocity
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker.Parent :: Instance, target.Parent :: Instance }
	params.RespectCanCollide = true
	local size = profile.KnockbackProbeSize
	local wall = Workspace:Blockcast(target.CFrame, Vector3.new(size.X, size.Y, size.Z), direction * speed * profile.KnockbackWallProbeTime, params)
	if wall then
		speed = math.min(speed, math.max(0, wall.Distance - profile.KnockbackWallPadding) / profile.KnockbackWallProbeTime)
	end
	local desired = direction * speed + Vector3.new(0, profile.KnockbackUpVelocity, 0)
	if desired.Magnitude > profile.MaxKnockbackSpeed then desired = desired.Unit * profile.MaxKnockbackSpeed end
	local mass = target.AssemblyMass
	if mass <= 0 or mass == math.huge or mass ~= mass then return end
	local current = target.AssemblyLinearVelocity
	if current.Magnitude ~= current.Magnitude or current.Magnitude == math.huge then
		target.AssemblyLinearVelocity = Vector3.zero
		current = Vector3.zero
	end
	-- Set a bounded initial velocity via a mass-scaled delta impulse, never stack it.
	target:ApplyImpulse((desired - current) * mass)
end

return KnockbackService
