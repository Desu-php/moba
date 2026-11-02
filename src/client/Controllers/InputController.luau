--!strict

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CombatController = require(script.Parent.CombatController)
local AbilityConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.AbilityConfig)
local interruptKeys: { [string]: boolean } = {}
for _, ability in AbilityConfig.Abilities do interruptKeys[ability.Key] = true end
for key in (AbilityConfig.InputAliases :: { [string]: string }) do interruptKeys[key] = true end

local InputController = {}
local started = false
local held = false
local nextPoll = 0

function InputController.Start()
	if started then
		return
	end
	started = true
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		-- A skill/command key interrupts a held attack; it cannot manufacture M1.
		if interruptKeys[input.KeyCode.Name] then held = false end
		if gameProcessed or UserInputService:GetFocusedTextBox() or game:GetService("Players").LocalPlayer:GetAttribute("ShopOpen") == true then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if game:GetService("Players").LocalPlayer:GetAttribute("SelectingCloneTarget") == true then return end
			local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
			local abilityGui = if playerGui then playerGui:FindFirstChild("AbilityHUD") else nil
			if playerGui and abilityGui then
				for _, object in playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
					if object:IsDescendantOf(abilityGui) then return end
				end
			end
			held = true
			CombatController.TryAttack()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then held = false end
	end)
	UserInputService.WindowFocusReleased:Connect(function() held = false end)
	local player = game:GetService("Players").LocalPlayer
	player.CharacterAdded:Connect(function() held = false end)
	player.CharacterRemoving:Connect(function() held = false end)
	require(script.Parent.RoundController).Watch(function() held = false end)
	RunService.Heartbeat:Connect(function()
		if not held or os.clock() < nextPoll then return end
		nextPoll = os.clock() + 0.05
		local player = game:GetService("Players").LocalPlayer
		if UserInputService:GetFocusedTextBox() or player:GetAttribute("ShopOpen") == true
			or player:GetAttribute("SelectingCloneTarget") == true or game:GetService("GuiService").MenuIsOpen then
			held = false; return
		end
		CombatController.TryHeldAttack()
	end)
end

return InputController
