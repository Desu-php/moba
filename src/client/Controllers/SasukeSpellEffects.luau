--!strict
-- Server messages supply centres, radii, endpoints and timestamps. No client damage.
local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local Rules=require(Shared.Abilities.SasukePresentation)
local Flame=require(script.Parent.SasukeFlameFX)
local FireCast=require(script.Parent.SasukeFireCastFX)
local Combat=require(Shared.Config.CombatConfig)
local FX={}
local active:{any}={}
local avatars:{[Model]:any}={}
local actors:{[Model]:boolean}={}
local parent:Folder
local violet=Color3.fromRGB(155,78,240)
local blue=Color3.fromRGB(125,214,255)
local fire=Color3.fromRGB(255,117,27)
local handled={Amaterasu=true,Fire=true,KirinPrepare=true,KirinWarning=true,Kirin=true,Transform=true,
 Katana=true,Nagashi=true,Genjutsu=true,Teleport=true,EntonPull=true,Eiso=true,Projectile=true,Impact=true,
 ChibakuDrop=true,ChibakuImpact=true,Extinguish=true,AreaEnd=true,EntonPierce=true,Summon=true,EntonGather=true,SusanooWave=true,EntonCombo=true,EntonComboWarning=true,AmaterasuWarning=true}
local function make(f:Instance,name:string,size:Vector3,cf:CFrame,color:Color3,alpha:number?):Part
 local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Size=size;p.CFrame=cf;p.Color=color;p.Material=Enum.Material.Neon;p.Transparency=alpha or 0;p.Parent=f;return p
end
local function ball(f:Instance,name:string,size:Vector3,point:Vector3,color:Color3,alpha:number?):Part
 local p=make(f,name,size,CFrame.new(point),color,alpha)
 -- SpecialMesh keeps non-uniform flame/neck proportions; Part.Shape Ball does not.
 local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=p
 return p
end
local function line(f:Instance,name:string,a:Vector3,b:Vector3,color:Color3,width:number,alpha:number?):Part
 return make(f,name,Vector3.new(width,width,math.max(.01,(b-a).Magnitude)),CFrame.lookAt((a+b)/2,b),color,alpha)
end
local function floor(point:Vector3,caster:Model?):Vector3
 local ignore:{Instance}={parent};if caster then table.insert(ignore,caster) end
 for model in actors do table.insert(ignore,model) end
 local p=RaycastParams.new();p.FilterDescendantsInstances=ignore;p.RespectCanCollide=true
 local hit=workspace:Raycast(point+Vector3.new(0,6,0),Vector3.new(0,-40,0),p)
 return if hit then hit.Position+Vector3.new(0,.12,0) else point
end
local function ring(e:any,center:Vector3,radius:number,color:Color3)
 -- Boundary stays fixed. Interior animation never advertises a larger hit area.
 for i=1,32 do local a,b=(i-1)*math.pi/16,i*math.pi/16
  local first=floor(center+Vector3.new(math.cos(a),0,math.sin(a))*radius,e.caster)
  local last=floor(center+Vector3.new(math.cos(b),0,math.sin(b))*radius,e.caster)
  line(e.folder,"DamageBoundary",first,last,color,.11,.2)
 end
 local mark=floor(center,e.caster)
 line(e.folder,"AimCentre",mark-Vector3.new(.7,0,0),mark+Vector3.new(.7,0,0),color,.1,.25)
 line(e.folder,"AimCentre",mark-Vector3.new(0,0,.7),mark+Vector3.new(0,0,.7),color,.1,.25)
end
local function bolt(f:Instance,a:Vector3,b:Vector3,color:Color3,width:number,seed:number)
 local delta=b-a;local last=a
 for i=1,10 do local t=i/10
  local nextPoint=a+delta*t+Vector3.new(math.sin(i*5+seed),0,math.cos(i*3+seed))*math.sin(t*math.pi)*math.min(1,delta.Magnitude*.06)
  line(f,"LightningArc",last,nextPoint,color,width,.15);last=nextPoint
 end
