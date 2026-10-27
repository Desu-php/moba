--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.AbilityConfig)
local Heroes = require(Shared.Config.HeroConfig)
local Controller = require(script.Parent.AbilityController)
local HUD = {}
local started = false
function HUD.Start()
	if started then return end; started = true; Controller.Start()
	local gui = Instance.new("ScreenGui"); gui.Name = "AbilityHUD"; gui.ResetOnSpawn = false; gui.DisplayOrder = 8
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame"); panel.Name = "Abilities"; panel.Size = UDim2.fromOffset(366, 108)
	panel.BackgroundColor3 = Color3.fromRGB(19, 27, 41); panel.BackgroundTransparency = 0.1; panel.BorderSizePixel = 0; panel.Parent = gui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = panel
	local scale = Instance.new("UIScale"); scale.Parent = panel
	local title = Instance.new("TextLabel"); title.Size = UDim2.new(1, -16, 0, 24); title.Position = UDim2.fromOffset(8, 0)
	title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(255, 188, 80); title.Font = Enum.Font.GothamBold; title.TextSize = 14; title.Parent = panel
	local buttons: { [string]: TextButton } = {}
	for index, id in Config.Order do
		local button = Instance.new("TextButton"); button.Name = id; button.Size = UDim2.fromOffset(114, 62)
		button.Position = UDim2.fromOffset(8 + (index - 1) * 118, 26); button.BackgroundColor3 = Color3.fromRGB(44, 65, 83)
		button.TextColor3 = Color3.new(1, 1, 1); button.TextSize = 12; button.TextWrapped = true; button.Font = Enum.Font.GothamMedium
		button.BorderSizePixel = 0; button.Parent = panel; local rounded = Instance.new("UICorner"); rounded.CornerRadius = UDim.new(0, 7); rounded.Parent = button
		button.Activated:Connect(function() Controller.TryCast(id) end); buttons[id] = button
	end
	local message = Instance.new("TextLabel"); message.Size = UDim2.new(1, -16, 0, 18); message.Position = UDim2.fromOffset(8, 89)
	message.BackgroundTransparency = 1; message.TextColor3 = Color3.fromRGB(210, 220, 235); message.TextSize = 11; message.Font = Enum.Font.Gotham; message.Parent = panel
	local nextUpdate = 0
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow(); if now < nextUpdate then return end; nextUpdate = now + Config.Visual.HUDInterval
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize; local portrait = viewport.Y > viewport.X
			scale.Scale = math.clamp(math.min((viewport.X - 24) / 366, viewport.Y / 440), 0.65, 1)
			panel.AnchorPoint = Vector2.new(0.5, if portrait then 0 else 1)
			panel.Position = if portrait then UDim2.new(0.5, 0, 0, 162) else UDim2.new(0.5, 0, 1, -112)
		end
		local hero = Heroes.Heroes[tostring(Players.LocalPlayer:GetAttribute("HeroId"))]
		title.Text = if hero then hero.Name else "Герой"
		local unavailable = Controller.Unavailable()
		message.Text = Controller.GetMessage()
		for id, button in buttons do
			local ability = Config.Abilities[id]; local remaining = Controller.Remaining(id)
			button.Text = ability.Key .. " · " .. ability.Name .. "\n" .. (if remaining > 0 then string.format("%.1f с", remaining) else unavailable or "Готово")
			button.Active = unavailable == nil and remaining <= 0; button.AutoButtonColor = button.Active
			button.BackgroundColor3 = if button.Active then Color3.fromRGB(46, 91, 117) else Color3.fromRGB(42, 46, 58)
		end
	end)
end
return HUD
