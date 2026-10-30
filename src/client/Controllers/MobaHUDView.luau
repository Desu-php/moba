--!strict
local View = {}
View.Background = Color3.fromRGB(20, 24, 29)
View.Card = Color3.fromRGB(35, 41, 47)
View.Gold = Color3.fromRGB(224, 182, 102)
View.Text = Color3.fromRGB(229, 229, 220)
function View.frame(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
	local f = Instance.new("Frame"); f.Name = name; f.Size = size; f.Position = position
	f.BackgroundColor3 = View.Background; f.BorderSizePixel = 0; f.Parent = parent; return f
end
function View.label(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local t = Instance.new("TextLabel"); t.Name = name; t.Size = size; t.Position = position
	t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamMedium; t.TextSize = textSize; t.TextColor3 = View.Text
	t.Text = ""; t.TextTruncate = Enum.TextTruncate.AtEnd; t.Parent = parent; return t
end
function View.border(parent: GuiObject, color: Color3)
	local stroke = Instance.new("UIStroke"); stroke.Color = color; stroke.Transparency = .35; stroke.Parent = parent
end
export type Portrait = { viewport: ViewportFrame, source: Model?, copy: Model?, appearance: string }
function View.portrait(parent: Instance, size: UDim2, position: UDim2): Portrait
	local viewport = Instance.new("ViewportFrame"); viewport.Name = "Portrait"; viewport.Size = size; viewport.Position = position
	viewport.BackgroundColor3 = View.Card; viewport.BorderSizePixel = 0; viewport.LightDirection = Vector3.new(-1,-1,-2)
	viewport.Ambient = Color3.fromRGB(180,180,180); viewport.Parent = parent
	return { viewport = viewport, source = nil, copy = nil, appearance = "" }
end
function View.updatePortrait(portrait: Portrait, source: Model?)
	local costume = if source then source:FindFirstChild("HeroAppearance") else nil
local appearance = if source then tostring(source:GetAttribute("HeroAppearanceVersion")) .. ":" .. #source:GetChildren() .. ":" .. (if costume then #costume:GetChildren() else 0) else ""
	if portrait.source == source and portrait.appearance == appearance and (not source or portrait.copy) then return end
	portrait.source = source; portrait.appearance = appearance; portrait.viewport:ClearAllChildren(); portrait.copy = nil
	if not source then return end
	local head = source:FindFirstChild("Head"); if not head or not head:IsA("BasePart") then portrait.source = nil; return end
	local old = source.Archivable; source.Archivable = true; local copy = source:Clone(); source.Archivable = old
	for _, child in copy:GetDescendants() do
		if child:IsA("LuaSourceContainer") or child:IsA("Tool") or child:IsA("ForceField") then child:Destroy()
		elseif child:IsA("BasePart") then child.Anchored = true; child.CanCollide = false end
	end
	local world = Instance.new("WorldModel"); world.Parent = portrait.viewport; copy.Parent = world; portrait.copy = copy
	local camera = Instance.new("Camera"); camera.FieldOfView = 35
	camera.CFrame = CFrame.lookAt(head.Position + head.CFrame.LookVector * 4.8 + Vector3.new(0,.3,0), head.Position - Vector3.new(0,.25,0))
	camera.Parent = portrait.viewport; portrait.viewport.CurrentCamera = camera
end
return View
