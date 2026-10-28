--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.AbilityConfig)
local Rounds = require(script.Parent.RoundController)
type Effect = { parts: { BasePart }, at: number, untilAt: number, origin: Vector3, sphere: Model?, wind: CFrame?, distance: number?, hit: boolean? }
local VFX = {}
local effects: { Effect } = {}
local seen: { [Model]: number } = setmetatable({}, { __mode = "k" })
local folder: Folder? = nil
local started = false
local function remove(index: number)
	for _, part in effects[index].parts do part:Destroy() end
	table.remove(effects, index)
end
local function create(position: Vector3, sphere: Model?): Effect?
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > Config.Visual.ViewDistance then return nil end
	while #effects >= Config.Visual.MaxEffects do remove(1) end
	local now = workspace:GetServerTimeNow()
	local effect: Effect = { parts = {}, at = now, untilAt = now + (if sphere then Config.Abilities.SpiralSphere.Duration else Config.Visual.SmokeLifetime), origin = position, sphere = sphere }
	for i = 1, (if sphere then 4 else 6) do
		local part = Instance.new("Part"); part.Name = if sphere then "SpiralLight" else "CloneSmoke"
		part.Shape = Enum.PartType.Ball; part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
		part.Size = Vector3.one * (if sphere then 0.4 else 0.9)
		part.Material = if sphere then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Color = if sphere then Color3.fromRGB(93 + i * 25, 210, 255) else Color3.fromRGB(190, 210, 221)
		part.CFrame = CFrame.new(position); part.Parent = folder; table.insert(effect.parts, part)
	end
	table.insert(effects, effect); return effect
end
function VFX.Event(message: any)
	if message.kind == "Smoke" or message.kind == "SphereHit" then
		if typeof(message.position) == "Vector3" then
			local effect = create(message.position, nil)
			if effect and message.kind == "SphereHit" then
				effect.hit = true
				for _, part in effect.parts do part.Color = Color3.fromRGB(95, 225, 255); part.Material = Enum.Material.Neon end
			end
		end
	elseif message.kind == "WindBurst" and typeof(message.frame) == "CFrame" then
		local effect = create(message.frame.Position, nil)
		if effect then
			effect.wind = message.frame; effect.distance = message.distance; effect.untilAt = effect.at + Config.Wind.VisualDuration
			for _, part in effect.parts do part.Color = Color3.fromRGB(180, 255, 226); part.Material = Enum.Material.Neon end
		end
	end
end
function VFX.Start()
	if started then return end; started = true
	Rounds.Watch(function() for i = #effects, 1, -1 do remove(i) end; table.clear(seen) end)
	local created = Instance.new("Folder"); created.Name = "LocalHeroVFX"; created.Parent = workspace; folder = created
	RunService.PreRender:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do
			local model = player.Character; if not model then continue end
			local serial = model:GetAttribute("AbilityCastId")
			if typeof(serial) ~= "number" or serial <= (seen[model] or 0) then continue end
			local id = model:GetAttribute("AbilityId")
			local ends = model:GetAttribute("AbilityEndsAt")
			if not ends or typeof(ends) ~= "number" or now >= ends or id == "" then continue end
			seen[model] = serial
			if id == "SpiralSphere" then
				local effect = create(model:GetPivot().Position, model)
				if effect then
					effect.untilAt = ends
					local at = model:GetAttribute("AbilityStartedAt"); if typeof(at) == "number" then effect.at = at end
				end
			end
		end
		for i = #effects, 1, -1 do
			local effect = effects[i]; local model = effect.sphere
			if now >= effect.untilAt or (model and (not model.Parent or model:GetAttribute("AbilityId") ~= "SpiralSphere")) then remove(i); continue end
			local elapsed = now - effect.at
			if effect.wind then
				local progress = math.clamp(elapsed / Config.Wind.VisualDuration, 0, 1)
				for j, part in effect.parts do
					local angle = j * math.pi / 3 + progress * 5
					local radius = 0.8 + progress * 2.8
					part.CFrame = effect.wind * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, -progress * (effect.distance or Config.Wind.Range))
					part.Size = Vector3.new(1.2, 0.3, 2.3) * (0.5 + progress); part.Transparency = progress
				end
			elseif model then
				local hand = model:FindFirstChild("RightHand")
				if not hand or not hand:IsA("BasePart") then remove(i); continue end
				local center = hand.CFrame * CFrame.new(0, -0.25, -0.3)
				for j, part in effect.parts do
					local angle = now * 17 + j * math.pi * 2 / 3
					local radius = if j == 1 then 0 else 0.47
					part.Size = Vector3.one * (if j == 1 then math.min(0.95, 0.3 + elapsed * 2) else 0.24)
					part.CFrame = center * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, math.sin(angle * 1.4) * radius * 0.5)
				end
			else
				local progress = elapsed / Config.Visual.SmokeLifetime
				for j, part in effect.parts do
					local angle = j * math.pi / 3
					part.Position = effect.origin + Vector3.new(math.cos(angle) * progress * 2, progress * 1.7, math.sin(angle) * progress * 2)
					part.Size = Vector3.one * (0.7 + progress * (if effect.hit then 2.5 else 1.3)); part.Transparency = 0.25 + progress * 0.75
				end
			end
		end
	end)
end
return VFX
