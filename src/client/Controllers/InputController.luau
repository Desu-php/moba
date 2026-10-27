--!strict

local UserInputService = game:GetService("UserInputService")
local CombatController = require(script.Parent.CombatController)

local InputController = {}
local started = false

function InputController.Start()
	if started then
		return
	end
	started = true
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or UserInputService:GetFocusedTextBox() or game:GetService("Players").LocalPlayer:GetAttribute("ShopOpen") == true then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
			local abilityGui = if playerGui then playerGui:FindFirstChild("AbilityHUD") else nil
			if playerGui and abilityGui then
				for _, object in playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
					if object:IsDescendantOf(abilityGui) then return end
				end
			end
			CombatController.TryAttack()
		end
	end)
end

return InputController
