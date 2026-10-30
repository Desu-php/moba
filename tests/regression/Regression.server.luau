--!strict
-- Test place entry point only. Production never maps this file or its fixtures.
assert(game:GetService("RunService"):IsStudio(), "Regression harness is Studio-only")
local name = workspace:GetAttribute("RegressionSuite")
assert(typeof(name) == "string", "Set Workspace.RegressionSuite in edit mode")
local fixtures = game:GetService("ServerStorage"):WaitForChild("RegressionFixtures")
local runner = fixtures:FindFirstChild(name)
assert(runner and runner:IsA("Script"), "Unknown RegressionSuite: " .. name)
workspace:SetAttribute("CombatOnlyTest", name == "M1")
workspace:SetAttribute("NarutoQuickFixture", name == "Fast")
if name == "M1" then
	local floor = Instance.new("Part"); floor.Name = "TestFloor"; floor.Anchored = true
	floor.Size = Vector3.new(128,1,128); floor.Position = Vector3.new(0,-.5,0); floor.Parent = workspace
	local spawn = Instance.new("SpawnLocation"); spawn.Name = "Spawn"; spawn.Anchored = true
	spawn.Size = Vector3.new(6,1,6); spawn.Position = Vector3.new(20,.5,0); spawn.Duration = 0; spawn.Parent = workspace
elseif name == "Survival" then
	local base = Instance.new("Part"); base.Name = "Baseplate"; base.Anchored = true
	base.Size = Vector3.new(512,1,512); base.Position = Vector3.new(0,-.5,0); base.Parent = workspace
	local sentinel = Instance.new("Folder"); sentinel.Name = "UserObject"; sentinel.Parent = workspace
end
local main = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Main")
assert(main:IsA("Script")); assert(main.Disabled, "Main ran before test mode selection"); main.Disabled = false
local copy = runner:Clone(); copy.Parent = game:GetService("ServerScriptService")
print("[Regression] START " .. name .. "; real runtime clocks and unchanged suite assertions")
