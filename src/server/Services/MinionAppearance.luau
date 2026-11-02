--!strict
-- Original primitive silhouettes; cosmetic parts never participate in combat queries/physics.
local Appearance = {}
function Appearance.Apply(model: Model, kind: string, teamId: string)
	local zetsu = teamId == "Red"
	model:SetAttribute("MinionVisual", if zetsu then "WhiteZetsu" else "Alliance")
	local torso = model:FindFirstChild("Torso") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	local leftArm = model:FindFirstChild("Left Arm") :: BasePart
	local rightArm = model:FindFirstChild("Right Arm") :: BasePart
	local pale = Color3.fromRGB(224, 233, 208)
	local cloth = Color3.fromRGB(39, 49, 65)
	local green = Color3.fromRGB(88, 111, 77)
	local dark = Color3.fromRGB(39, 65, 48)
	local steel = Color3.fromRGB(152, 165, 174)
	local folder = Instance.new("Folder"); folder.Name = "MinionCosmetics"; folder.Parent = model
	local function detail(name: string, parent: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
		local part = Instance.new("Part"); part.Name = name; part.Size = size; part.Color = color
		part.Material = Enum.Material.SmoothPlastic; part.Shape = shape or Enum.PartType.Block
		part.TopSurface = Enum.SurfaceType.Smooth; part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false; part.CanTouch = false; part.CanQuery = false; part.Massless = true
		part.CastShadow = false; part.CFrame = parent.CFrame * offset; part.Parent = folder
		local weld = Instance.new("WeldConstraint"); weld.Part0 = parent; weld.Part1 = part; weld.Parent = part
		return part
	end
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then item.Color = if zetsu then pale else cloth end
	end
	head.Color = if zetsu then pale else Color3.fromRGB(218, 177, 141)
	if zetsu then
		-- Split organic face, leaf collar and a spine distinguish these from uniformed shinobi.
		detail("FaceGrowth", head, Vector3.new(.55, .95, .14), CFrame.new(-.5, 0, -.52), Color3.fromRGB(163, 187, 139))
		for _, side in { -1, 1 } do
			detail("LeafCollar", torso, Vector3.new(.55, 1.8, 1.4), CFrame.new(side * 1.05, .75, .25) * CFrame.Angles(0, 0, -side * .4), dark, Enum.PartType.Ball)
			detail("RootVein", torso, Vector3.new(.12, 1.6, .12), CFrame.new(side * .5, -.05, -.55) * CFrame.Angles(0, 0, side * .25), green)
			detail("Eye", head, Vector3.new(.19, .12, .09), CFrame.new(side * .37, .12, -.56), Color3.fromRGB(78, 93, 42))
		end
		detail("Spine", torso, Vector3.new(.35, 1.85, .35), CFrame.new(0, 0, .63), green)
		if kind == "Ranged" then
			detail("SeedPod", torso, Vector3.new(1.3, 1.3, .8), CFrame.new(0, .2, .95), dark, Enum.PartType.Ball)
			detail("SeedArm", rightArm, Vector3.new(1.14, 1.25, 1.14), CFrame.new(0, -.3, 0), green, Enum.PartType.Ball)
		else
			for _, arm in { leftArm, rightArm } do
				detail("RootBlade", arm, Vector3.new(.2, 1.5, .35), CFrame.new(0, -.65, -.65) * CFrame.Angles(-.3, 0, 0), dark)
			end
		end
	else
		detail("FlakVest", torso, Vector3.new(2.12, 1.65, 1.15), CFrame.new(0, .12, 0), green)
		detail("VestSeam", torso, Vector3.new(.1, 1.5, .09), CFrame.new(0, .1, -.62), dark)
		for _, side in { -1, 1 } do
			detail("VestPouch", torso, Vector3.new(.65, .55, .22), CFrame.new(side * .53, -.22, -.66), Color3.fromRGB(116, 133, 92))
			detail("Eye", head, Vector3.new(.17, .09, .08), CFrame.new(side * .36, .03, -.54), cloth)
			local leg = model:FindFirstChild((if side == -1 then "Left" else "Right") .. " Leg") :: BasePart
			detail("ShinWrap", leg, Vector3.new(1.04, .6, 1.04), CFrame.new(0, -.35, 0), Color3.fromRGB(179, 184, 165))
		end
		detail("ForeheadCloth", head, Vector3.new(2.03, .32, 1.03), CFrame.new(0, .27, 0), cloth)
		detail("AlliancePlate", head, Vector3.new(1.05, .27, .1), CFrame.new(0, .27, -.57), steel)
		-- A simple original linked-bars insignia, rather than an external decal asset.
		detail("AllianceMark", head, Vector3.new(.38, .07, .03), CFrame.new(0, .27, -.635) * CFrame.Angles(0, 0, .35), dark)
		detail("Belt", torso, Vector3.new(2.08, .23, 1.1), CFrame.new(0, -.82, 0), dark)
		if kind == "Ranged" then
			detail("Scroll", torso, Vector3.new(.65, 1.8, .65), CFrame.new(0, 0, .95) * CFrame.Angles(0, 0, .5), Color3.fromRGB(200, 183, 136), Enum.PartType.Cylinder)
			detail("SealCuff", rightArm, Vector3.new(1.08, .55, 1.08), CFrame.new(0, -.5, 0), steel)
		else
			detail("KunaiHandle", rightArm, Vector3.new(.16, .6, .16), CFrame.new(0, -1.1, -.4), dark)
			detail("KunaiBlade", rightArm, Vector3.new(.24, .65, .1), CFrame.new(0, -1.7, -.4), steel)
		end
	end
end
return Appearance
