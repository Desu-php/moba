--!strict
-- Original Blender skin; combat collision is independent of the animated body.
local A={}
local template=script.Parent:WaitForChild("AodaRig")
function A.Build(model:Model,root:BasePart,adult:boolean)
 local original=template:FindFirstChildWhichIsA("MeshPart",true)
 assert(original,"Aoda mesh is missing")
 local skin=original:Clone()
 local scale=if adult then 1 else .72
 skin.Name="AodaSkin";skin.Anchored=true;skin.CanCollide=false;skin.CanTouch=false;skin.CanQuery=false
 skin.Size=original.Size*scale
 for _,bone in skin:GetDescendants() do
  if bone:IsA("Bone") then bone.CFrame=CFrame.new(bone.CFrame.Position*scale)*bone.CFrame.Rotation end
 end
 local offset=CFrame.new(original.CFrame.Position*scale+Vector3.new(0,-root.Size.Y/2,0))
 skin:SetAttribute("HeroCosmetic",true);skin:SetAttribute("AodaOffset",offset)
 skin.CFrame=root.CFrame*offset;skin.Parent=model
 model:SetAttribute("AodaVisualVersion",1);model:SetAttribute("AodaScale",scale)
end
return A
