--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Players = game:GetService("Players")
local Config = require(Shared.Config.TowerConfig)
local Rules = require(Shared.Game.TowerRules)
local Structures = require(script.Parent.StructureService)
local Fighters = require(script.Parent.FighterStateService)
local Damage = require(script.Parent.DamageService)
local Teams = require(script.Parent.TeamService)
local Factory = require(script.Parent.TowerFactory)
local Hitboxes = require(script.Parent.HitboxService)
export type Tower = { structure: Structures.Structure, logic: Rules.State, crystal: BasePart,
	label: TextLabel, fill: Frame, connections: { RBXScriptConnection } }
local Service = { Event = Instance.new("BindableEvent") }
local records: { [Model]: Tower } = {}
local ids: { [Model]: number } = setmetatable({}, { __mode = "k" })
local models: { [number]: Model } = setmetatable({}, { __mode = "v" })
local serial = 0
local started = false
local function idFor(model: Model): number
	if ids[model] then return ids[model] end
	serial += 1; ids[model] = serial; models[serial] = model; return serial
end
function Service.GetAll(): { [Model]: Tower } return records end
local function mode(tower: Tower, value: string)
	tower.structure.model:SetAttribute("TowerState", value)
	tower.structure.model:SetAttribute("ChargeEndsAt", if tower.logic.shot then tower.logic.contactAt else 0)
end
local function health(tower: Tower)
	local record = tower.structure
	record.model:SetAttribute("CurrentHealth", record.humanoid.Health)
	record.model:SetAttribute("MaxHealth", record.humanoid.MaxHealth)
	tower.label.Text = string.format("%s • %s\n%d / %d", record.teamId, record.lane, math.ceil(record.humanoid.Health), record.humanoid.MaxHealth)
	tower.fill.Size = UDim2.fromScale(math.clamp(record.humanoid.Health / record.humanoid.MaxHealth, 0, 1), 1)
end
local function destroy(tower: Tower)
	if not Rules.destroy(tower.logic) then return end
	local record = tower.structure
	record.model:SetAttribute("IsDestroyed", true); mode(tower, "Destroyed")
	for _, item in record.model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = false; item.CanQuery = false; item.CanTouch = false
			item.Transparency = if item.Name == "Plinth" then 0 else 1
			item.Material = Enum.Material.Slate; item.Color = Color3.fromRGB(47, 50, 58)
		elseif item:IsA("PointLight") then item.Enabled = false end
	end
	tower.label.Text = record.teamId .. " • " .. record.lane .. "\nБАШНЯ РАЗРУШЕНА"; tower.fill.Size = UDim2.fromScale(0, 1)
	Service.Event:Fire("Destroyed", record.model, tower.crystal.Position, tower.crystal.Position, record.teamId, record.lane)
end
local function valid(tower: Tower, model: Model): boolean
	local kind = tostring(model:GetAttribute("EntityKind"))
	if not (Config.TargetPriority :: { [string]: number })[kind] or (kind == "Summon" and not Config.AllowSummons) then return false end
	if kind == "Hero" then
		local player = Players:GetPlayerFromCharacter(model)
		if not player or player.Parent ~= Players or player:GetAttribute("Eliminated") == true then return false end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or not Damage.CanDamage(tower.structure.model, model) then return false end
	if not Hitboxes.IsFiniteCFrame(root.CFrame) or not Hitboxes.IsFiniteCFrame(tower.structure.root.CFrame) then return false end
	if (root.Position - tower.structure.root.Position).Magnitude > Config.Range then return false end
	local excluded: { Instance } = { tower.structure.model, model }
	for actor in Fighters.GetAll() do table.insert(excluded, actor) end
	local summons = workspace:FindFirstChild("HeroSummons"); if summons then table.insert(excluded, summons) end
	local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances = excluded; ray.RespectCanCollide = true
	-- Use the combat center for LOS so a short solid wall cannot be bypassed by the decorative crystal's height.
	return workspace:Raycast(tower.structure.root.Position, root.Position - tower.structure.root.Position, ray) == nil
end
function Service.CancelAll()
	for _, tower in records do
		Rules.cancel(tower.logic)
		if not tower.logic.destroyed then mode(tower, "Idle") end
	end
