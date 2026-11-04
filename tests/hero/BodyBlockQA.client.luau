--!strict
-- Opt-in Studio companion to BodyBlockQA.server.luau. Restart Play after the test.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() or workspace:GetAttribute("RunBodyBlockQA") ~= true then return end
local player = game:GetService("Players").LocalPlayer
RunService:UnbindFromRenderStep("CombatShoulderCamera")
RunService:UnbindFromRenderStep("CombatMovement")
RunService:BindToRenderStep("BodyBlockQA", Enum.RenderPriority.Character.Value + 2, function()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not humanoid or not root or not root:IsA("BasePart") then return end
	workspace:SetAttribute("BodyBlockQAClientConfigured", not humanoid:GetStateEnabled(Enum.HumanoidStateType.Climbing) and not humanoid.AutoJumpEnabled)
	local target = workspace:GetAttribute("BodyBlockQAClientTarget")
	if typeof(target) == "Vector3" then
		local delta = (target - root.Position) * Vector3.new(1, 0, 1)
		humanoid:Move(if delta.Magnitude > .1 then delta.Unit else Vector3.zero, false)
	end
end)
