--!strict
local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local Data=require(Shared.Config.SasukeVisualData)
local Factory=require(Shared.CreatorVisualFactory)
local A={}
function A.Apply(model:Model)
 local head=model:FindFirstChild("Head");local root=model:FindFirstChild("HumanoidRootPart")
 if not head or not head:IsA("BasePart") or not root or not root:IsA("BasePart") then return end
 local mode=(model:GetAttribute("SasukeMode") or 0) :: number;local form=(model:GetAttribute("SusanooForm") or 0) :: number
 local flying=model:GetAttribute("GarudaActive")==true
 local version="Sasuke-v1:"..mode..":"..form..":"..tostring(flying)
 if model:GetAttribute("HeroAppearanceVersion")==version and model:FindFirstChild("HeroAppearance") then return end
 local previous=model:FindFirstChild("HeroAppearance")
 local folder=Instance.new("Folder");folder.Name="HeroAppearance"
 for _,item in model:GetChildren() do
  if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") then item:Destroy() end
  if item:IsA("BasePart") and item~=root then item.Transparency=if item==head then 1 else 0;item.Color=Color3.fromRGB(244,210,177) end
 end
 for _,item in head:GetChildren() do if item:IsA("Decal") then item:Destroy() end end
 local shirt=Instance.new("Shirt");shirt.ShirtTemplate=Data.shirt;shirt.Parent=model
 local pants=Instance.new("Pants");pants.PantsTemplate=Data.pants;pants.Parent=model
 local function attach(p:Part,body:BasePart,offset:CFrame)
  p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
  p:SetAttribute("HeroCosmetic",true);p:SetAttribute("CosmeticBody",body.Name);p:SetAttribute("CosmeticOffset",offset)
  p:SetAttribute("AppearanceTransparency",p.Transparency);p.CFrame=body.CFrame*offset;p.Parent=folder
  local weld=Instance.new("Weld");weld.Name="FormVisualWeld";weld.Part0=body;weld.Part1=p;weld.C0=offset;weld.Parent=p
 end
 local face=Instance.new("Part");face.Name="SasukeFace";face.Size=Vector3.new(2,1,1);face.Color=head.Color
 local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Head;mesh.Scale=Vector3.one*1.25;mesh.Parent=face
 attach(face,head,CFrame.identity)
 -- A clean geometric face avoids baking the store model's curse mark into every form.
 local function feature(name:string,size:Vector3,color:Color3,offset:CFrame)
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Material=Enum.Material.SmoothPlastic;attach(p,head,offset)
 end
 for side=-1,1,2 do
  feature("EyeWhite",Vector3.new(.29,.13,.025),Color3.fromRGB(244,244,238),CFrame.new(side*.24,.04,-.635)*CFrame.Angles(0,0,side*.08))
  feature("Iris",Vector3.new(.105,.12,.032),Color3.fromRGB(22,23,30),CFrame.new(side*.24,.035,-.655))
  feature("Brow",Vector3.new(.32,.035,.028),Color3.fromRGB(27,26,35),CFrame.new(side*.24,.165,-.64)*CFrame.Angles(0,0,side*.12))
 end
 feature("Mouth",Vector3.new(.24,.022,.025),Color3.fromRGB(96,67,62),CFrame.new(0,-.23,-.64))
 for _,spec in Data.appearance do local body=model:FindFirstChild(spec.body)
  if body and body:IsA("BasePart") then local p=Factory.Part(spec :: any);attach(p,body,Factory.Frame(spec.cf)) end
 end
 if mode>0 then
  for i=-1,1,2 do
   local eye=Instance.new("Part");eye.Name=if i==1 and mode==3 then "RinneganEye" else "SharinganEye";eye.Shape=Enum.PartType.Ball
   eye.Size=Vector3.new(.14,.12,.025);eye.Color=if i==1 and mode==3 then Color3.fromRGB(168,112,255) else Color3.fromRGB(218,30,46);eye.Material=Enum.Material.Neon
   attach(eye,head,CFrame.new(i*.23,.06,-.635))
  end
 end
 if form==1 then
  for side=-1,1,2 do for i=1,4 do
   local rib=Instance.new("Part");rib.Name="SusanooRib";rib.Size=Vector3.new(.25,.25,3.5);rib.Color=Color3.fromRGB(140,60,230);rib.Material=Enum.Material.Neon;rib.Transparency=.3
   attach(rib,root,CFrame.new(side*1.8,.2+i*.45,0)*CFrame.Angles(0,side*.25,0))
  end end
 elseif form>=2 then
  local scale=if form==2 then .15 else .23
  for _,spec in Data.susanoo do
   local lower=string.lower(spec.name)
   if string.find(lower,"wing") or (form==2 and string.find(lower,"leg")) then continue end
   local p,m=Factory.Part(spec :: any);p.Size*=scale;m.Scale*=scale;m.Offset*=scale;p.Transparency=math.max(p.Transparency,.28)
   local cf=Factory.Frame(spec.cf);local offset=CFrame.new(0,if form==2 then 4 else 14.5,0)*CFrame.Angles(0,math.pi/2,0)*(CFrame.new(cf.Position*scale)*cf.Rotation)
   p:SetAttribute("SusanooLimb",if string.find(lower,"rarm") then "Right" elseif string.find(lower,"larm") then "Left" else "Body")
   attach(p,root,offset)
  end
 end
 if flying then
  for _,spec in Data.garuda do
   local p,m=Factory.Part(spec :: any);p.Name="Garuda"..spec.name;p.Size*=1.6;m.Scale*=1.6
   local cf=Factory.Frame(spec.cf)
   local offset=CFrame.new(0,-4,0)*CFrame.Angles(-math.pi/2,0,0)*(CFrame.new(cf.Position*1.6)*cf.Rotation)
   if string.find(spec.name,"Wing") then p:SetAttribute("GarudaWing",if spec.name=="LeftWing" then -1 else 1) end
   attach(p,root,offset)
  end
 end
 folder:SetAttribute("AppearanceVersion",version);folder:SetAttribute("AppearanceForm","Sasuke")
 folder:SetAttribute("AppearanceParts",#folder:GetChildren());folder:SetAttribute("AppearanceDescendants",#folder:GetDescendants())
 if previous then previous.Name="PreviousHeroAppearance" end
 folder.Parent=model;model:SetAttribute("HeroVisualForm","Sasuke:"..mode..":"..form);model:SetAttribute("HeroAppearanceVersion",version)
 if previous then game:GetService("Debris"):AddItem(previous,3) end
end
return A
