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
			CombatController.TryAttack()
		end
	end)
end

return InputController
