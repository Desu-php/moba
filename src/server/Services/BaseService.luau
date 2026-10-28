--!strict
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.GameModeConfig)
local Structures = require(script.Parent.StructureService)
local Reset = require(script.Parent.StructureReset)
export type Base = { model: Model, humanoid: Humanoid, root: BasePart, teamId: string, destroyed: boolean }
local BaseService = { Destroyed = Instance.new("BindableEvent") }
local bases: { [string]: Base } = {}
local connections: { RBXScriptConnection } = {}
local arena: Folder? = nil
local visuals: { [Model]: Reset.Snapshot } = {}
local boards: { BillboardGui } = {}
local currentRound = 0
function BaseService.GetAll(): { [string]: Base } return bases end
function BaseService.Get(id: string): Base? return bases[id] end
function BaseService.Start(map: Folder, roundId: number?)
	if next(bases) ~= nil then return end
	arena = map; currentRound = roundId or 1
	local epoch = currentRound
	for _, definition in Config.Teams do
		local container = map:FindFirstChild("Bases"); assert(container, "Bases missing")
		local model = container:FindFirstChild(definition.Id .. "Base")
		assert(model and model:IsA("Model"), "Base model missing")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		assert(humanoid and root and root:IsA("BasePart"), "Base requires Humanoid and root")
		if not visuals[model] then visuals[model] = Reset.capture(model) end
		model:SetAttribute("RoundId", epoch)
		model:SetAttribute("TeamId", definition.Id); model:SetAttribute("EntityKind", "Base")
		humanoid.MaxHealth = Config.BaseHealth; humanoid.Health = Config.BaseHealth
		local base: Base = { model = model, humanoid = humanoid, root = root, teamId = definition.Id, destroyed = false }
		bases[definition.Id] = base
		Structures.Register(model)
		local billboard = Instance.new("BillboardGui"); billboard.Name = "BaseHealth"
		billboard.Size = UDim2.fromOffset(200, 68); billboard.StudsOffset = Vector3.new(0, 6, 0)
		billboard.AlwaysOnTop = true; billboard.MaxDistance = 240; billboard.Parent = root
		table.insert(boards, billboard)
		local label = Instance.new("TextLabel"); label.Size = UDim2.fromScale(1, 0.65)
		label.BackgroundTransparency = 1; label.TextColor3 = Color3.new(1, 1, 1); label.TextStrokeTransparency = 0.4
		label.TextSize = 16; label.Font = Enum.Font.GothamBold; label.Parent = billboard
		local track = Instance.new("Frame"); track.Size = UDim2.fromScale(1, 0.2); track.Position = UDim2.fromScale(0, 0.75)
		track.BackgroundColor3 = Color3.fromRGB(30, 32, 40); track.BorderSizePixel = 0; track.Parent = billboard
		local fill = Instance.new("Frame"); fill.BackgroundColor3 = definition.Color; fill.BorderSizePixel = 0; fill.Parent = track
		local function update()
			if currentRound ~= epoch or bases[definition.Id] ~= base then return end
			model:SetAttribute("MaxHealth", humanoid.MaxHealth); model:SetAttribute("CurrentHealth", humanoid.Health)
			label.Text = definition.Id .. " CORE  " .. math.ceil(humanoid.Health) .. "/" .. humanoid.MaxHealth .. "\n"
				.. (if model:GetAttribute("ProtectedByTowers") == true then "Защищена башнями" else "База уязвима")
			fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
			if humanoid.Health <= 0 and not base.destroyed then
				base.destroyed = true; model:SetAttribute("IsDestroyed", true)
				root.Color = Color3.fromRGB(40, 42, 45); root.Material = Enum.Material.Slate
				root.CanCollide = false; root.CanQuery = false
				BaseService.Destroyed:Fire(base.teamId, epoch)
			end
		end
		model:SetAttribute("IsDestroyed", false); update()
		table.insert(connections, humanoid.HealthChanged:Connect(update))
		table.insert(connections, model:GetAttributeChangedSignal("ProtectedByTowers"):Connect(update))
	end
end
function BaseService.Reset(roundId: number)
	if roundId <= currentRound then return end
	local map = arena; assert(map)
	for _, connection in connections do connection:Disconnect() end; table.clear(connections)
	for _, board in boards do board:Destroy() end; table.clear(boards)
	for _, base in bases do
		Structures.Remove(base.model); visuals[base.model].restore()
		Reset.humanoid(base.model, Config.BaseHealth)
	end
	table.clear(bases)
	BaseService.Start(map, roundId)
end
return BaseService
