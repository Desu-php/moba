--!strict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Data=require(Shared.Config.CreatorVisualData)
local Forms=require(Shared.Config.NarutoFormVisualData)
local Factory=require(Shared.CreatorVisualFactory)
local KuramaAvatar=require(Shared.KuramaAvatar)
local Appearance={}
local bound: {[Model]: {RBXScriptConnection}}=setmetatable({}, {__mode="k"})
local function dress(model: Model)
 if model:GetAttribute("HeroId")=="Sasuke" then require(script.Parent.SasukeAppearanceService).Apply(model);return end
 local head=model:FindFirstChild("Head")
 if not head or not head:IsA("BasePart") or not model:FindFirstChild("UpperTorso") then return end
 local form=if model:GetAttribute("KuramaActive")==true then "Kurama" elseif model:GetAttribute("KcmActive")==true then "KCM" elseif model:GetAttribute("SagePhase")=="Active" then "Sage" else "Normal"
 if form=="KCM" and model:GetAttribute("KcmRank")==3 then form="Rikudo" end
 local version="CreatorStore-v5:"..form
 if model:GetAttribute("HeroAppearanceVersion")==version and model:FindFirstChild("HeroAppearance") then return end
 local sage=form=="Sage"
 local kcm=form=="KCM" or form=="Rikudo"
 -- Keep the physical head and its rig joints; the imported face supplies the visible head.
 head.Transparency=1
 local previous=model:FindFirstChild("HeroAppearance")
 for _,item in model:GetChildren() do
  if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then item:Destroy() end
 end
 for _,item in head:GetChildren() do if item:IsA("Decal") then item:Destroy() end end
 for _,item in model:GetChildren() do if item:IsA("BasePart") and item.Name~="HumanoidRootPart" and item.Name~="KuramaCombatBody" then
  item.Transparency=if item.Name=="Head" or form=="Kurama" then 1 else 0
  item.Color=if kcm then Color3.fromRGB(255,184,31) else Color3.fromRGB(255,204,153);item.Material=Enum.Material.SmoothPlastic
 end end
 local shirt=Instance.new("Shirt");shirt.ShirtTemplate=if form=="Rikudo" then "rbxassetid://6510073285" elseif kcm then "rbxassetid://7923921567" elseif sage then "rbxassetid://7472900840" else "rbxassetid://6764794671";shirt.Parent=model
 local pants=Instance.new("Pants");pants.PantsTemplate=if form=="Rikudo" then "rbxassetid://6510069460" elseif kcm then "rbxassetid://7923927930" elseif sage then "rbxassetid://7472928447" else "rbxassetid://3237352364";pants.Parent=model
 -- Build off-tree so clients never observe a deliberately empty costume.
 local folder=Instance.new("Folder");folder.Name="HeroAppearance"
 if sage or kcm then
  -- A classic head supports this store face decal. The avatar's dynamic head does not.
  local faceHead=Instance.new("Part");faceHead.Name=form.."FaceHead";faceHead.Size=Vector3.new(2,1,1)
  faceHead.Color=if kcm then Color3.fromRGB(255,202,71) else Color3.fromRGB(255,204,153);faceHead.Material=Enum.Material.SmoothPlastic
  faceHead.CanCollide=false;faceHead.CanTouch=false;faceHead.CanQuery=false;faceHead.Massless=true
  faceHead:SetAttribute("HeroCosmetic",true);faceHead:SetAttribute("CosmeticBody","Head");faceHead:SetAttribute("CosmeticOffset",CFrame.identity)
  faceHead.CFrame=head.CFrame;faceHead.Parent=folder
  local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Head;mesh.Scale=Vector3.one*1.25;mesh.Parent=faceHead
  local face=Instance.new("Decal");face.Name=form.."Face";face.Texture=if kcm then "rbxassetid://9477576334" else "rbxassetid://9449064416";face.Face=Enum.NormalId.Front;face.Parent=faceHead
  local weld=Instance.new("WeldConstraint");weld.Part0=head;weld.Part1=faceHead;weld.Parent=faceHead
 end
 for _,spec in Forms[form] or Data.appearance do
  if spec.form~="All" and spec.form~=form then continue end
  local body=model:FindFirstChild(spec.body)
  if not body or not body:IsA("BasePart") then continue end
  local part,mesh=Factory.Part(spec);part:SetAttribute("HeroCosmetic",true)
  local offset=Factory.Frame(spec.cf)
  if form=="Kurama" then KuramaAvatar.Style(part,mesh);offset=KuramaAvatar.Offset(offset) end
  part:SetAttribute("CosmeticBody",spec.body);part:SetAttribute("CosmeticOffset",offset)
  part.CFrame=body.CFrame*offset;part.Parent=folder
  local weld=Instance.new("Weld");weld.Name="FormVisualWeld";weld.Part0=body;weld.Part1=part;weld.C0=offset;weld.Parent=part
 end
 if form=="Kurama" then local root=model:FindFirstChild("HumanoidRootPart");if root and root:IsA("BasePart") then KuramaAvatar.Markings(folder,root) end end
 if form=="Rikudo" then
  local torso=model:FindFirstChild("UpperTorso") :: BasePart
  for i=1,9 do
   local angle=(i-1)*math.pi*2/9
   local offset=CFrame.new(math.cos(angle)*1.9,.2+math.sin(angle)*1.9,1.25)
   local orb=Instance.new("Part");orb.Name="TruthSeekingOrb"..i;orb.Shape=Enum.PartType.Ball;orb.Size=Vector3.one*.42
   orb.Color=Color3.fromRGB(12,10,17);orb.Material=Enum.Material.SmoothPlastic;orb.Massless=true
   orb.CanCollide=false;orb.CanTouch=false;orb.CanQuery=false;orb:SetAttribute("HeroCosmetic",true)
   orb:SetAttribute("CosmeticBody","UpperTorso");orb:SetAttribute("CosmeticOffset",offset);orb.CFrame=torso.CFrame*offset;orb.Parent=folder
   local weld=Instance.new("Weld");weld.Name="FormVisualWeld";weld.Part0=torso;weld.Part1=orb;weld.C0=offset;weld.Parent=orb
  end
 end
 for _,part in folder:GetChildren() do
  if part:IsA("BasePart") then part:SetAttribute("AppearanceTransparency",part.Transparency) end
 end
 folder:SetAttribute("AppearanceVersion",version)
 folder:SetAttribute("AppearanceForm",form)
 folder:SetAttribute("AppearanceParts",#folder:GetChildren())
 folder:SetAttribute("AppearanceDescendants",#folder:GetDescendants())
 if previous then previous.Name="PreviousHeroAppearance" end
 folder.Parent=model
 model:SetAttribute("HeroVisualForm",form)
 model:SetAttribute("HeroAppearanceVersion",version)
 -- Each client retains its own loaded visual until the next one is ready.
 -- This grace window also covers replication of the new folder and its children.
 if previous then game:GetService("Debris"):AddItem(previous,3) end
end
function Appearance.Apply(model: Model)
 dress(model)
 if bound[model] then return end
 local connections={};bound[model]=connections
 for _,attribute in {"SagePhase","KcmActive","KcmRank","KuramaActive","SasukeMode","SusanooForm","GarudaActive"} do
  table.insert(connections,model:GetAttributeChangedSignal(attribute):Connect(function() dress(model) end))
 end
 model.Destroying:Once(function() for _,connection in connections do connection:Disconnect() end;bound[model]=nil end)
end
return Appearance