end
local function dragon(e:any)
 e.dragon={}
 local body=Color3.fromRGB(37,116,187)
 local function piece(name:string,offset:Vector3,size:Vector3,color:Color3,rotation:CFrame?,angular:boolean?)
  local p=if angular then make(e.folder,name,size,CFrame.new(e.point+offset),color,.12) else ball(e.folder,name,size,e.point+offset,color,.12)
  p.Material=Enum.Material.SmoothPlastic
  table.insert(e.dragon,{part=p,offset=offset,rotation=rotation});return p
 end
 -- Overlapping tapered neck, broad canine muzzle and branching antlers. Darker
 -- body preserves the silhouette under bloom; only eyes and mane emit light.
 for i=1,8 do
  local width=5-i*.42
  piece("LightningNeck",Vector3.new(math.sin(i*.52)*3,i*2.1,2+i*.35),Vector3.new(width,5,width),body,CFrame.Angles(0,0,-math.cos(i*.52)*.3))
 end
 piece("KirinHead",Vector3.zero,Vector3.new(7,4.8,6),body)
 piece("KirinMuzzle",Vector3.new(0,-1,-3),Vector3.new(4.7,2.2,4),Color3.fromRGB(65,156,219),nil,true)
 piece("KirinNose",Vector3.new(0,-.5,-5),Vector3.new(3.5,.8,.6),Color3.fromRGB(15,50,95),nil,true)
 piece("KirinJaw",Vector3.new(0,-2.6,-2.7),Vector3.new(3.6,.7,3.9),body,CFrame.Angles(.14,0,0),true)
 for sign=-1,1,2 do
  piece("KirinEye",Vector3.new(sign*2.5,.3,-2.5),Vector3.new(.8,.45,.65),Color3.fromRGB(255,245,180)).Material=Enum.Material.Neon
  piece("KirinBrow",Vector3.new(sign*2.4,.9,-2.8),Vector3.new(2,.55,1),body,CFrame.Angles(0,0,-sign*.3),true)
  piece("KirinHorn",Vector3.new(sign*2.7,3.8,1),Vector3.new(.65,6,.65),blue,CFrame.Angles(.25,0,-sign*.35),true)
  piece("AntlerBranch",Vector3.new(sign*4,4,1.5),Vector3.new(.4,3,.4),blue,CFrame.Angles(.4,0,-sign*.9),true)
  for i=1,4 do
   local mane=piece("LightningMane",Vector3.new(sign*(3.3+i*.3),.5+i*.65,1+i*.5),Vector3.new(.4,3+i*.5,.5),blue,CFrame.Angles(.55,0,-sign*(.6+i*.12)),true)
   mane.Material=Enum.Material.Neon;mane.Transparency=.35
  end
  for i=1,2 do piece("KirinFang",Vector3.new(sign*1.5,-1.8,-2-i),Vector3.new(.35,.9,.4),blue,nil,true) end
 end
 local root=if e.caster then e.caster:FindFirstChild("HumanoidRootPart") else nil
 local facing=if root and root:IsA("BasePart") then (root.Position-e.point)*Vector3.new(1,0,1) else Vector3.zAxis
 e.dragonFacing=if facing.Magnitude>.01 then CFrame.lookAt(Vector3.zero,facing) else CFrame.identity
end
function FX.Start(folder:Folder,models:{[Model]:boolean}) parent=folder;actors=models end
function FX.Clear()
 FireCast.Clear()
 for _,e in active do e.folder:Destroy() end;table.clear(active)
 for _,e in avatars do e.folder:Destroy() end;table.clear(avatars)
