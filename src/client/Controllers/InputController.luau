--!strict

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CombatController = require(script.Parent.CombatController)
local Camera = require(script.Parent.CameraController)
local Abilities = require(script.Parent.AbilityController)
local CameraRules = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Combat.CombatCameraRules)
local AbilityConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.AbilityConfig)
local interruptKeys: { [string]: boolean } = {}
for _, ability in AbilityConfig.Abilities do interruptKeys[ability.Key] = true end
for key in (AbilityConfig.InputAliases :: { [string]: string }) do interruptKeys[key] = true end
interruptKeys.R = true; interruptKeys.Y = true -- Follow/Hold orders also release a held attack.

local InputController = {}
local started = false
local held = false
local nextPoll = 0

function InputController.Start()
	if started then
		return
	end
	started = true
	local player = game:GetService("Players").LocalPlayer
	if UserInputService.KeyboardEnabled then
		-- Own PC locomotion so user-selected ClickToMove never competes with aim clicks.
		-- The existing Humanoid still applies authoritative speed, jump and control locks.
		task.spawn(function()
			local scripts = player:WaitForChild("PlayerScripts")
			local module = scripts:WaitForChild("PlayerModule", 15)
			if module and module:IsA("ModuleScript") then
				-- Roblox injects PlayerModule at runtime, outside the Rojo source map.
				local loadRuntimeModule: any = require
				local defaultPlayer = loadRuntimeModule(module)
				defaultPlayer:GetControls():Disable()
			end
		end)
		RunService:BindToRenderStep("CombatMovement", Enum.RenderPriority.Character.Value + 1, function()
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if not humanoid then return end
			if not Camera.IsCaptured() or humanoid.Health <= 0 then player:Move(Vector3.zero, false); humanoid.Jump = false; return end
			local x = (if UserInputService:IsKeyDown(Enum.KeyCode.D) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.A) then 1 else 0)
			local z = (if UserInputService:IsKeyDown(Enum.KeyCode.S) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.W) then 1 else 0)
			x, z = CameraRules.move(x, z)
			player:Move(Vector3.new(x, 0, z), true)
			humanoid.Jump = UserInputService:IsKeyDown(Enum.KeyCode.Space)
		end)
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		-- A skill/command key interrupts a held attack; it cannot manufacture M1.
		if interruptKeys[input.KeyCode.Name] then held = false end
		if gameProcessed or not Camera.IsCaptured() then
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
			if Abilities.TryThrowRasenshuriken() then held=false; return end
			held = true
			CombatController.TryAttack()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then held = false end
	end)
	UserInputService.WindowFocusReleased:Connect(function() held = false end)
	player.CharacterAdded:Connect(function() held = false end)
	player.CharacterRemoving:Connect(function() held = false end)
	require(script.Parent.RoundController).Watch(function() held = false end)
	RunService.Heartbeat:Connect(function()
		if not held or os.clock() < nextPoll then return end
		nextPoll = os.clock() + 0.05
		local player = game:GetService("Players").LocalPlayer
		if not Camera.IsCaptured() or player:GetAttribute("SelectingCloneTarget") == true then
			held = false; return
		end
		CombatController.TryHeldAttack()
	end)
end

return InputController