end
function Service.Update(now: number)
	local match = Teams.GetState()
	if not match or match.phase ~= "InProgress" then Service.CancelAll(); return end
	for model, tower in records do
		if not model:IsDescendantOf(workspace) or tower.structure.humanoid.Parent ~= model or not tower.structure.root:IsDescendantOf(model) then
			Rules.destroy(tower.logic); Structures.Remove(model)
			for _, connection in tower.connections do connection:Disconnect() end
			records[model] = nil; continue
		end
		if tower.structure.humanoid.Health <= 0 then destroy(tower) end
		if tower.logic.destroyed then continue end
		if not Damage.CanAct(model) then Rules.cancel(tower.logic); mode(tower, "Idle"); continue end
		local pending = tower.logic.shot
		if pending then
			local target = models[pending]
			local confirmed = Rules.contact(tower.logic, now, target ~= nil and valid(tower, target), true)
			if confirmed and target then
				local humanoid = target:FindFirstChildOfClass("Humanoid")
				local root = target:FindFirstChild("HumanoidRootPart")
				mode(tower, "Attacking"); model:SetAttribute("LastShotAt", now)
				if humanoid and root and root:IsA("BasePart") then
					local position = root.Position
					Damage.Apply(model, humanoid, Config.Damage)
					Service.Event:Fire("Shot", model, tower.crystal.Position, position, tower.structure.teamId, tower.structure.lane)
				end
			elseif not tower.logic.shot then mode(tower, "Idle") end
			continue
		end
		local samples: { Rules.Candidate } = {}
		for actor, fighter in Fighters.GetAll() do
			table.insert(samples, { id = idFor(actor), kind = tostring(actor:GetAttribute("EntityKind")),
				distance = (fighter.root.Position - tower.structure.root.Position).Magnitude, valid = valid(tower, actor) })
		end
		local target = Rules.choose(tower.logic, samples, now, Config.TargetPriority, Config.AllowSummons)
		tower.logic.target = target
		if target and Rules.begin(tower.logic, target, now, Config.Windup, Config.AttackInterval) then mode(tower, "Charging")
		elseif now >= ((model:GetAttribute("LastShotAt") or 0) :: number) + Config.Visual.ProjectileDuration then mode(tower, "Idle") end
	end
end
function Service.Start(map: Folder)
	if started then return end; started = true
	local container = Factory.Build(map)
	for _, model in container:GetChildren() do
		if not model:IsA("Model") or model:GetAttribute("ManagedTower") ~= true then continue end
		local record = Structures.Register(model)
		local crystal = model:FindFirstChild("Crystal"); assert(crystal and crystal:IsA("BasePart"))
		local board = Instance.new("BillboardGui"); board.Name = "TowerHealth"; board.Size = UDim2.fromOffset(170, 54)
		board.StudsOffset = Vector3.new(0, 10, 0); board.MaxDistance = 170; board.AlwaysOnTop = true; board.Parent = record.root
		local label = Instance.new("TextLabel"); label.Size = UDim2.new(1, 0, 1, -8); label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold; label.TextSize = 14; label.TextColor3 = Color3.new(1, 1, 1); label.TextStrokeTransparency = 0.25; label.Parent = board
		local track = Instance.new("Frame"); track.Size = UDim2.new(1, 0, 0, 5); track.Position = UDim2.new(0, 0, 1, -5)
		track.BackgroundColor3 = Color3.fromRGB(25, 28, 35); track.BorderSizePixel = 0; track.Parent = board
		local fill = Instance.new("Frame"); fill.BackgroundColor3 = crystal.Color; fill.BorderSizePixel = 0; fill.Parent = track
		local tower: Tower = { structure = record, logic = Rules.new(), crystal = crystal, label = label, fill = fill, connections = {} }
		records[model] = tower; health(tower)
		table.insert(tower.connections, record.humanoid.HealthChanged:Connect(function()
			health(tower); if record.humanoid.Health <= 0 then destroy(tower) end
		end))
	end
	Damage.Applied.Event:Connect(function(attacker: Model, victim: Model, amount: number)
		if amount <= 0 then return end
		local killed = records[victim]
		if killed and killed.structure.humanoid.Health <= 0 then
			destroy(killed)
		end
		if attacker:GetAttribute("EntityKind") ~= "Hero" or victim:GetAttribute("EntityKind") ~= "Hero" then return end
		local victimRoot = victim:FindFirstChild("HumanoidRootPart"); if not victimRoot or not victimRoot:IsA("BasePart") then return end
		local now = workspace:GetServerTimeNow()
		for _, tower in records do
			if victim:GetAttribute("TeamId") == tower.structure.teamId and (victimRoot.Position - tower.structure.root.Position).Magnitude <= Config.Range
				and valid(tower, attacker) then Rules.aggress(tower.logic, idFor(attacker), now, Config.AggroDuration, true) end
		end
	end)
end
return Service
