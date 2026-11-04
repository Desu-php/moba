--!strict
-- Preview only: server services still decide legality, resources and hits.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Units = require(Shared.Abilities.WorldUnits)
local Definitions = require(Shared.Abilities.NarutoDefinitions)
local Spells = require(Shared.Abilities.GamakichiSpells)
local Kcm = require(Shared.Abilities.NarutoKcmGameplay)
local Ranged = require(Shared.Abilities.NarutoRangedState)
local Targeting = {}
local folder: Folder? = nil
local ring: {Part} = {}
local line: Part? = nil
local marker: Part? = nil
local growthRing: {Part} = {}
local highlight: Highlight? = nil
local validColor, invalidColor = Color3.fromRGB(94,225,205), Color3.fromRGB(255,104,98)
-- NarutoRangedState starts both explosions at 636 WC; HY expands by 4 for 58 pulses.
local rangedRadius, hyMaximumRadius = 636, 636 + 4*58
local actors: {[Model]: boolean} = {}
local function actorAdded(item: Instance)
	if item:IsA("Humanoid") and item.Parent and item.Parent:IsA("Model") then actors[item.Parent] = true end
end
for _, item in workspace:GetDescendants() do actorAdded(item) end
workspace.DescendantAdded:Connect(actorAdded)
workspace.DescendantRemoving:Connect(function(item)
	if item:IsA("Humanoid") and item.Parent and item.Parent:IsA("Model") then actors[item.Parent] = nil end
end)

function Targeting.IsTargeted(id: string): boolean
	return id == "CloneCommand" or id == "ShadowSleep" or id == "GamakichiOil" or id == "GamakichiChop" or id == "KcmDash" or id == "RikudoHY" or id == "RikudoHZ"
end
local function exclusions(): {Instance}
	local player = Players.LocalPlayer
	local excluded: {Instance} = {}
	if player.Character then table.insert(excluded, player.Character) end
	if folder then table.insert(excluded, folder) end
	local summons = workspace:FindFirstChild("HeroSummons")
	if summons then for _, model in summons:GetChildren() do
		if model:GetAttribute("TeamId") == player:GetAttribute("TeamId") then table.insert(excluded, model) end
	end end
	return excluded
