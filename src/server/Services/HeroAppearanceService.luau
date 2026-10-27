--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.HeroAppearanceConfig)
local HeroConfig = require(Shared.Config.HeroConfig)
local Appearance = {}
local function color(rgb: { number }): Color3 return Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end
function Appearance.Apply(model: Model)
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	if not head or not head:IsA("BasePart") or not torso or not torso:IsA("BasePart") then return end
	-- Only avatar cosmetics are replaced. Motors, tools, gameplay folders and Animator survive.
	for _, item in model:GetChildren() do
		if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item.Name == "HeroAppearance" then item:Destroy() end
	end
	for _, item in head:GetChildren() do if item:IsA("Decal") then item:Destroy() end end
	local skin, orange, dark, hair, metal = color(Config.Skin), color(Config.Orange), color(Config.Dark), color(Config.Hair), color(Config.Metal)
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
			item.Color = if item.Name == "Head" or string.find(item.Name, "Hand") then skin elseif string.find(item.Name, "Foot") then dark else orange
			item.Material = Enum.Material.SmoothPlastic
		end
	end
	local folder = Instance.new("Folder"); folder.Name = "HeroAppearance"; folder.Parent = model
	local function detail(name: string, parent: BasePart, size: Vector3, offset: CFrame, tint: Color3, wedge: boolean?): BasePart
		local part: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
		part.Name = name; part.Size = size; part.Color = tint; part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false; part.CanTouch = false; part.CanQuery = false; part.Massless = true
		part:SetAttribute("HeroCosmetic", true); part.CFrame = parent.CFrame * offset; part.Parent = folder
		local weld = Instance.new("WeldConstraint"); weld.Part0 = parent; weld.Part1 = part; weld.Parent = part
		return part
	end
	local cap = detail("HairCrown", head, Vector3.new(1.45, 0.62, 1.15), CFrame.new(0, 0.55, 0.08), hair)
	if cap:IsA("Part") then cap.Shape = Enum.PartType.Ball end
	for i = 1, Config.HairSpikes do
		local angle = i * math.pi * 2 / Config.HairSpikes
		detail("HairSpike" .. i, head, Vector3.new(0.4, Config.HairHeight + (i % 3) * 0.13, 0.54),
			CFrame.new(math.sin(angle) * Config.HairRadius, 0.72, math.cos(angle) * 0.43) * CFrame.Angles(-0.25, angle, math.sin(angle) * -0.42), hair, true)
	end
	detail("Headband", head, Vector3.new(1.52, 0.3, 1.12), CFrame.new(0, 0.19, 0), dark)
	detail("ForeheadPlate", head, Vector3.new(0.92, 0.24, 0.07), CFrame.new(0, 0.2, -0.6), metal)
	-- Original broken diamond emblem, not a franchise logo.
	for i = 0, 3 do
		detail("Emblem" .. i, head, Vector3.new(0.2, 0.035, 0.035),
			CFrame.new(math.cos(i * math.pi / 2) * 0.12, 0.2 + math.sin(i * math.pi / 2) * 0.08, -0.65) * CFrame.Angles(0, 0, math.pi / 4 + i * math.pi / 2), dark)
	end
	for _, side in { -1, 1 } do
		detail("EyeWhite", head, Vector3.new(0.27, 0.13, 0.055), CFrame.new(side * 0.31, -0.03, -0.55), Color3.new(1, 1, 1))
		detail("Eye", head, Vector3.new(0.11, 0.12, 0.06), CFrame.new(side * 0.3, -0.03, -0.585), color(Config.Eyes))
		detail("Brow", head, Vector3.new(0.28, 0.055, 0.06), CFrame.new(side * 0.31, 0.065, -0.57) * CFrame.Angles(0, 0, side * 0.12), hair)
		detail("BandTail", head, Vector3.new(0.18, 0.85, 0.08), CFrame.new(side * 0.19, -0.34, 0.65) * CFrame.Angles(-0.4, 0, side * 0.25), dark)
	end
	detail("Mouth", head, Vector3.new(0.27, 0.035, 0.05), CFrame.new(0, -0.3, -0.55), dark)
	detail("JacketYoke", torso, Vector3.new(2.05, 0.43, 1.08), CFrame.new(0, 0.55, 0), dark)
	detail("Zipper", torso, Vector3.new(0.08, 1.35, 0.07), CFrame.new(0, -0.08, -0.55), metal)
	detail("Collar", torso, Vector3.new(1.35, 0.26, 1.1), CFrame.new(0, 0.81, 0), dark)
	local lower = model:FindFirstChild("LowerTorso")
	if lower and lower:IsA("BasePart") then detail("Belt", lower, Vector3.new(2.04, 0.2, 1.08), CFrame.new(0, 0.1, 0), dark) end
	for _, side in { "Left", "Right" } do
		local arm = model:FindFirstChild(side .. "LowerArm")
		if arm and arm:IsA("BasePart") then detail("Cuff", arm, Vector3.new(1.03, 0.22, 1.03), CFrame.new(0, -0.35, 0), dark) end
		local foot = model:FindFirstChild(side .. "Foot")
		if foot and foot:IsA("BasePart") then
			detail("SandalSole", foot, Vector3.new(1.05, 0.14, 1.5), CFrame.new(0, -0.34, 0), dark)
			detail("Toes", foot, Vector3.new(0.83, 0.22, 0.27), CFrame.new(0, -0.08, -0.64), skin)
		end
	end
	model:SetAttribute("HeroAppearanceVersion", HeroConfig.AppearanceVersion)
end
return Appearance
