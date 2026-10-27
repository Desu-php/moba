--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Minions = require(Shared.Config.MinionConfig)
local VFX = require(script.Parent.VFXController)
local HUD = {}
local started = false
function HUD.Start()
	if started then return end; started = true
	task.spawn(function()
		local state = ReplicatedStorage:WaitForChild("SurvivalState", 30)
		if not state then warn("[HUD] SurvivalState missing"); return end
		local gui = Instance.new("ScreenGui"); gui.Name = "SurvivalHUD"; gui.ResetOnSpawn = false
		gui.DisplayOrder = 5; gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		local panel = Instance.new("Frame"); panel.Name = "MatchPanel"; panel.AnchorPoint = Vector2.new(0.5, 0)
		panel.Position = UDim2.new(0.5, 0, 0, 8); panel.Size = UDim2.fromOffset(580, 96)
		panel.BackgroundColor3 = Color3.fromRGB(17, 24, 35); panel.BackgroundTransparency = 0.13
		panel.BorderSizePixel = 0; panel.Parent = gui
		local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = panel
		local scale = Instance.new("UIScale"); scale.Parent = panel
		local function label(parent: Instance, name: string, position: UDim2, size: UDim2, fontSize: number): TextLabel
			local item = Instance.new("TextLabel"); item.Name = name; item.Position = position; item.Size = size
			item.BackgroundTransparency = 1; item.Font = Enum.Font.GothamMedium; item.TextSize = fontSize
			item.TextColor3 = Color3.fromRGB(235, 242, 255); item.Parent = parent; return item
		end
		local title = label(panel, "Team", UDim2.fromOffset(12, 5), UDim2.new(1, -24, 0, 24), 16)
		local details = label(panel, "Status", UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 20), 13)
		local rows: { [string]: { text: TextLabel, fill: Frame } } = {}
		local teams: { Folder } = {}
		for _, item in state:GetChildren() do if item:IsA("Folder") then table.insert(teams, item) end end
		table.sort(teams, function(a: Folder, b: Folder) return a.Name < b.Name end)
		for index, team in teams do
			local cell = Instance.new("Frame"); cell.BackgroundTransparency = 1
			cell.Position = UDim2.new((index - 1) / #teams, 12, 0, 55); cell.Size = UDim2.new(1 / #teams, -24, 0, 32); cell.Parent = panel
			local text = label(cell, team.Name, UDim2.new(), UDim2.new(1, 0, 0, 20), 12)
			local track = Instance.new("Frame"); track.Position = UDim2.fromOffset(0, 25)
			track.Size = UDim2.new(1, 0, 0, 4); track.BackgroundColor3 = Color3.fromRGB(50, 55, 65); track.BorderSizePixel = 0; track.Parent = cell
			local fill = Instance.new("Frame"); fill.Size = UDim2.fromScale(1, 1); fill.BorderSizePixel = 0
			fill.BackgroundColor3 = team:GetAttribute("Color") :: Color3; fill.Parent = track
			rows[team.Name] = { text = text, fill = fill }
		end
		local ending = Instance.new("Frame"); ending.Name = "Result"; ending.AnchorPoint = Vector2.new(0.5, 0.5)
		ending.Position = UDim2.fromScale(0.5, 0.45); ending.Size = UDim2.fromOffset(360, 130)
		ending.BackgroundColor3 = Color3.fromRGB(17, 24, 35); ending.BackgroundTransparency = 0.08
		ending.BorderSizePixel = 0; ending.Visible = false; ending.Parent = gui
		local result = label(ending, "ResultText", UDim2.fromOffset(10, 12), UDim2.new(1, -20, 0, 60), 28)
		local explanation = label(ending, "Explanation", UDim2.fromOffset(10, 77), UDim2.new(1, -20, 0, 40), 14)
		explanation.TextWrapped = true
		local accumulator = 0
		RunService.Heartbeat:Connect(function(dt)
			accumulator += dt; if accumulator < 0.25 then return end; accumulator = 0
			local player = Players.LocalPlayer
			local teamId = player:GetAttribute("TeamId")
			local phase = state:GetAttribute("Phase")
			local now = workspace:GetServerTimeNow()
			local startedAt = (state:GetAttribute("StartedAt") or 0) :: number
			local finishedAt = (state:GetAttribute("FinishedAt") or 0) :: number
			local elapsed = if startedAt > 0 then math.max(0, (if phase == "Finished" then finishedAt else now) - startedAt) else 0
			title.Text = "LAST TEAM STANDING  •  " .. (if typeof(teamId) == "string" then teamId else "Наблюдатель")
			local status = if phase == "WaitingForPlayers" then "Ожидание игроков (" .. tostring(state:GetAttribute("MinimumPlayers")) .. ")"
				elseif phase == "Preparing" then "Подготовка " .. math.max(0, math.ceil((state:GetAttribute("PreparationEnds") :: number) - now)) .. " с"
				elseif phase == "Finished" then "Матч завершён" else "Бой"
			details.Text = string.format("%s  •  %02d:%02d  •  Волна %d  •  Мобы %d", status, math.floor(elapsed / 60), math.floor(elapsed % 60),
				(state:GetAttribute("Wave") or 0) :: number, (state:GetAttribute("ActiveNPCs") or 0) :: number)
			for _, team in teams do
				local health = (team:GetAttribute("Health") or 0) :: number
				local maximum = (team:GetAttribute("MaxHealth") or 1) :: number
				local row = rows[team.Name]
				row.text.Text = (if team.Name == teamId then "ВАША БАЗА • " else "БАЗА • ") .. team.Name .. "  " .. math.ceil(health) .. "/" .. maximum
				row.fill.Size = UDim2.fromScale(math.clamp(health / maximum, 0, 1), 1)
			end
			local eliminated = player:GetAttribute("Eliminated") == true
			ending.Visible = phase == "Finished" or eliminated
			local winner = state:GetAttribute("Winner")
			result.Text = if phase == "Finished" and winner == teamId then "ПОБЕДА" elseif eliminated or (phase == "Finished" and winner ~= "") then "ПОРАЖЕНИЕ" else "МАТЧ ЗАВЕРШЁН"
			explanation.Text = if phase == "Finished" then "Победитель: " .. tostring(winner) else "Ваша база уничтожена. Команда выбыла."
			local camera = workspace.CurrentCamera
			if camera then
				local viewport = camera.ViewportSize
				scale.Scale = math.clamp(math.min((viewport.X - 30) / 580, viewport.Y / 600), 0.65, 1)
				local compact = viewport.X < 900 or viewport.Y < 500
				panel.AnchorPoint = Vector2.new(0.5, if compact then 1 else 0)
				panel.Position = if compact then UDim2.new(0.5, 0, 1, -104) else UDim2.new(0.5, 0, 0, 8)
			end
		end)
		local shots = state:WaitForChild("MinionShot") :: RemoteEvent
		shots.OnClientEvent:Connect(function(origin: Vector3, destination: Vector3, kind: string, id: string, target: Model)
			local team = state:FindFirstChild(id)
			local color = if team then team:GetAttribute("Color") else Color3.new(1, 1, 1)
			if kind == "Ranged" then VFX.Projectile(origin, destination, color :: Color3, Minions.ProjectileDuration) end
			if target and target.Parent then VFX.Hit(target, destination, false) end
		end)
	end)
end
return HUD