end
function FX.Avatar(model:Model,now:number)
 local form=(model:GetAttribute("SusanooForm") or 0) :: number
 local h=model:FindFirstChildOfClass("Humanoid");local root=model:FindFirstChild("HumanoidRootPart")
 local e=avatars[model]
 if form<=0 or not model.Parent or not h or h.Health<=0 or not root or not root:IsA("BasePart") then
  if e then e.folder:Destroy();avatars[model]=nil end;return
 end
 if not e then
  local f=Instance.new("Folder");f.Name="SusanooAura";f.Parent=parent
  e={folder=f,wisps={},boundary={}};avatars[model]=e
  for _=1,10 do table.insert(e.wisps,ball(f,"ChakraFlare",Vector3.new(.3,2,.3),root.Position,violet,.7)) end
  e.blade=make(f,"ChakraBlade",Vector3.one,CFrame.new(root.Position),violet,.4)
  e.core=make(f,"BladeCore",Vector3.one,CFrame.new(root.Position),Color3.fromRGB(213,177,255),.35)
  for _=1,5 do table.insert(e.boundary,make(f,"AttackFootprint",Vector3.one,CFrame.new(root.Position),violet,1)) end
 end
 local at=(model:GetAttribute("CombatLastAttackAt") or 0) :: number
 local ends=(model:GetAttribute("CombatAttackEndsAt") or 0) :: number
 local hit=(model:GetAttribute("CombatAttackHitAt") or 0) :: number
 local duration=math.max(.001,ends-at);local phase=(now-at)/duration
 local swing=Rules.susanooSwing(phase,(hit-at)/duration)
 local rise=math.clamp((now-((model:GetAttribute("SusanooFormAt") or now) :: number))/.7,0,1)
 for i,p in e.wisps do local a=i*2.399+now*.8;local radius=if form>=3 then 4 else 2.3
  p.Position=root.Position+Vector3.new(math.cos(a)*radius,((now*.6+i*.13)%1)*(if form>=3 then 13 else 4)*rise-1,math.sin(a)*radius)
  p.Size=Vector3.new(.22,if form>=3 then 3 else 1.4,.22);p.Transparency=.65+.2*math.sin(now*2+i)^2
 end
 local appearance=model:FindFirstChild("DisplayedHeroAppearance");local hand=if appearance then appearance:FindFirstChild("Rarm2") else nil
 local show=form>=3 and hand and hand:IsA("BasePart")
 if show and hand and hand:IsA("BasePart") then
  local from=hand.Position
  local rest=from+root.CFrame.LookVector*6
  local contact=root.CFrame:PointToWorldSpace(Vector3.new(0,.4,-14))
  local tip=rest:Lerp(contact,swing);local cf=CFrame.lookAt((from+tip)/2,tip);local length=(tip-from).Magnitude
  e.blade.CFrame=cf;e.blade.Size=Vector3.new(.4,.8,length);e.blade.Transparency=.45
  e.core.CFrame=cf;e.core.Size=Vector3.new(.12,.3,length);e.core.Transparency=.35
 else e.blade.Transparency=1;e.core.Transparency=1 end
 -- Clip the box by the same forward-angle requirement as server target selection.
 local profile=Combat.Profiles.SasukeSusanoo
 local half=profile.HitboxSize.X/2;local depth=profile.HitboxSize.Z
 local near=half/math.tan(math.acos(profile.MinimumForwardDot))
 local corners={Vector3.zero,Vector3.new(half,0,-near),Vector3.new(half,0,-depth),Vector3.new(-half,0,-depth),Vector3.new(-half,0,-near)}
 for i,p in e.boundary do
  p.Transparency=if form>=3 and phase>=0 and phase<.65 then .45 else 1
  local a=root.CFrame:PointToWorldSpace(corners[i]);local b=root.CFrame:PointToWorldSpace(corners[i%5+1])
  a-=Vector3.new(0,h.HipHeight+root.Size.Y/2-.15,0);b-=Vector3.new(0,h.HipHeight+root.Size.Y/2-.15,0)
  p.CFrame=CFrame.lookAt((a+b)/2,b);p.Size=Vector3.new(.08,.08,(b-a).Magnitude)
 end
