--!strict
assert(game:GetService("RunService"):IsStudio())
local player = game:GetService("Players").LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("JungleTestDriver") :: RemoteEvent
remote.OnClientEvent:Connect(function()
	local camps = workspace:FindFirstChild("JungleCamps")
	remote:FireServer(camps ~= nil and #camps:GetChildren() == 4, player.PlayerGui:FindFirstChild("AbilityHUD") ~= nil)
end)
