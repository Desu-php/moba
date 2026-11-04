--!strict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Data=require(Shared.Config.CreatorVisualData)
local Factory=require(Shared.CreatorVisualFactory)
local Appearance={}
local bound: {[Model]: RBXScriptConnection}=setmetatable({}, {__mode="k"})
local function dress(model: Model)
 local head=model:FindFirstChild("Head")
 if not head or not head:IsA("BasePart") or not model:FindFirstChild("UpperTorso") then return end
 local sage=model:GetAttribute("SagePhase")=="Active"
 -- Keep the physical head and its rig joints; the imported face supplies the visible head.
 head.Transparency=1
 for _,item in model:GetChildren() do
  if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item.Name=="HeroAppearance" then item:Destroy() end
 end
 for _,item in head:GetChildren() do if item:IsA("Decal") then item:Destroy() end end
 for _,item in model:GetChildren() do if item:IsA("BasePart") and item.Name~="HumanoidRootPart" then
  item.Color=Color3.fromRGB(255,204,153);item.Material=Enum.Material.SmoothPlastic
 end end
 local shirt=Instance.new("Shirt");shirt.ShirtTemplate=if sage then "rbxassetid://7472900840" else "rbxassetid://6764794671";shirt.Parent=model
 local pants=Instance.new("Pants");pants.PantsTemplate=if sage then "rbxassetid://7472928447" else "rbxassetid://3237352364";pants.Parent=model
 local folder=Instance.new("Folder");folder.Name="HeroAppearance";folder.Parent=model
 if sage then
  -- A classic head supports this store face decal. The avatar's dynamic head does not.
  local faceHead=Instance.new("Part");faceHead.Name="SageFaceHead";faceHead.Size=Vector3.new(2,1,1)
  faceHead.Color=Color3.fromRGB(255,204,153);faceHead.Material=Enum.Material.SmoothPlastic
  faceHead.CanCollide=false;faceHead.CanTouch=false;faceHead.CanQuery=false;faceHead.Massless=true
  faceHead:SetAttribute("HeroCosmetic",true);faceHead:SetAttribute("CosmeticBody","Head");faceHead:SetAttribute("CosmeticOffset",CFrame.identity)
  faceHead.CFrame=head.CFrame;faceHead.Parent=folder
  local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Head;mesh.Scale=Vector3.one*1.25;mesh.Parent=faceHead
  local face=Instance.new("Decal");face.Name="SageFace";face.Texture="rbxassetid://9449064416";face.Face=Enum.NormalId.Front;face.Parent=faceHead
  local weld=Instance.new("WeldConstraint");weld.Part0=head;weld.Part1=faceHead;weld.Parent=faceHead
 end
 for _,spec in Data.appearance do
  if spec.form=="Sage" and not sage or spec.form=="Normal" and sage then continue end
  local body=model:FindFirstChild(spec.body)
  if not body or not body:IsA("BasePart") then continue end
  local part=Factory.Part(spec);part:SetAttribute("HeroCosmetic",true)
  part:SetAttribute("CosmeticBody",spec.body);part:SetAttribute("CosmeticOffset",Factory.Frame(spec.cf))
  part.CFrame=body.CFrame*Factory.Frame(spec.cf);part.Parent=folder
  local weld=Instance.new("WeldConstraint");weld.Part0=body;weld.Part1=part;weld.Parent=part
 end
 model:SetAttribute("HeroAppearanceVersion","CreatorStore-v2:"..(if sage then "Sage" else "Normal"))
end
function Appearance.Apply(model: Model)
 dress(model)
 if bound[model] then return end
 bound[model]=model:GetAttributeChangedSignal("SagePhase"):Connect(function() dress(model) end)
 model.Destroying:Once(function() local connection=bound[model];if connection then connection:Disconnect();bound[model]=nil end end)
end
return Appearance
