--!strict
-- Chakra currents with a reviewed Creator Store wind-blade mesh. See docs/CREATOR-ASSETS.md.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StoreData=require(Shared.Config.CreatorVisualData)
local Factory=require(Shared.CreatorVisualFactory)
local Particles=require(script.Parent.ChakraParticleVisual)
local Visual = {}
local cyan = Color3.fromRGB(80,198,255)
local ice = Color3.fromRGB(213,250,255)
local white = Color3.fromRGB(248,255,255)
type Current = { part: Part, ring: number, segment: number }
export type Orb = { group: Model, core: Part, plasma: Part, glow: Part, currents: {Current}, storeBlade: Part, storeMesh: SpecialMesh,
 particles: Particles.State?, light: PointLight, variant: string, changedAt: number, radius: number, detailed: boolean, size: number }
export type Burst = { group: Model, parts: {Part}, at: number, duration: number, radius: number, variant: string }
local function part(parent: Instance, name: string, color: Color3): Part
 local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
 p.Material=Enum.Material.Neon; p.Color=color; p.CastShadow=false; p.Size=Vector3.one*.1; p.Parent=parent; return p
end
local function sphere(parent: Instance, name: string, color: Color3, transparency: number): Part
 local p=part(parent,name,color); p.Shape=Enum.PartType.Ball; p.Transparency=transparency; return p
end
function Visual.Create(parent: Instance, source: Model, detailed: boolean): Orb
 local group=Instance.new("Model"); group.Name="RasenganChakra"; group:SetAttribute("Source",source.Name); group.Parent=parent
 -- Saturated, deliberately low-value Neon avoids both white clipping and the
 -- directional shadow of an opaque plastic ball. Geometric currents need no Beam texture.
 local core=sphere(group,"ChakraCore",Color3.fromRGB(10,85,135),.08)
 local plasma=sphere(group,"BluePlasma",Color3.fromRGB(18,96,163),.78)
 local glow=sphere(group,"ChakraHalo",Color3.fromRGB(10,65,145),.95)
 local currents: {Current}={}
 for ring=1,if detailed then 0 else 2 do for segment=1,if detailed then 24 else 8 do
  local current=part(group,"RotatingChakraCurrent",Color3.fromRGB(92,198,245))
  table.insert(currents,{part=current,ring=ring,segment=segment})
 end end
 local storeBlade,storeMesh=Factory.Part(StoreData.blade)
 storeBlade.Name="CreatorStoreWindBlades";storeBlade.Anchored=true;storeBlade.Transparency=1
 storeBlade.Material=Enum.Material.Neon;storeBlade.Color=Color3.fromRGB(145,230,255);storeBlade.Parent=group
 local light=Instance.new("PointLight"); light.Color=cyan; light.Range=5; light.Brightness=.22; light.Shadows=false; light.Parent=core
 return {group=group,core=core,plasma=plasma,glow=glow,currents=currents,storeBlade=storeBlade,storeMesh=storeMesh,light=light,
  particles=if detailed then Particles.Create(core) else nil,variant="",changedAt=0,radius=.1,detailed=detailed,size=0}
