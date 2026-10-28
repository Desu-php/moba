--!strict
assert(game:GetService("RunService"):IsStudio())
local Storage = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer
local driver = Storage:WaitForChild("RoundTestDriver") :: RemoteEvent
local state = Storage:WaitForChild("SurvivalState")
local shop = Storage:WaitForChild("ItemShop") :: RemoteEvent
local ability = Storage:WaitForChild("HeroAbility") :: RemoteEvent
local attack = Storage:WaitForChild("CombatRemotes"):WaitForChild("BasicAttack") :: RemoteEvent
local controllers = player.PlayerScripts:WaitForChild("Client"):WaitForChild("Controllers")
local combat = require(controllers:WaitForChild("CombatController"))
local abilities = require(controllers:WaitForChild("AbilityController"))
local shopSerial = 1000
driver.OnClientEvent:Connect(function(id: number, mode: string, data: any)
	local result: any = {}
	if mode == "attack" then result.accepted = combat.TryAttack(); task.wait(0.6)
	elseif mode == "prepare" then result.accepted = abilities.TryCast("WindPalm")
	elseif mode == "cast" then result.accepted = abilities.TryCast(data); task.wait(0.8)
	elseif mode == "buy" then
		shopSerial += 1; shop:FireServer(shopSerial, "IronBlade", state:GetAttribute("RoundId")); task.wait(0.3)
	elseif mode == "stale" then
		-- Current Character + old round tests the epoch independently of character validation.
		attack:FireServer(combat.NextRequestId(), player.Character, data)
		ability:FireServer(100000 + id, player.Character, "ShadowClones", data)
		shopSerial += 1; shop:FireServer(shopSerial, "IronBlade", data)
		task.wait(0.5)
	end
	result.roundId = state:GetAttribute("RoundId"); result.phase = state:GetAttribute("Phase")
	local gui = player.PlayerGui:FindFirstChild("SurvivalHUD")
	local title = if gui then gui:FindFirstChild("Team", true) else nil
	result.title = if title and title:IsA("TextLabel") then title.Text else ""
	result.guiCount = 0
	for _, child in player.PlayerGui:GetChildren() do
		if child.Name == "SurvivalHUD" or child.Name == "HeroHUD" or child.Name == "AbilityHUD" then result.guiCount += 1 end
	end
	result.effects = 0
	for _, name in { "LocalHeroVFX", "LocalTowerVFX" } do
		local folder = workspace:FindFirstChild(name); if folder then result.effects += #folder:GetChildren() end
	end
	driver:FireServer(id, result)
end)
