--!strict
-- Humanoid initialization may restore CanCollide on copied rig parts. Collision
-- groups are the authoritative nonblocking guarantee, independent of that flag.
local Physics = game:GetService("PhysicsService")
local Collision = {}
local ready = false
function Collision.Apply(model: Model)
	if not ready then
		for _, name in { "SurvivalHeroes", "SurvivalMinions", "SurvivalSummons" } do
			if not Physics:IsCollisionGroupRegistered(name) then Physics:RegisterCollisionGroup(name) end
		end
		for _, name in { "SurvivalHeroes", "SurvivalMinions", "SurvivalSummons" } do
			Physics:CollisionGroupSetCollidable("SurvivalSummons", name, false)
		end
		-- Keep Default collidable: navigation's world raycasts still see terrain.
		ready = true
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CollisionGroup = "SurvivalSummons"
			item.CanCollide = false; item.CanTouch = false
		end
	end
end
return Collision