end
function Visual.Update(state: Orb, source: Model, hand: BasePart, now: number, dt: number)
 local attr=source:GetAttribute("RasenganVariant")
 local variant=if attr=="Odama" or attr=="Rasenshuriken" then attr else "Rasengan"
 if variant~=state.variant then
  state.variant=variant; state.changedAt=now; state.group:SetAttribute("Variant",variant)
  state.group.Name=if variant=="Odama" then "OdamaRasenganChakra" elseif variant=="Rasenshuriken" then "RasenshurikenChakra" else "RasenganChakra"
 end
 local ready=source:GetAttribute("RasenganReadyAt"); local started=source:GetAttribute("RasenganStartedAt")
 -- CFrame stores float32 values. Unix-sized angles erase small ring offsets and
 -- frame-to-frame movement; keep all rotations relative to this short-lived cast.
 local animationTime=if typeof(started)=="number" then math.max(0,now-started) else now%100
 local preparation=if typeof(ready)=="number" and typeof(started)=="number" then math.clamp((now-started)/math.max(.1,ready-started),0,1) else 1
 local charge=if source:GetAttribute("RasenganPhase")=="Preparing" then .16+.84*preparation^1.2 else 1
 local targetRadius=(if variant=="Odama" then 2.15 elseif variant=="Rasenshuriken" then .95 else .66)*charge
 state.radius+=(targetRadius-state.radius)*(1-math.exp(-16*math.min(dt,.1)))
 local radius=math.max(.04,state.radius)
 local upgrade=math.max(0,1-(now-state.changedAt)/.35)
 local offset=if variant=="Odama" then Vector3.new(0,-1.9,-.3) elseif variant=="Rasenshuriken" then Vector3.new(0,-1,-.25) else Vector3.new(0,-.85,-.35)
 local position=hand.CFrame:PointToWorldSpace(offset)
 local center=CFrame.new(position)
 state.core.CFrame=center; state.plasma.CFrame=center; state.glow.CFrame=center
 local pulse=1+math.sin(animationTime*17)*.018
 state.core.Size=Vector3.one*radius*1.64*pulse
 state.plasma.Size=Vector3.one*radius*1.93
 state.glow.Size=Vector3.one*radius*(2.15+upgrade*.35)
 state.core.Color=if variant=="Rasenshuriken" then Color3.fromRGB(12,104,151) else Color3.fromRGB(10,85,135)
 state.plasma.Color=if variant=="Rasenshuriken" then Color3.fromRGB(24,113,177) else Color3.fromRGB(18,96,163)
 state.glow.Transparency=.96-upgrade*.035
 state.light.Range=math.min(8,radius*3+2); state.light.Brightness=.18+upgrade*.12
 if state.particles then Particles.Update(state.particles,radius);state.core.Transparency=.65;state.plasma.Transparency=.93 end
 state.size=radius*2
 -- Three independently rotating, tapered arcs form a readable spherical vortex.
 -- All are outside the plasma shell, so even opaque-volume ordering cannot hide them.
 local segmentCount=if state.detailed then 24 else 8
 for _,current in state.currents do
  local ring,index=current.ring,current.segment
  local rotation=center*CFrame.Angles(ring*.92+animationTime*.21,ring*1.16+animationTime*.14,ring*.73)
  local spin=(if ring%2==0 then -1 else 1)*animationTime*(if variant=="Odama" then 4.7 else 6.8)
  local span=math.pi*1.58
  local angle=spin+(index-1)*span/segmentCount
  local nextAngle=angle+span/segmentCount*1.05
  local r=radius*(1.025+(ring-1)*.018)
  local a=rotation:PointToWorldSpace(Vector3.new(math.cos(angle)*r,math.sin(angle)*r,0))
  local b=rotation:PointToWorldSpace(Vector3.new(math.cos(nextAngle)*r,math.sin(nextAngle)*r,0))
  local tail=(index-1)/segmentCount
  local thickness=radius*(.065-.03*tail)
  local p=current.part
  p.Size=Vector3.new(thickness,thickness,(b-a).Magnitude*1.08)
  p.CFrame=CFrame.lookAt((a+b)/2,b)
  p.Transparency=if state.particles then 1 else .05+tail*.68
 end
 local shuriken=variant=="Rasenshuriken"
 if shuriken then
  local root=source:FindFirstChild("HumanoidRootPart")
  local facing=if root and root:IsA("BasePart") then root.CFrame.Rotation else CFrame.identity
  -- Tilted wind-disc remains recognisable from the shoulder camera, with its
  -- normal independent of wrist rotation so all four points remain readable.
  local bladeFrame=center*facing*CFrame.Angles(math.rad(-35),0,0)*CFrame.Angles(0,animationTime*10,0)
  local size=math.clamp(radius/.95,0,1)
  -- The store mesh is 20.72 studs wide at its authored scale. Fit the same 7.3-stud disc.
  local factor=7.3/StoreData.blade.size[1]*size
  state.storeBlade.CFrame=bladeFrame
  state.storeMesh.Scale=Factory.Vector(StoreData.blade.scale)*factor
  state.storeBlade.Transparency=.3
 else
  state.storeBlade.Transparency=1
 end
end
function Visual.Destroy(state: Orb) state.group:Destroy() end
function Visual.Burst(parent: Instance, position: Vector3, variant: string, kind: string, now: number): Burst
 local group=Instance.new("Model"); group.Name=variant..kind; group.Parent=parent
 local parts: {Part}={}
 local radius=if variant=="Odama" then 6 elseif variant=="Rasenshuriken" then 5 else 3.2
 local duration=if kind=="Contact" then .24 elseif kind=="Impact" then .48 else .62
 if kind=="Contact" then radius*=.42 end
 for index=1,if kind=="Contact" then 9 else 19 do
  local p=if index<=3 then sphere(group,"PressureShell",if index==1 then white else cyan,.3) else part(group,"ChakraSpiral",ice)
  p.Position=position; table.insert(parts,p)
 end
 return {group=group,parts=parts,at=now,duration=duration,radius=radius,variant=variant}
end
function Visual.UpdateBurst(state: Burst, position: Vector3, now: number)
 local t=math.clamp((now-state.at)/state.duration,0,1)
 for index,p in state.parts do
  if index<=3 then
   p.Size=Vector3.one*math.max(.03,state.radius*(.15+t*(if index==1 then .7 else 1.3)))
   p.Position=position; p.Transparency=math.clamp((if index==1 then .25 else .72)+t*.75,0,1)
  else
   local angle=(index-4)*math.pi*2/(#state.parts-3)+t*3.3
   local nextAngle=angle+.22
   local r=state.radius*(.15+t)
   local height=math.sin(angle*2)*(1-t)*state.radius*.35
   local a=position+Vector3.new(math.cos(angle)*r,height,math.sin(angle)*r)
   local b=position+Vector3.new(math.cos(nextAngle)*r,height+.12,math.sin(nextAngle)*r)
   p.Size=Vector3.new(.045,.045,(b-a).Magnitude);p.CFrame=CFrame.lookAt((a+b)/2,b);p.Transparency=t
  end
 end
end
return Visual
