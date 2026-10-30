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
	elseif mode == "prepare" then result.accepted = abilities.TryCast("Rasengan"); task.wait(.15)
	elseif mode == "cast" then
		result.accepted = abilities.TryCast(data)
		if data == "Rasengan" then task.wait(2.2); result.attack = combat.TryAttack(); task.wait(1.3)
		else task.wait(0.8) end
	elseif mode == "status" and typeof(data) == "string" then
		-- The production HUD refreshes at5Hz; assert eventual presentation within a bounded window.
		local deadline = os.clock() + 1.5
		repeat
			local gui = player.PlayerGui:FindFirstChild("SurvivalHUD")
			local label = if gui then gui:FindFirstChild("ResultText", true) else nil
			if label and label:IsA("TextLabel") and label.Text == data then break end
			task.wait()
		until os.clock() >= deadline
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
	result.portraitSlots = 0
	if gui then
		for _, item in gui:GetDescendants() do if item:IsA("ViewportFrame") then result.portraitSlots += 1 end end
		local resultText = gui:FindFirstChild("ResultText", true)
		result.resultText = if resultText and resultText:IsA("TextLabel") then resultText.Text else ""
	end
	local lower = player.PlayerGui:FindFirstChild("AbilityHUD")
	local function barText(name: string): string
		local track = if lower then lower:FindFirstChild(name, true) else nil
		local value = if track then track:FindFirstChild("Value") else nil
		return if value and value:IsA("TextLabel") then value.Text else ""
	end
	result.health = barText("Health"); result.mana = barText("Mana")
	local oldHUD = player.PlayerGui:FindFirstChild("HeroHUD")
	result.duplicateStats = oldHUD ~= nil and oldHUD:FindFirstChild("ProgressionPanel", true) ~= nil
	result.debugText = false
	for _, screen in { gui, lower, oldHUD } do
		if screen then for _, object in screen:GetDescendants() do
			if object:IsA("TextLabel") and (string.find(object.Text, "Раунд", 1, true) or string.find(object.Text, "Волна", 1, true) or string.find(object.Text, "Мобы", 1, true)) then result.debugText = true end
		end end
	end
	for _, child in player.PlayerGui:GetChildren() do
		if child.Name == "SurvivalHUD" or child.Name == "HeroHUD" or child.Name == "AbilityHUD" then result.guiCount += 1 end
	end
	result.effects = 0
	for _, name in { "LocalHeroVFX", "LocalTowerVFX" } do
		local folder = workspace:FindFirstChild(name); if folder then result.effects += #folder:GetChildren() end
	end
	driver:FireServer(id, result)
end)