end
function Targeting.Pick(point: Vector2?): RaycastResult?
	local camera = workspace.CurrentCamera; if not camera then return nil end
	local mouse = point or Input:GetMouseLocation()
	local ray = if Input.MouseBehavior == Enum.MouseBehavior.LockCenter
		then camera:ViewportPointToRay(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
		else camera:ScreenPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new(); params.FilterDescendantsInstances = exclusions()
	return workspace:Raycast(ray.Origin, ray.Direction*500, params)
end
local function modelAt(hit: RaycastResult?): Model?
	local item = if hit then hit.Instance :: Instance else nil
	while item and item ~= workspace do
		if item:IsA("Model") and item:FindFirstChildOfClass("Humanoid") then return item end
		item = item.Parent
	end
	return nil
end
function Targeting.PickModel(point: Vector2?): Model? return modelAt(Targeting.Pick(point)) end
local function terrainParams(): RaycastParams
	local ignored = exclusions()
	for actor in actors do table.insert(ignored, actor) end
	local params = RaycastParams.new(); params.FilterDescendantsInstances = ignored; params.RespectCanCollide = true
	return params
end
function Targeting.Geometry(id: string): (BasePart?, number, number)
	local player = Players.LocalPlayer
	local model = player.Character
	if id == "GamakichiOil" or id == "GamakichiChop" then
		model = nil
		local summons = workspace:FindFirstChild("HeroSummons")
		if summons then for _, child in summons:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("NativeGamakichi") == true and child:GetAttribute("SummonOwner") == player.UserId then model = child; break end
		end end
	end
	local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
	local range = if id == "GamakichiOil" then Spells.Oil.Range elseif id == "GamakichiChop" then Spells.Chopping.Range
		elseif id == "KcmDash" then Kcm.Dash.RangeWarcraft elseif id == "RikudoHY" or id == "RikudoHZ" then Ranged.RangeWarcraft else Definitions.Clones.RangeWarcraft
	local radius = if id == "GamakichiChop" then Spells.Chopping.Radius elseif id == "GamakichiOil" then Spells.Oil.Radius
		elseif id == "RikudoHY" or id == "RikudoHZ" then rangedRadius else 0
	return if root and root:IsA("BasePart") then root else nil, Units.toStuds(range), Units.toStuds(radius)
end
function Targeting.Evaluate(id: string, point: Vector2?): (any, string?, Vector3?)
	local hit = Targeting.Pick(point); if not hit then return nil, "Наведите прицел на цель или землю", nil end
	local model = modelAt(hit)
	local area = id == "GamakichiChop" or id == "RikudoHY" or id == "RikudoHZ"
	local target: any = if area then hit.Position elseif id == "KcmDash" then model or hit.Position else model
	if not target then return nil, "Наведите прицел на врага", hit.Position end
	local origin, range = Targeting.Geometry(id); if not origin then return nil, "Источник способности недоступен", hit.Position end
	local position = hit.Position
	if area then
		-- Aiming at a torso anchors the area to the floor under it, not to its side normal.
		local ground = workspace:Raycast(position+Vector3.new(0,12,0),Vector3.new(0,-36,0),terrainParams())
		if not ground then return nil, "Наведите прицел на землю", position end
		position = ground.Position; target = position
	end
	if typeof(target) == "Instance" then
		local targetModel = target :: Model
		local hp = targetModel:FindFirstChildOfClass("Humanoid")
		local root = targetModel:FindFirstChild("HumanoidRootPart")
		local ownTeam = Players.LocalPlayer:GetAttribute("TeamId")
		if not hp or hp.Health <= 0 or not root or not root:IsA("BasePart") or targetModel:FindFirstChildOfClass("ForceField")
			or targetModel:GetAttribute("CombatDisabled") == true or targetModel:GetAttribute("IsDestroyed") == true
			or (ownTeam ~= nil and targetModel:GetAttribute("TeamId") == ownTeam) then return nil, "Недоступная цель", hit.Position end
		local kind = targetModel:GetAttribute("EntityKind")
		if id ~= "CloneCommand" and kind ~= "Hero" and kind ~= "Minion" and kind ~= "Summon" then return nil, "Выберите бойца", hit.Position end
		position = root.Position
	end
	if (position-origin.Position).Magnitude > range then return nil, "Слишком далеко", position end
	-- Only these techniques use server terrain visibility checks. Clone orders,
	-- Sleep and ranged ultimates must not acquire a new client-only LOS restriction.
	if id == "KcmDash" or id == "GamakichiOil" or id == "GamakichiChop" then
		local destination = if id == "KcmDash" then position else position+Vector3.new(0,.1,0)
		if workspace:Raycast(origin.Position, destination-origin.Position, terrainParams()) then return nil, "Путь перекрыт", position end
	end
	if id == "KcmDash" then
		if math.abs(position.Y-origin.Position.Y)>12 then return nil, "Слишком большой перепад высоты", position end
		local destination = position
		if typeof(target) == "Instance" then
			local flat = (origin.Position-destination)*Vector3.new(1,0,1)
			if flat.Magnitude>.01 then destination += flat.Unit*3 end
		end
		local params = RaycastParams.new(); params.RespectCanCollide = true
		local ignored: {Instance} = {}; if Players.LocalPlayer.Character then table.insert(ignored,Players.LocalPlayer.Character :: Model) end
		if typeof(target) == "Instance" then table.insert(ignored,target) end
		params.FilterDescendantsInstances = ignored
		local ground = workspace:Raycast(destination+Vector3.new(0,6,0),Vector3.new(0,-18,0),params)
		if not ground or ground.Normal.Y<.5 then return nil, "Выберите устойчивую поверхность", position end
		local humanoid = if origin.Parent then origin.Parent:FindFirstChildOfClass("Humanoid") else nil
		destination = Vector3.new(destination.X,ground.Position.Y+(if humanoid then humanoid.HipHeight else 2)+origin.Size.Y/2,destination.Z)
		local movement = destination-origin.Position
		if movement.Magnitude>.01 and workspace:Blockcast(origin.CFrame,origin.Size*.8,movement,params) then return nil, "Путь перекрыт", destination end
		position = destination
	end
	return target, nil, position
end
function Targeting.Clear()
	if folder then folder:Destroy(); folder = nil end
	table.clear(ring); table.clear(growthRing); line = nil; marker = nil; highlight = nil
	Players.LocalPlayer:SetAttribute("AimTargetValid", nil)
end
local function part(name: string): Part
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Material = Enum.Material.Neon; p.CastShadow = false; p.Transparency = .35; p.Parent = folder; return p
end
function Targeting.Preview(id: string): string?
	if not folder then
		local created = Instance.new("Folder"); created.Name = "LocalAbilityAim"; created.Parent = workspace; folder = created
		for _ = 1,32 do table.insert(ring, part("Range")) end
		for _ = 1,32 do table.insert(growthRing, part("ExpansionLimit")) end
		line = part("Direction"); marker = part("Area"); marker.Shape = Enum.PartType.Cylinder
		highlight = Instance.new("Highlight"); highlight.DepthMode = Enum.HighlightDepthMode.Occluded; highlight.FillTransparency = .85; highlight.Parent = folder
	end
	local target, reason, position = Targeting.Evaluate(id)
	local root, range, radius = Targeting.Geometry(id)
	local color = if reason then invalidColor else validColor
	Players.LocalPlayer:SetAttribute("AimTargetValid", reason == nil)
	if root then
		local floor = workspace:Raycast(root.Position,Vector3.new(0,-20,0),terrainParams())
		local center = if floor then floor.Position+Vector3.new(0,.08,0) else root.Position-Vector3.new(0,2.6,0)
		for i,p in ring do
			local a,b = (i-1)*math.pi/16, i*math.pi/16
			local first = center+Vector3.new(math.cos(a),0,math.sin(a))*range
			local last = center+Vector3.new(math.cos(b),0,math.sin(b))*range
			p.Size = Vector3.new(.08,.08,(last-first).Magnitude); p.CFrame = CFrame.lookAt((first+last)/2,last); p.Color = color
		end
		if line then
			line.Transparency = if position then .4 else 1
			if position and (position-root.Position).Magnitude > .01 then
				line.Size = Vector3.new(.08,.08,(position-root.Position).Magnitude); line.CFrame = CFrame.lookAt((root.Position+position)/2, position); line.Color = color
			end
		end
	end
	if marker then
		marker.Transparency = if position then .8 else 1
		if position then marker.Size = Vector3.new(.06,math.max(1,radius*2),math.max(1,radius*2)); marker.CFrame = CFrame.new(position+Vector3.new(0,.08,0))*CFrame.Angles(0,0,math.pi/2); marker.Color = color end
	end
	for i,p in growthRing do
		p.Transparency = if id == "RikudoHY" and position then .6 else 1
		if id == "RikudoHY" and position then
			local a,b = (i-1)*math.pi/16, i*math.pi/16
			local first = position+Vector3.new(math.cos(a),0,math.sin(a))*Units.toStuds(hyMaximumRadius)
			local last = position+Vector3.new(math.cos(b),0,math.sin(b))*Units.toStuds(hyMaximumRadius)
			p.Size=Vector3.new(.1,.1,(last-first).Magnitude); p.CFrame=CFrame.lookAt((first+last)/2,last); p.Color=color
		end
	end
	if highlight then highlight.Adornee = if typeof(target) == "Instance" then target else nil; highlight.FillColor = color; highlight.OutlineColor = color end
	return reason
end
return Targeting
