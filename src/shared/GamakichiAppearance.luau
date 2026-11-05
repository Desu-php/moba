--!strict
-- Blender-authored skinned mesh. The collider remains independent of the visual skeleton.
local A={}
local template=script.Parent:WaitForChild("GamakichiRig")
function A.Build(model:Model,root:BasePart,adult:boolean)
 local original=template:FindFirstChildWhichIsA("MeshPart",true)
 assert(original,"Gamakichi mesh is missing")
 local skin=original:Clone()
 local scale=(if adult then 7 else 5)/original.Size.X
 skin.Name="GamakichiSkin";skin.Anchored=true;skin.CanCollide=false;skin.CanTouch=false;skin.CanQuery=false
 skin.Size=original.Size*scale
 for _,bone in skin:GetDescendants() do
  if bone:IsA("Bone") then bone.CFrame=CFrame.new(bone.CFrame.Position*scale)*bone.CFrame.Rotation end
 end
 local floor=-math.max(4,root.Size.Y)/2
 local offset=CFrame.new(original.CFrame.Position*scale+Vector3.new(0,floor,0))
 skin:SetAttribute("HeroCosmetic",true);skin:SetAttribute("ToadVisual",true);skin:SetAttribute("ToadOffset",offset)
 skin.CFrame=root.CFrame*offset;skin.Parent=model
 model:SetAttribute("GamakichiVisualWidth",if adult then 7 else 5)
 model:SetAttribute("GamakichiVisualVersion",3);model:SetAttribute("ToadScale",scale)
end
return A
