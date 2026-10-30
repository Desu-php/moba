--!strict
assert(game:GetService("RunService"):IsStudio(), "Regression harness is Studio-only")
local name = workspace:GetAttribute("RegressionSuite")
assert(typeof(name) == "string")
local fixture = game:GetService("ReplicatedStorage"):WaitForChild("RegressionDrivers"):FindFirstChild(name)
assert(fixture and fixture:IsA("LocalScript"), "Unknown regression driver")
local copy = fixture:Clone(); copy.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
