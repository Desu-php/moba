--!strict
-- Rebuild only whitelisted visual properties; never load marketplace scripts at runtime.
local Factory = {}
export type Spec = { name: string, body: string, form: string, size: {number}, cf: {number}, color: {number},
 transparency: number, mesh: string, texture: string, scale: {number}, offset: {number},
 decals: {{face: string, texture: string, transparency: number}} }
function Factory.Vector(v: {number}): Vector3 return Vector3.new(v[1],v[2],v[3]) end
function Factory.Frame(v: {number}): CFrame
 return CFrame.new(v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],v[9],v[10],v[11],v[12])
end
function Factory.Part(spec: Spec): (Part, SpecialMesh)
 local p=Instance.new("Part");p.Name=spec.name;p.Size=Factory.Vector(spec.size)
 p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.CastShadow=false
 p.Color=Color3.new(spec.color[1],spec.color[2],spec.color[3]);p.Transparency=spec.transparency
 p.Material=Enum.Material.SmoothPlastic
 local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.FileMesh
 mesh.MeshId=spec.mesh;mesh.TextureId=spec.texture;mesh.Scale=Factory.Vector(spec.scale);mesh.Offset=Factory.Vector(spec.offset);mesh.Parent=p
 for _,value in spec.decals do
  local decal=Instance.new("Decal");decal.Face=(Enum.NormalId :: any)[value.face]
  decal.Texture=value.texture;decal.Transparency=value.transparency;decal.Parent=p
 end
 return p,mesh
end
return Factory
