--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local driver = ReplicatedStorage:WaitForChild("SurvivalTestDriver") :: RemoteEvent
local controller = require(player.PlayerScripts:WaitForChild("Client"):WaitForChild("Controllers").CombatController)
local attack = ReplicatedStorage:WaitForChild("CombatRemotes"):WaitForChild("BasicAttack") :: RemoteEvent
driver.OnClientEvent:Connect(function(sequence: number, mode: string)
	if mode == "attack" or mode == "combo" then
		for _ = 1, if mode == "combo" then 4 else 1 do
			attack:FireServer(controller.NextRequestId(), player.Character)
			task.wait(0.4)
		end
	end
	local state = ReplicatedStorage:FindFirstChild("SurvivalState")
	driver:FireServer(sequence, {
		hud = player.PlayerGui:FindFirstChild("SurvivalHUD") ~= nil,
		phase = if state then state:GetAttribute("Phase") else nil,
		winner = if state then state:GetAttribute("Winner") else nil,
	})
end)
driver:FireServer(0, {})
