--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.TowerConfig)
type Effect = { object: BasePart, tween: Tween, endsAt: number }
local Controller = {}
local started = false
local effects: { Effect } = {}
local function remove(index: number)
	local effect = effects[index]; effect.tween:Cancel(); effect.object:Destroy(); table.remove(effects, index)
end
function Controller.GetActiveCount(): number return #effects end
function Controller.Start()
	if started then return end; started = true
	task.spawn(function()
		local state = ReplicatedStorage:WaitForChild("SurvivalState", 30); if not state then return end
		local event = state:WaitForChild("TowerEvent") :: RemoteEvent
		local folder = Instance.new("Folder"); folder.Name = "LocalTowerVFX"; folder.Parent = workspace
		event.OnClientEvent:Connect(function(kind: string, _model: Model, origin: Vector3, destination: Vector3, teamId: string)
			local camera = workspace.CurrentCamera
			if camera and (origin - camera.CFrame.Position).Magnitude > Config.Visual.ViewDistance then return end
			while #effects >= Config.Visual.MaxEffects do remove(1) end
			local team = state:FindFirstChild(teamId)
			local color = if team then team:GetAttribute("Color") else Color3.new(1, 1, 1)
			local object = Instance.new("Part"); object.Name = "Tower" .. kind; object.Shape = Enum.PartType.Ball
			object.Anchored = true; object.CanCollide = false; object.CanQuery = false; object.CanTouch = false; object.CastShadow = false
			object.Material = Enum.Material.Neon; object.Color = color :: Color3; object.Position = origin
			object.Size = Vector3.one * (if kind == "Destroyed" then 3 else 0.85); object.Parent = folder
			local duration = if kind == "Destroyed" then Config.Visual.RuinFlashLifetime else Config.Visual.ProjectileDuration
			local tween = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad), {
				Position = destination, Size = Vector3.one * (if kind == "Destroyed" then 12 else 0.25), Transparency = 1,
			})
			table.insert(effects, { object = object, tween = tween, endsAt = os.clock() + duration }); tween:Play()
		end)
		RunService.PreRender:Connect(function()
			for index = #effects, 1, -1 do if os.clock() >= effects[index].endsAt then remove(index) end end
			local map = workspace:FindFirstChild("Map"); local towers = if map then map:FindFirstChild("Towers") else nil
			if not towers then return end
			local now = workspace:GetServerTimeNow()
			for _, model in towers:GetChildren() do
				if model:GetAttribute("ManagedTower") ~= true then continue end
				local crystal = model:FindFirstChild("Crystal")
				if not crystal or not crystal:IsA("BasePart") then continue end
				local light = crystal:FindFirstChildOfClass("PointLight")
				local charging = model:GetAttribute("TowerState") == "Charging"
				local chargeEnd = (model:GetAttribute("ChargeEndsAt") or 0) :: number
				local progress = if charging then math.clamp(1 - (chargeEnd - now) / Config.Windup, 0, 1) else 0
				crystal.Size = Vector3.one * (2.6 + progress * 1.5)
				if light then light.Brightness = 0.8 + progress * 5 end
			end
		end)
	end)
end
return Controller
