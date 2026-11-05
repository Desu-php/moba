--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.MapConfig)
local Plan = require(Shared.Game.MapSceneryPlan)
local MapScenery = {}
local palette = {
	Bark = Color3.fromRGB(103, 72, 48), Leaf = Color3.fromRGB(52, 98, 65), LightLeaf = Color3.fromRGB(77, 120, 68),
	DarkLeaf = Color3.fromRGB(44, 66, 66), Ash = Color3.fromRGB(84, 81, 82), Rock = Color3.fromRGB(111, 115, 107),
	DarkRock = Color3.fromRGB(64, 65, 73), Moss = Color3.fromRGB(78, 104, 66), Plaster = Color3.fromRGB(211, 190, 146),
	Roof = Color3.fromRGB(68, 108, 91), Paper = Color3.fromRGB(226, 219, 185), Alliance = Color3.fromRGB(61, 94, 146),
	Enemy = Color3.fromRGB(148, 43, 52), Bone = Color3.fromRGB(163, 167, 144), Water = Color3.fromRGB(64, 131, 143),
	SandRock = Color3.fromRGB(153, 132, 103), Scorch = Color3.fromRGB(71, 65, 58), Canvas = Color3.fromRGB(194, 182, 135),
}
function MapScenery.Ensure(map: Folder)
	-- Authored maps own their appearance. Only decorate this generator's layout.
	if map:GetAttribute("AuthoredSurvivalMap") == true then return end
	local old = map:FindFirstChild("ShinobiScenery")
	if old and old:GetAttribute("SceneryVersion") == Plan.Version then return end
	assert(not old or old:GetAttribute("GeneratedScenery") == true, "ShinobiScenery is reserved for generated decor")
	local root = Instance.new("Folder")
	root.Name = "ShinobiScenery"
	root:SetAttribute("GeneratedScenery", true)
	root:SetAttribute("SceneryVersion", Plan.Version)
	local ok, failure = pcall(function()
		for _, piece in Plan.Build() do
			local item = Instance.new("Part")
			item.Name = piece.name
			item.Anchored = true
			item.CanCollide = piece.solid
			item.CanTouch = false
			item.CanQuery = piece.solid
			item.CastShadow = false -- Canopies cannot darken combat or hide targeting telegraphs.
			item.Size = Vector3.new(piece.sx, piece.sy, piece.sz)
			item.CFrame = CFrame.new(Config.Origin + Vector3.new(piece.x, piece.y, piece.z)) * CFrame.Angles(0, math.rad(piece.yaw), 0)
			if piece.pitch then item.CFrame*=CFrame.Angles(math.rad(piece.pitch),0,0) end
			item.Color = (palette :: { [string]: Color3 })[piece.palette]
			item.Material = (Enum.Material :: any)[piece.material]
			item.Shape = if piece.shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
			if piece.shape == "Cylinder" then
				item.Shape=Enum.PartType.Cylinder
				item.Size=Vector3.new(piece.sy,piece.sx,piece.sz)
				item.CFrame*=CFrame.Angles(0,0,math.pi/2)
			end
			item.TopSurface = Enum.SurfaceType.Smooth
			item.BottomSurface = Enum.SurfaceType.Smooth
			item.Parent = root
		end
	end)
	if not ok then root:Destroy(); error(failure) end
	local function sign(name: string,position: Vector3,label: string,color: Color3)
		local marker=Instance.new("Part");marker.Name=name;marker.Anchored=true
		marker.Size=Vector3.new(2,9,2);marker.Position=Config.Origin+position
		marker.CanCollide=false;marker.CanQuery=false;marker.CanTouch=false
		marker.Material=Enum.Material.Wood;marker.Color=palette.Bark;marker.Parent=root
		local gui=Instance.new("BillboardGui");gui.Name="Wayfinding";gui.Size=UDim2.fromOffset(240,44)
		gui.StudsOffsetWorldSpace=Vector3.new(0,5,0);gui.MaxDistance=115;gui.AlwaysOnTop=false;gui.Parent=marker
		local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundColor3=Color3.fromRGB(26,33,29)
		text.BackgroundTransparency=.15;text.BorderSizePixel=0;text.Text=label;text.TextColor3=color
		text.Font=Enum.Font.GothamBold;text.TextSize=16;text.TextWrapped=true;text.Parent=gui
	end
	sign("AllianceCampSign",Vector3.new(-368,5,-46),"ЛАГЕРЬ АЛЬЯНСА",Color3.fromRGB(164,211,247))
	sign("WarFrontSign",Vector3.new(-45,5,-238),"ВЫЖЖЕННОЕ ПОЛЕ",Color3.fromRGB(230,204,150))
	sign("DivineRootsSign",Vector3.new(369,5,46),"КОРНИ ДРЕВА",Color3.fromRGB(233,175,166))
	for _,side in {-1,1} do
		sign("TopSign"..side,Vector3.new(side*320,5,-52),"ВЕРХНЯЯ ЛИНИЯ",Color3.fromRGB(231,222,186))
		sign("BottomSign"..side,Vector3.new(side*320,5,52),"НИЖНЯЯ ЛИНИЯ",Color3.fromRGB(231,222,186))
	end
	root:SetAttribute("PartCount", #root:GetChildren())
	if old then old:Destroy() end
	root.Parent = map
	local lighting=game:GetService("Lighting")
	lighting.ClockTime=14.5;lighting.Brightness=2.5
	lighting.Ambient=Color3.fromRGB(140,143,137);lighting.OutdoorAmbient=Color3.fromRGB(164,168,155)
	lighting.ExposureCompensation=.25
	lighting.FogColor=Color3.fromRGB(184,201,199);lighting.FogStart=650;lighting.FogEnd=1800
end
return MapScenery
