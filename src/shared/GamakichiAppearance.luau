--!strict
-- Visual-only free Creator Store snapshot: Appendance / asset 2831683674.
-- The supplied mesh is static. Idle, hopping, attack and cast motion are authored locally.
local A={}
function A.Build(model:Model,root:BasePart,adult:boolean)
 local width=if adult then 7 else 5
 local p=Instance.new("Part");p.Name="GamakichiSkin";p.Size=Vector3.new(width,width*16.804346/29.069124,width*34.830093/29.069124)
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Color=Color3.fromRGB(163,162,165)
 p:SetAttribute("HeroCosmetic",true);p:SetAttribute("ToadVisual",true);p.CFrame=root.CFrame;p.Parent=model
 local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.FileMesh;mesh.MeshId="rbxassetid://37223966";mesh.TextureId="rbxassetid://73178159"
 mesh.Scale=Vector3.new(p.Size.X/1.09912002,p.Size.Y/.33434501,p.Size.Z/.88010699);mesh.Parent=p
 local offset=CFrame.new(0,p.Size.Y/2-math.max(4,root.Size.Y)/2-.05,0)
 p:SetAttribute("ToadOffset",offset)
 if adult then
  local grip=offset*CFrame.new(2.6,-.65,-2.0)
  local pieces:{{name:string,size:Vector3,z:number,color:Color3}}={
   {name="Blade",size=Vector3.new(.16,.5,5.2),z=-2.6,color=Color3.fromRGB(201,209,217)},
   {name="Guard",size=Vector3.new(.35,1.2,.22),z=0,color=Color3.fromRGB(91,65,32)},
   {name="Grip",size=Vector3.new(.28,.28,1.15),z=.6,color=Color3.fromRGB(68,43,28)}}
  for _,spec in pieces do
   local blade=Instance.new("Part");blade.Name="GamakichiSword"..spec.name;blade.Size=spec.size;blade.Color=spec.color
   blade.Anchored=true;blade.CanCollide=false;blade.CanTouch=false;blade.CanQuery=false;blade.Material=Enum.Material.Metal
   blade:SetAttribute("HeroCosmetic",true);blade:SetAttribute("ToadSword",true);blade:SetAttribute("ToadGrip",grip);blade:SetAttribute("ToadOffset",CFrame.new(0,0,spec.z))
   blade.CFrame=root.CFrame*grip*CFrame.new(0,0,spec.z);blade.Parent=model
  end
 end
 model:SetAttribute("GamakichiVisualWidth",width);model:SetAttribute("GamakichiModelAsset",2831683674)
end
function A.Motion(now:number,moving:boolean,swingAt:number,spellAt:number,spell:string,channel:boolean):CFrame
 local hop=if moving then math.max(0,math.sin(now*9)) else 0
 local swing=math.clamp((now-swingAt)/.8,0,1)
 local strike=if swing<.625 then math.sin(swing/.625*math.pi/2) else 1-(swing-.625)/.375
 if now-swingAt<0 or now-swingAt>.8 then strike=0 end
 local age=now-spellAt
 local oil=if spell=="GamakichiOil" and age>=0 and age<.6 then math.sin(age/.6*math.pi) else 0
 local chop=if channel then math.sin(math.max(0,age-.05)*math.pi*2) else 0
 return CFrame.new(0,hop*.65+math.sin(now*2)*.035,-strike*.6+oil*.25)
  *CFrame.Angles(-hop*.08-strike*.14+oil*.12,0,chop*.12)
end
return A