end
function FX.Message(m:any):boolean
 if FireCast.Message(m,parent) then return true end
 if m.id=="KirinCancel" or m.id=="EntonCancel" then
  for i=#active,1,-1 do local e=active[i]
   if e.caster==m.character and (e.id=="KirinWarning" or e.id=="Kirin" or e.id=="EntonGather" or e.id=="EntonComboWarning" or e.id=="EntonCombo") then e.folder:Destroy();table.remove(active,i) end
  end
  return true
 end
 if m.id=="AreaMove" then
  for _,e in active do if e.extra.areaSerial==m.extra.areaSerial then
   e.moveFrom=m.position;e.moveGoal=m.extra.goal;e.moveAt=m.at;e.moveDuration=math.max(.01,m.duration)
  end end
  return true
 end
 if not handled[m.id] then return false end
 if m.id=="AreaEnd" then
  for i=#active,1,-1 do local e=active[i];if m.extra and e.extra and e.extra.areaSerial==m.extra.areaSerial then e.folder:Destroy();table.remove(active,i) end end
  return true
 end
 if m.id=="Impact" then
  for i=#active,1,-1 do local e=active[i];if e.id=="Projectile" and e.extra.serial==m.extra.serial then e.folder:Destroy();table.remove(active,i) end end
 end
 if m.id=="Extinguish" then return true end -- AreaEnd identifies exactly which server areas were removed.
 local f=Instance.new("Folder");f.Name=m.id;f.Parent=parent
 local e:any={id=m.id,folder=f,caster=m.character,point=m.position,at=m.at or workspace:GetServerTimeNow(),duration=math.max(.1,m.duration or .5),radius=m.radius or 1,extra=m.extra or {},parts={},flames={},clouds={}}
 f:SetAttribute("DamageRadius",e.radius);f:SetAttribute("ServerCentre",e.point)
 f:SetAttribute("ServerStartedAt",e.at);f:SetAttribute("ServerExpiresAt",e.at+e.duration)
 if #active>=64 then active[1].folder:Destroy();table.remove(active,1) end
 table.insert(active,e)
 local r=e.radius;local ground=floor(e.point,e.caster)
 if e.id=="Amaterasu" or e.id=="Fire" or e.id=="EntonCombo" then
  local black=e.id~="Fire";local tint=if black then violet else fire
  ring(e,e.point,r,tint)
  local patch=make(f,"ScorchedArea",Vector3.new(.03,r*1.9,r*1.9),CFrame.new(ground)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(14,9,20),.65);patch.Shape=Enum.PartType.Cylinder
  local count=math.clamp(math.floor(r*r*.22),8,24)
  for i=1,count do local angle=i*2.399;local distance=Rules.flameRadius(math.max(.1,r-1.6),i,count)
   local base=floor(e.point+Vector3.new(math.cos(angle),0,math.sin(angle))*distance,e.caster)
   local scale=math.min(2.2,math.max(.65,r*.22))*(.8+(i%4)*.12)
   local core=make(f,"FlameSource",Vector3.one*.15,CFrame.new(base),tint,1)
   Flame.Attach(core,scale,black,false)
   if i%8==0 then Flame.Light(core,scale,black) end
   table.insert(e.flames,{base=base,core=core,scale=scale})
  end
 elseif e.id=="SusanooWave" then
  e.moveFrom=e.point;e.moveGoal=e.extra.finish;e.moveAt=e.at;e.moveDuration=e.duration
  ring(e,e.point,r,violet)
  local dir=e.extra.finish-e.point;local cf=CFrame.lookAt(e.point,e.point+dir)
  for i=1,13 do local x=(i-7)/6
   local offset=cf:VectorToWorldSpace(Vector3.new(x*r,2+5*(1-x*x),-3*(1-x*x)))
   local p=ball(f,"ShockCrest",Vector3.new(2,5,1),e.point+offset,violet,.65);table.insert(e.parts,p)
  end
 elseif e.id=="EntonComboWarning" or e.id=="AmaterasuWarning" then
  ring(e,e.point,r,violet)
 elseif e.id=="EntonGather" then
  ring(e,e.point,r,violet)
  for i=1,12 do local a=i*math.pi/6
   table.insert(e.parts,ball(f,"GravityStream",Vector3.new(.25,.25,2),e.point+Vector3.new(math.cos(a)*r,1,math.sin(a)*r),violet,.35))
  end
 elseif e.id=="KirinWarning" then
  ring(e,e.point,r,blue);dragon(e)
  for i=1,7 do local a=i*2.399
   table.insert(e.clouds,ball(f,"StormCloud",Vector3.new(13,3,10),e.point+Vector3.new(math.cos(a)*r*.45,35+i%3,math.sin(a)*r*.45),Color3.fromRGB(38,51,72),.58))
  end
 elseif e.id=="Kirin" or e.id=="ChibakuImpact" or e.id=="Impact" then
  local tint=if e.id=="Kirin" then blue elseif e.id=="ChibakuImpact" or (e.extra.spell=="EntonMagatama" or e.extra.spell=="EntonWeapon" or e.extra.spell=="EntonArrow") then violet elseif e.extra.spell=="SasukeFireball" or e.extra.spell=="PhoenixFlowers" then fire else blue
  ring(e,e.point,r,tint)
  if e.id=="Kirin" then bolt(f,e.point+Vector3.new(0,45,0),e.point,Color3.fromRGB(221,249,255),.8,3) end
  local fireImpact=e.id=="Impact" and ((e.extra.spell=="EntonMagatama" or e.extra.spell=="EntonWeapon" or e.extra.spell=="EntonArrow") or e.extra.spell=="SasukeFireball" or e.extra.spell=="PhoenixFlowers")
  for i=1,if fireImpact then 0 else 8 do local a=i*math.pi/4
   bolt(f,e.point,e.point+Vector3.new(math.cos(a),.03,math.sin(a))*math.max(.1,r-.8),tint,.13,i)
  end
  e.flash=ball(f,"ImpactCore",Vector3.one*math.min(4,r),e.point,tint,.25)
  if fireImpact then
   e.flash.Transparency=1;Flame.Burst(e.flash,math.clamp(r*.45,1,3.5),(e.extra.spell=="EntonMagatama" or e.extra.spell=="EntonWeapon" or e.extra.spell=="EntonArrow"))
  else
   local light=Instance.new("PointLight");light.Range=math.min(24,r*2);light.Brightness=3;light.Color=tint;light.Parent=e.flash
  end
 elseif e.id=="KirinPrepare" then
  e.rising=ball(f,"SkyFire",Vector3.one*1.8,e.point+Vector3.new(0,2,0),fire,1);Flame.Attach(e.rising,1.7,false,true);Flame.Light(e.rising,1.7,false)
  for i=1,4 do table.insert(e.clouds,ball(f,"GatheringCloud",Vector3.new(8,2,6),e.point+Vector3.new(math.sin(i*2)*7,24,math.cos(i*2)*7),Color3.fromRGB(45,54,73),.7)) end
 elseif e.id=="Projectile" then
  local black=(e.extra.spell=="EntonMagatama" or e.extra.spell=="EntonWeapon" or e.extra.spell=="EntonArrow")
  local fiery=black or e.extra.spell=="SasukeFireball" or e.extra.spell=="PhoenixFlowers"
  local size=if e.extra.spell=="EntonArrow" then 2 elseif e.extra.spell=="EntonWeapon" then 1.5 elseif e.extra.spell=="SasukeFireball" then 3.4 elseif fiery then 1 else .22
  e.body=ball(f,if fiery then "FireballCore" else "LightningNeedle",Vector3.one*size,e.point,if fiery then Color3.fromRGB(255,222,117) else blue,.05)
  e.shell=ball(f,"ProjectileShell",Vector3.one*size*1.3,e.point,if fiery then fire else blue,.5)
  e.tail=line(f,"ProjectileTail",e.point,e.point+Vector3.new(0,0,1),if fiery then fire else blue,if fiery then size*.45 else .12,.55)
  if fiery then
   e.fiery=true;e.flameSize=size
   e.body.Transparency=1;e.shell.Transparency=1;e.tail.Transparency=1
   e.body.Size=Vector3.one*size*.35
   local delta=e.extra.finish-e.point
   if delta.Magnitude>.01 then e.body.CFrame=CFrame.lookAt(e.point,e.extra.finish) end
   local layers=Flame.Attach(e.body,size*.8,black,true)
   for _,v in layers do v:Emit(if v.Name=="FlameTongues" then 12 else 4) end
   e.fireLight=Flame.Light(e.body,size,black)
   if e.extra.spell=="EntonArrow" or e.extra.spell=="EntonWeapon" then
    e.weapon=make(f,"BlackFlameShaft",Vector3.new(.4,.4,if e.extra.spell=="EntonArrow" then 8 else 5),CFrame.new(e.point),Color3.fromRGB(17,7,25),.1)
    e.tip=make(f,"FlameArrowHead",Vector3.new(2,.6,3),CFrame.new(e.point),violet,.3)
    local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Wedge;mesh.Parent=e.tip
    Flame.Attach(e.weapon,.7,true,false)
   end
  end
 elseif e.id=="ChibakuDrop" then
  for _,point in e.extra.points do ring(e,point,r,Color3.fromRGB(235,117,150));table.insert(e.parts,ball(f,"FallingCore",Vector3.one*4,point+Vector3.new(0,18,0),Color3.fromRGB(53,46,65),.05)) end
 elseif e.id=="Eiso" then
  bolt(f,e.point,e.extra.finish,blue,.22,1)
  line(f,"LightningSpear",e.point,e.extra.finish,Color3.fromRGB(230,250,255),.12,.1)
 elseif e.id=="Katana" then
  for i=1,6 do table.insert(e.parts,make(f,"SwordLightning",Vector3.new(.045,.045,.7),CFrame.new(e.point),blue,.1)) end
 elseif e.id=="EntonPierce" then
  local lance=line(f,"BlackFlameLance",e.extra.from,e.point,Color3.fromRGB(16,7,27),.65,.25)
  Flame.Attach(lance,.7,true,false)
  line(f,"VioletLanceEdge",e.extra.from,e.point,violet,.85,.75)
 elseif e.id=="Summon" then
  for i=1,9 do local a=i*2.399
   local p=ball(f,"SummonSmoke",Vector3.one*2,e.point+Vector3.new(math.cos(a)*2,i%3*.5,math.sin(a)*2),Color3.fromRGB(202,205,215),.35)
   p.Material=Enum.Material.SmoothPlastic;table.insert(e.parts,p)
  end
 elseif e.id=="Nagashi" or e.id=="EntonPull" then
  ring(e,e.point,r,if e.id=="Nagashi" then blue else violet)
  for i=1,12 do local a=i*math.pi/6
   if e.id=="Nagashi" then bolt(f,e.point,e.point+Vector3.new(math.cos(a)*math.max(.1,r-.6),.5,math.sin(a)*math.max(.1,r-.6)),blue,.1,i)
   else
    local p=make(f,"BlackFlameSpike",Vector3.new(.7,4,.7),CFrame.new(ground+Vector3.new(math.cos(a)*4,1.8,math.sin(a)*4))*CFrame.Angles(math.cos(a)*.4,0,math.sin(a)*.4),Color3.fromRGB(19,8,29),.05)
    local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Wedge;mesh.Parent=p
    Flame.Attach(p,.8,true,false)
   end
  end
 elseif e.id=="Transform" then
  -- Vertical chakra, deliberately no ground danger circle for a self buff.
  for i=1,14 do local a=i*2.399
   local p=ball(f,"SusanooChakra",Vector3.new(.5,4,.5),e.point+Vector3.new(math.cos(a)*3,0,math.sin(a)*3),violet,.65)
   table.insert(e.parts,p)
  end
 elseif e.id=="Genjutsu" then
  e.eye=ball(f,"Sharingan",Vector3.new(2,.15,2),e.point+Vector3.new(0,3.5,0),if e.extra.rinnegan then violet else Color3.fromRGB(203,37,55),.25)
  for i=1,3 do local a=i*math.pi*2/3
   ball(f,"Tomoe",Vector3.one*.25,e.eye.Position+Vector3.new(math.cos(a)*.55,.1,math.sin(a)*.55),Color3.fromRGB(10,6,13))
  end
 elseif e.id=="Teleport" then
  for i=1,7 do local a=i*math.pi*2/7;line(f,"SpaceFracture",e.point+Vector3.new(math.cos(a)*2,-2,math.sin(a)*2),e.point+Vector3.new(math.cos(a+.4)*2,3,math.sin(a+.4)*2),violet,.08,.2) end
 end
 return true
