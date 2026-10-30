--!strict
assert(game:GetService("RunService"):IsStudio())
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TowerTestDriver") :: RemoteEvent
local controllers = player.PlayerScripts:WaitForChild("Client"):WaitForChild("Controllers")
local shots = 0
local towerEvent = ReplicatedStorage:WaitForChild("SurvivalState"):WaitForChild("TowerEvent") :: RemoteEvent
towerEvent.OnClientEvent:Connect(function(kind: string) if kind == "Shot" then shots += 1 end end)
remote.OnClientEvent:Connect(function(id: number, mode: string)
	local result: any = {}
	if mode == "attack" then
		result.accepted = require(controllers.CombatController).TryAttack(); task.wait(0.6)
	else
		local gui = player.PlayerGui
		local survival = gui:FindFirstChild("SurvivalHUD"); local panel = if survival then survival:FindFirstChild("MatchPanel") else nil
		local labels, portraits = 0, 0
		for _, item in workspace:GetDescendants() do if item:IsA("BillboardGui") and item.Name == "TowerHealth" then labels += 1 end end
		if panel then for _, item in panel:GetDescendants() do if item:IsA("ViewportFrame") then portraits += 1 end end end
		local safe = true; local effects = workspace:FindFirstChild("LocalTowerVFX")
		if effects then for _, item in effects:GetChildren() do if item:IsA("BasePart") then safe = safe and not item.CanCollide and not item.CanQuery and not item.CanTouch end end end
		result = { towerLabels = labels, portraitSlots = portraits, hero = gui:FindFirstChild("HeroHUD") ~= nil, abilities = gui:FindFirstChild("AbilityHUD") ~= nil,
			safeEffects = safe, effectCount = require(controllers.TowerVFXController).GetActiveCount(), shots = shots }
	end
	remote:FireServer(id, result)
end)
