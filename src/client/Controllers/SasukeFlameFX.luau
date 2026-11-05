--!strict
-- Local cosmetic particles only. Built-in textures need no uploaded asset permissions.
local Flame={}
local warm=ColorSequence.new({
 ColorSequenceKeypoint.new(0,Color3.fromRGB(255,245,184)),
 ColorSequenceKeypoint.new(.22,Color3.fromRGB(255,190,49)),
 ColorSequenceKeypoint.new(.6,Color3.fromRGB(245,73,12)),
 ColorSequenceKeypoint.new(1,Color3.fromRGB(85,15,7)),
})
local dark=ColorSequence.new({
 ColorSequenceKeypoint.new(0,Color3.fromRGB(8,3,13)),
 ColorSequenceKeypoint.new(.65,Color3.fromRGB(16,5,23)),
 ColorSequenceKeypoint.new(1,Color3.fromRGB(65,23,79)),
})
local function size(s:number):NumberSequence
 return NumberSequence.new({NumberSequenceKeypoint.new(0,s*.45),NumberSequenceKeypoint.new(.18,s,.18*s),NumberSequenceKeypoint.new(.65,s*.65,.15*s),NumberSequenceKeypoint.new(1,0)})
end
local function emitter(p:BasePart,name:string,texture:string):ParticleEmitter
 local v=Instance.new("ParticleEmitter");v.Name=name;v.Texture="rbxasset://textures/particles/"..texture..".dds"
 v.EmissionDirection=Enum.NormalId.Top;v.Orientation=Enum.ParticleOrientation.FacingCamera
 v.Rotation=NumberRange.new(-180,180);v.RotSpeed=NumberRange.new(-65,65)
 v.LightInfluence=0;v.LockedToPart=false;v.VelocityInheritance=0
 v.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.12,.12),NumberSequenceKeypoint.new(.65,.35),NumberSequenceKeypoint.new(1,1)})
 v.Parent=p;return v
end
function Flame.Attach(p:BasePart,scale:number,black:boolean,projectile:boolean):{ParticleEmitter}
 local layers={}
 local tongues=emitter(p,"FlameTongues","fire_main")
 tongues.Color=if black then dark else warm; tongues.LightEmission=if black then 0 else .8
 tongues.Size=size(scale*1.65);tongues.Lifetime=NumberRange.new(.22,.48)
 tongues.Speed=NumberRange.new(scale*1.4,scale*3.2);tongues.Acceleration=Vector3.new(0,scale*3,0)
 tongues.SpreadAngle=Vector2.new(26,26);tongues.Rate=if projectile then 60 else 16
 if projectile then tongues.EmissionDirection=Enum.NormalId.Back;tongues.SpreadAngle=Vector2.new(18,18) end
 table.insert(layers,tongues)
 local heart=emitter(p,"FlameHeart","fire_main")
 heart.Color=if black then dark else warm;heart.LightEmission=if black then 0 else 1
 heart.Size=size(scale*.9);heart.Lifetime=NumberRange.new(.12,.23);heart.Speed=NumberRange.new(scale*.3,scale)
 heart.Acceleration=Vector3.new(0,scale*2,0);heart.SpreadAngle=Vector2.new(40,40);heart.Rate=if projectile then 38 else 12
 table.insert(layers,heart)
 local smoke=emitter(p,"Soot","smoke_main")
 smoke.Color=ColorSequence.new(Color3.fromRGB(60,48,43),Color3.fromRGB(30,28,30))
 smoke.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,scale*.6),NumberSequenceKeypoint.new(1,scale*2.4)})
 smoke.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.8),NumberSequenceKeypoint.new(1,1)})
 smoke.Lifetime=NumberRange.new(.45,.85);smoke.Speed=NumberRange.new(scale*.4,scale)
 smoke.Acceleration=Vector3.new(0,scale*4,0);smoke.SpreadAngle=Vector2.new(30,30);smoke.Rate=if projectile then 9 else 3
 table.insert(layers,smoke)
 local sparks=emitter(p,"RisingEmbers","sparkles_main")
 sparks.Color=if black then ColorSequence.new(Color3.fromRGB(113,46,153)) else warm
 sparks.LightEmission=1;sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.1*scale),NumberSequenceKeypoint.new(1,0)})
 sparks.Lifetime=NumberRange.new(.3,.7);sparks.Speed=NumberRange.new(scale*2,scale*5)
 sparks.Acceleration=Vector3.new(0,scale*3,0);sparks.SpreadAngle=Vector2.new(45,45);sparks.Rate=if projectile then 12 else 3
 table.insert(layers,sparks)
 return layers
end
function Flame.Light(p:BasePart,scale:number,black:boolean):PointLight
 local light=Instance.new("PointLight");light.Color=if black then Color3.fromRGB(104,40,160) else Color3.fromRGB(255,148,46)
 light.Brightness=if black then .4 else 1.5;light.Range=math.min(20,scale*5);light.Shadows=false;light.Parent=p;return light
end
function Flame.Burst(p:BasePart,scale:number,black:boolean?)
 local layers=Flame.Attach(p,scale,black==true,false)
 for _,v in layers do
  v.Enabled=false;v.SpreadAngle=Vector2.new(180,180)
  v.Speed=NumberRange.new(scale*2,scale*6)
  v:Emit(if v.Name=="FlameTongues" then 32 elseif v.Name=="FlameHeart" then 18 elseif v.Name=="Soot" then 8 else 24)
 end
 Flame.Light(p,scale,black==true)
end
return Flame