end
function FX.Update(now:number)
 FireCast.Update(now)
 for model,e in avatars do if not model.Parent then e.folder:Destroy();avatars[model]=nil end end
 for i=#active,1,-1 do local e=active[i];local t=math.clamp((now-e.at)/e.duration,0,1)
  local h=if e.caster and e.caster.Parent then e.caster:FindFirstChildOfClass("Humanoid") else nil
  if t>=1 or not e.folder.Parent or (e.caster and (not e.caster.Parent or (h and h.Health<=0))) then e.folder:Destroy();table.remove(active,i);continue end
  local tracked=if e.id=="KirinWarning" and e.extra.target and e.extra.target.Parent then e.extra.target:FindFirstChild("HumanoidRootPart") else nil
  if (e.extra.follow and e.caster) or e.moveGoal or tracked then
   local point=if tracked then tracked.Position elseif e.moveGoal then e.moveFrom:Lerp(e.moveGoal,math.clamp((now-e.moveAt)/e.moveDuration,0,1)) else e.caster:GetPivot().Position;local delta=point-e.point
   for _,p in e.folder:GetChildren() do if p:IsA("BasePart") then p.CFrame+=delta end end
   for _,v in e.flames do v.base+=delta end;e.point=point;e.folder:SetAttribute("ServerCentre",point)
  end
  if e.id=="Amaterasu" or e.id=="Fire" or e.id=="EntonCombo" then
   for j,v in e.flames do
    v.core.Position=v.base+Vector3.new(math.sin(now*3+j)*.12,0,math.cos(now*4+j)*.12)
    local light=v.core:FindFirstChildOfClass("PointLight")
    if light then light.Brightness=(if e.id=="Amaterasu" then .4 else 1.5)*(.85+.15*math.sin(now*17+j)) end
   end
  elseif e.id=="KirinWarning" then
   local height=26*(1-t^3)+3
   for _,v in e.dragon do v.part.CFrame=CFrame.new(e.point+Vector3.new(0,height,0))*e.dragonFacing*CFrame.new(v.offset)*(v.rotation or CFrame.identity) end
   for j,p in e.clouds do p.Transparency=.58+math.sin(now*10+j)*.08 end
  elseif e.id=="EntonGather" then
   for j,p in e.parts do local a=j*math.pi/6;local radial=e.radius*(1-t)
    local pos=e.point+Vector3.new(math.cos(a)*radial,1,math.sin(a)*radial);p.CFrame=CFrame.lookAt(pos,e.point);p.Transparency=.3+.5*t
   end
  elseif e.id=="KirinPrepare" then
   local pos=e.point+Vector3.new(0,2+25*math.min(1,t*3),0)
   e.rising.CFrame=CFrame.lookAt(pos,pos+Vector3.yAxis);e.rising.Transparency=1
   for _,v in e.rising:GetChildren() do
    if v:IsA("ParticleEmitter") then v.Enabled=t<.65
    elseif v:IsA("PointLight") then v.Brightness=1.5*(1-t) end
   end
  elseif e.id=="Projectile" then
   local delay=e.extra.delay or 0;t=math.clamp((now-e.at-delay)/math.max(.01,e.duration-delay),0,1)
   local delta=e.extra.finish-e.point;local pos=e.point+delta*t;local dir=if delta.Magnitude>.01 then delta.Unit else Vector3.zAxis
   e.body.CFrame=CFrame.lookAt(pos,pos+dir);e.shell.Position=pos
   if e.weapon then e.weapon.CFrame=e.body.CFrame;e.tip.CFrame=e.body.CFrame*CFrame.new(0,0,-e.weapon.Size.Z/2) end
   if e.fiery then e.fireLight.Brightness=1.5+math.sin(now*23)*.25 end
   local tail=pos-dir*math.min(5,delta.Magnitude*t+1);e.tail.Size=Vector3.new(e.tail.Size.X,e.tail.Size.Y,math.max(.1,(pos-tail).Magnitude));e.tail.CFrame=CFrame.lookAt((pos+tail)/2,pos)
  elseif e.id=="Katana" then
   local hand=e.caster:FindFirstChild("RightHand")
   if hand and hand:IsA("BasePart") then for j,p in e.parts do p.CFrame=hand.CFrame*CFrame.new(.09+math.sin(now*25+j)*.12,-.14,-.6-j*.6)*CFrame.Angles(0,0,math.sin(now*20+j)*.5) end end
  elseif e.id=="Transform" then
   local point=e.caster:GetPivot().Position
   for j,p in e.parts do local a=j*2.399+now*.9;p.Position=point+Vector3.new(math.cos(a)*(3+t*2),((now*2+j*.5)%1)*12,math.sin(a)*(3+t*2));p.Transparency=.5+.3*math.sin(now+j)^2 end
  elseif e.id=="ChibakuDrop" then
   for j,p in e.parts do p.Position=e.extra.points[j]+Vector3.new(0,18*(1-t*t),0) end
  elseif e.id=="Summon" then
   for j,p in e.parts do local a=j*2.399;p.Position=e.point+Vector3.new(math.cos(a)*(2+t*2),j%3*.5+t*1.5,math.sin(a)*(2+t*2));p.Size=Vector3.one*(2+t*2);p.Transparency=.35+.65*t end
  else
   if e.flash then local light=e.flash:FindFirstChildOfClass("PointLight");if light then light.Brightness=3*(1-t)^2 end end
   for _,p in e.folder:GetChildren() do if p:IsA("BasePart") and p.Name~="DamageBoundary" then p.Transparency=math.max(p.Transparency,t) end end
  end
 end
end
return FX
