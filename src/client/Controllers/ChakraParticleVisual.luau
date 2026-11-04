--!strict
local Data=require(game:GetService("ReplicatedStorage").Shared.Config.ChakraParticleData)
local Visual={}
export type Layer={emitter: ParticleEmitter, sizes: {{number}}}
export type State={layers: {Layer}, radius: number}
local function sequence(keys: {{number}}, radius: number?): NumberSequence
 local points: {NumberSequenceKeypoint}={}
 for _,k in keys do table.insert(points,NumberSequenceKeypoint.new(k[1],if radius then math.min(2.4,k[2]*2.5)*radius else k[2],0)) end
 return NumberSequence.new(points)
end
function Visual.Create(parent: BasePart): State
 local attachment=Instance.new("Attachment");attachment.Name="CreatorChakra";attachment.Parent=parent
 local state: State={layers={},radius=0}
 for _,spec in Data do
  local e=Instance.new("ParticleEmitter");e.Name=spec.name;e.Texture=spec.texture
  e.Rate=math.min(30,spec.rate*.6);e.Lifetime=NumberRange.new(spec.lifetime[1],spec.lifetime[2])
  e.Rotation=NumberRange.new(spec.rotation[1],spec.rotation[2]);e.RotSpeed=NumberRange.new(spec.rotSpeed[1],spec.rotSpeed[2])
  e.Speed=NumberRange.new(0);e.LockedToPart=true;e.Orientation=Enum.ParticleOrientation.FacingCamera
  e.LightEmission=1;e.LightInfluence=0;e.Transparency=sequence(spec.transparency)
  local colors: {ColorSequenceKeypoint}={}
  for _,k in spec.color do table.insert(colors,ColorSequenceKeypoint.new(k[1],if string.find(spec.name,"golden") then Color3.fromRGB(125,225,255) else Color3.new(k[2],k[3],k[4]))) end
  e.Color=ColorSequence.new(colors);e.Size=sequence(spec.size,.04);e.Parent=attachment
  table.insert(state.layers,{emitter=e,sizes=spec.size})
 end
 return state
end
function Visual.Update(state: State,radius: number)
 if math.abs(radius-state.radius)<.015 then return end
 state.radius=radius
 for _,layer in state.layers do layer.emitter.Size=sequence(layer.sizes,radius) end
end
return Visual
