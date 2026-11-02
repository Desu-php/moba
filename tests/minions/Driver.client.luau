--!strict
local Motion = require(script.Parent:WaitForChild("MinionMotionController"))
Motion.Start()
local camera = workspace.CurrentCamera
if camera then
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 14, -28), Vector3.new(0, 3, 0))
end
-- Verify controller stop restores motors and can be restarted during the full-cap batches.
task.wait(.6)
Motion.Stop()
for _, item in workspace:GetDescendants() do
	if item:IsA("Motor6D") and item:IsDescendantOf(workspace:WaitForChild("NPCs")) then
		assert(item.Transform == CFrame.identity, "stopped minion controller retained a pose")
	end
end
Motion.Start()
print("[MinionVisualClient] PASS stop/reset/restart; visual inspection still required")
