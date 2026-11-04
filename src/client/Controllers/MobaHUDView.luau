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
export type Portrait = { viewport: ViewportFrame, source: Model?, copy: Model?, appearance: string,
 generation:number,pending:string?,pendingSource:Model? }
function View.portrait(parent: Instance, size: UDim2, position: UDim2): Portrait
	local viewport = Instance.new("ViewportFrame"); viewport.Name = "Portrait"; viewport.Size = size; viewport.Position = position
	viewport.BackgroundColor3 = View.Card; viewport.BorderSizePixel = 0; viewport.LightDirection = Vector3.new(-1,-1,-2)
	viewport.Ambient = Color3.fromRGB(180,180,180); viewport.Parent = parent
	return { viewport = viewport, source = nil, copy = nil, appearance = "",generation=0,pending=nil,pendingSource=nil }
end
function View.updatePortrait(portrait: Portrait, source: Model?)
	local costume = if source then source:FindFirstChild("HeroAppearance") else nil
 local appearance = if source then tostring(source:GetAttribute("HeroAppearanceVersion")) else ""
	if portrait.source == source and portrait.appearance == appearance and (not source or portrait.copy) then
  if portrait.pending then portrait.generation+=1;portrait.pending=nil;portrait.pendingSource=nil end
  return
 end
	if not source then
  portrait.generation+=1;portrait.pending=nil;portrait.pendingSource=nil
  portrait.source=nil;portrait.appearance="";portrait.copy=nil;portrait.viewport:ClearAllChildren();return
 end
 -- Keep the current portrait through partial replication and texture loading.
 if not costume or costume:GetAttribute("AppearanceVersion")~=appearance then return end
 local count=costume:GetAttribute("AppearanceParts")
 local descendants=costume:GetAttribute("AppearanceDescendants")
 if typeof(count)~="number" or #costume:GetChildren()<count or typeof(descendants)~="number" or #costume:GetDescendants()<descendants then return end
 if portrait.pendingSource==source and portrait.pending==appearance then return end
	local head = source:FindFirstChild("Head"); if not head or not head:IsA("BasePart") then portrait.source = nil; return end
 portrait.generation+=1;local generation=portrait.generation
 portrait.pending=appearance;portrait.pendingSource=source
 -- A fixed cosmetic bust keeps combat poses, helper clones and live effects out of the portrait.
 local copy=Instance.new("Model");copy.Name="HeroPortrait"
 local upper=source:FindFirstChild("UpperTorso")
 local torsoHeight=if upper and upper:IsA("BasePart") then upper.Size.Y else 1.6
 local headY=torsoHeight/2+head.Size.Y/2+.1
 local frames: {[string]: CFrame}={Head=CFrame.new(0,headY,0),UpperTorso=CFrame.identity,
  LowerTorso=CFrame.new(0,-1,0),LeftUpperArm=CFrame.new(-1.5,.1,0),RightUpperArm=CFrame.new(1.5,.1,0)}
 local kurama=costume:GetAttribute("AppearanceForm")=="Kurama"
 if kurama then frames.HumanoidRootPart=CFrame.identity end
 local function visualClone(original: BasePart, frame: CFrame): BasePart
  local part=original:Clone()
  local target=original:GetAttribute("AppearanceTransparency")
  if typeof(target)=="number" then part.Transparency=target end
  for _,child in part:GetDescendants() do
   if not child:IsA("DataModelMesh") and not child:IsA("Decal") and not child:IsA("SurfaceAppearance") then child:Destroy() end
  end
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
  part.LocalTransparencyModifier=0;part.CFrame=frame;part.Parent=copy;return part
 end
 for name,frame in frames do
  local original=source:FindFirstChild(name)
  if original and original:IsA("BasePart") then visualClone(original,frame) end
 end
 if costume then for _,original in costume:GetChildren() do
  if not original:IsA("BasePart") then continue end
  local body=original:GetAttribute("CosmeticBody");local offset=original:GetAttribute("CosmeticOffset")
  if typeof(body)=="string" and frames[body] and typeof(offset)=="CFrame" then visualClone(original,frames[body]*offset) end
 end end
 for _,item in source:GetChildren() do if item:IsA("Shirt") or item:IsA("Pants") then item:Clone().Parent=copy end end
 local sourceHumanoid=source:FindFirstChildOfClass("Humanoid")
 if sourceHumanoid then
  local humanoid=sourceHumanoid:Clone();humanoid:ClearAllChildren();humanoid.AutomaticScalingEnabled=false
  humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;humanoid.Parent=copy
 end
 local world=Instance.new("WorldModel");copy.Parent=world
 local camera=Instance.new("Camera");camera.FieldOfView=35
 camera.CFrame=CFrame.lookAt(Vector3.new(0,headY+.3,-4.8),Vector3.new(0,headY-.25,0))
 if kurama then
  -- Frame the fox's face, rather than the invisible humanoid head inside its body.
  camera.CFrame=CFrame.lookAt(Vector3.new(0,2,-12),Vector3.new(0,.8,-2))
 end
 -- Build and preload a replacement off-screen, then swap in one non-yielding step.
 task.spawn(function()
  local ready=pcall(function() game:GetService("ContentProvider"):PreloadAsync({copy}) end)
  if not ready or portrait.generation~=generation or not portrait.viewport.Parent or not source.Parent
   or source:GetAttribute("HeroAppearanceVersion")~=appearance then world:Destroy();camera:Destroy();return end
  portrait.viewport:ClearAllChildren()
  world.Parent=portrait.viewport;camera.Parent=portrait.viewport;portrait.viewport.CurrentCamera=camera
  portrait.copy=copy;portrait.source=source;portrait.appearance=appearance;portrait.pending=nil;portrait.pendingSource=nil
 end)
end
return View
