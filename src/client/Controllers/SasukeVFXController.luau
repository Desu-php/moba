--!strict
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local Data=require(Shared.Config.SasukeParticleData) :: any
local Spells=require(script.Parent.SasukeSpellEffects)
local Presentation=require(Shared.Abilities.SasukePresentation)
local V={}
local effects:{any}={}
local held:{[Model]:Folder}={}
local swordTrails:{[Model]:{trail:Trail,base:Attachment,tip:Attachment}}={}
local models:{[Model]:boolean}={}
local folder:Folder
local function part(parent:Instance,name:string,color:Color3,size:Vector3,cf:CFrame):Part
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Anchored=true;p.Material=Enum.Material.Neon;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent;return p
end
local function particles(parent:Instance,kind:string)
 for i,s in Data[kind] or {} do
  if i>4 then break end
  local p=Instance.new("ParticleEmitter");p.Name=s.name;p.Texture=s.texture
  local colors={};for _,v in s.color do table.insert(colors,ColorSequenceKeypoint.new(v[1],Color3.new(v[2],v[3],v[4]))) end
  local sizes={};for _,v in s.size do table.insert(sizes,NumberSequenceKeypoint.new(v[1],math.min(v[2],2),math.min(v[3],.3))) end
  local transparency={};for _,v in s.transparency do table.insert(transparency,NumberSequenceKeypoint.new(v[1],v[2],v[3])) end
  p.Color=ColorSequence.new(colors);p.Size=NumberSequence.new(sizes);p.Transparency=NumberSequence.new(transparency)
  p.Lifetime=NumberRange.new(math.min(s.lifetime[1],.4),math.min(s.lifetime[2],.7));p.Speed=NumberRange.new(0,math.min(s.speed[2],2))
  p.Rate=math.min(s.rate,25);p.LightEmission=s.light;p.SpreadAngle=Vector2.new(s.spread[1],s.spread[2]);p.Parent=parent
 end
end
local function lightning(parent:Instance,a:Vector3,b:Vector3,color:Color3,seed:number)
 local delta=b-a
 for i=1,9 do
  local x=(i-1)/9;local y=i/9
  local function at(t:number):Vector3 return a+delta*t+Vector3.new(math.sin(t*73+seed),math.cos(t*49+seed),0)*math.sin(t*math.pi)*.5 end
  local first,last=at(x),at(y);part(parent,"Lightning",color,Vector3.new(.09,.09,(last-first).Magnitude),CFrame.lookAt((first+last)/2,last))
 end
end
function V.Message(message:any)
 if message.kind~="Sasuke" or typeof(message.position)~="Vector3" then return end
 if message.id=="AreaEnd" or message.id=="FireEnd" then Spells.Message(message);return end
 local camera=workspace.CurrentCamera;if camera and (camera.CFrame.Position-message.position).Magnitude>300 then return end
 if message.id=="ChibakuDrop" then
  for i=#effects,1,-1 do local e=effects[i];if e.id=="Chibaku" and e.caster==message.character then e.folder:Destroy();table.remove(effects,i) end end
 end
 if Spells.Message(message) then return end
 if #effects>=48 then effects[1].folder:Destroy();table.remove(effects,1) end
 local id=message.id;local radius=math.clamp(message.radius or 1,.1,125)
 if id=="Extinguish" then
  for i=#effects,1,-1 do local e=effects[i];if e.id=="Amaterasu" and (e.point-message.position).Magnitude<=radius then e.folder:Destroy();table.remove(effects,i) end end;return
 end
 if id=="ChibakuMove" then
  for _,e in effects do if e.id=="Chibaku" and e.caster==message.character then
   e.moveAt=workspace:GetServerTimeNow();e.moveDuration=message.duration;e.movePoints=message.extra.points;e.moveFrom={}
   for i,p in e.parts do e.moveFrom[i]=p.Position end
  end end;return
 end
 if id=="ChibakuEnd" or id=="ChibakuDrop" or id=="Chibaku" then
  for i=#effects,1,-1 do local e=effects[i];if e.caster==message.character and e.id=="Chibaku" then e.folder:Destroy();table.remove(effects,i) end end
 end
 if id=="ChibakuEnd" then return end
 local f=Instance.new("Folder");f.Name=id;f.Parent=folder
 if id=="Impact" and message.extra then for i=#effects,1,-1 do local e=effects[i];if e.id=="Projectile" and e.extra and e.extra.serial==message.extra.serial then e.folder:Destroy();table.remove(effects,i) end end end
 local color=if id=="Amaterasu" then Color3.fromRGB(40,13,66) elseif id=="Fire" or (message.extra and (message.extra.spell=="SasukeFireball" or message.extra.spell=="PhoenixFlowers")) then Color3.fromRGB(255,125,30) else Color3.fromRGB(144,113,255)
 local parts={};local origin=message.position
 if id=="Projectile" then
  local p=part(f,"Projectile",color,Vector3.one*math.min(radius*2,4),CFrame.new(origin));p.Shape=Enum.PartType.Ball;table.insert(parts,p)
  local light=Instance.new("PointLight");light.Color=color;light.Range=10;light.Brightness=2;light.Parent=p
 elseif id=="Eiso" then lightning(f,origin,message.extra.finish,Color3.fromRGB(170,230,255),os.clock())
 elseif id=="ChidoriHit" then
  local direction=if message.extra and typeof(message.extra.direction)=="Vector3" then message.extra.direction else Vector3.zAxis
  local frame=CFrame.lookAt(origin,origin+direction)
  local tint=if message.extra and message.extra.variant=="OnyxChidori" then Color3.fromRGB(178,117,255) elseif message.extra and message.extra.variant=="AmaterasuChidori" then Color3.fromRGB(113,61,167) else Color3.fromRGB(154,225,255)
  local flash=part(f,"ContactFlash",Color3.fromRGB(232,250,255),Vector3.one*.85,CFrame.new(origin));flash.Shape=Enum.PartType.Ball;table.insert(parts,flash)
  local light=Instance.new("PointLight");light.Color=tint;light.Range=9;light.Brightness=4;light.Parent=flash
  for i=1,9 do
   local angle=i*2.399
   local offset=frame:VectorToWorldSpace(Vector3.new(math.cos(angle)*1.5,math.sin(angle)*1.5,-(1+i%3)*.7))
   lightning(f,origin,origin+offset,tint,i*3.1)
  end
  local caster=message.character;local hand=if caster then caster:FindFirstChild("LeftHand") else nil
  if hand and hand:IsA("BasePart") then lightning(f,hand.Position,origin,tint,1) end
  particles(flash,"Chidori")
  for _,emitter in flash:GetChildren() do if emitter:IsA("ParticleEmitter") then emitter.Enabled=false;emitter:Emit(12) end end
 elseif id=="Kirin" then
  lightning(f,origin+Vector3.new(0,65,0),origin,Color3.fromRGB(160,218,255),os.clock())
  local p=part(f,"LightningDome",Color3.fromRGB(150,210,255),Vector3.one*radius*2,CFrame.new(origin));p.Shape=Enum.PartType.Ball;p.Transparency=.7;table.insert(parts,p)
 elseif id=="Chibaku" then
  for _,point in message.extra.points do local p=part(f,"GravityCore",Color3.fromRGB(25,20,37),Vector3.one*3,CFrame.new(point));p.Shape=Enum.PartType.Ball;table.insert(parts,p) end
 elseif id=="ChibakuDrop" then
  for _,point in message.extra.points do local p=part(f,"FallingCore",Color3.fromRGB(63,55,71),Vector3.one*4,CFrame.new(point+Vector3.new(0,18,0)));p.Shape=Enum.PartType.Ball;table.insert(parts,p) end
 elseif id=="ChibakuMove" then
  for _,point in message.extra.points do local p=part(f,"GravityCore",Color3.fromRGB(25,20,37),Vector3.one*3,CFrame.new(point+Vector3.new(0,18,0)));p.Shape=Enum.PartType.Ball;table.insert(parts,p) end
 else
  local ring=part(f,"ExactArea",color,Vector3.new(.08,radius*2,radius*2),CFrame.new(origin+Vector3.new(0,.08,0))*CFrame.Angles(0,0,math.pi/2));ring.Shape=Enum.PartType.Cylinder;ring.Transparency=.7;table.insert(parts,ring)
  if id=="Amaterasu" or id=="Fire" then
   for i=1,18 do local angle=i*2.399;local r=radius*math.sqrt(i/19)
    local p=part(f,"Flame",color,Vector3.new(.5,2.5,.5),CFrame.new(origin+Vector3.new(math.cos(angle)*r,1,math.sin(angle)*r)));p.Transparency=.15;table.insert(parts,p)
    if id=="Amaterasu" and i<=4 then particles(p,"Amaterasu") end
   end
  elseif id=="Nagashi" or id=="Counter" then
   for i=1,8 do local angle=i*math.pi/4;lightning(f,origin,origin+Vector3.new(math.cos(angle),0,math.sin(angle))*radius,Color3.fromRGB(170,235,255),i) end
  end
 end
 table.insert(effects,{folder=f,id=id,point=origin,at=message.at or workspace:GetServerTimeNow(),duration=math.clamp(message.duration or .5,.1,30),parts=parts,extra=message.extra,caster=message.character})
end
function V.Start()
 folder=Instance.new("Folder");folder.Name="LocalSasukeVFX";folder.Parent=workspace
 Spells.Start(folder,models)
 local remote=game.ReplicatedStorage:WaitForChild("HeroAbility") :: RemoteEvent
 remote.OnClientEvent:Connect(V.Message)
 local function add(item:Instance) if item:IsA("Humanoid") and item.Parent and item.Parent:IsA("Model") then models[item.Parent]=true end end
 for _,item in workspace:GetDescendants() do add(item) end
 workspace.DescendantAdded:Connect(add);workspace.DescendantRemoving:Connect(function(item) if item:IsA("Humanoid") and item.Parent and item.Parent:IsA("Model") then models[item.Parent]=nil end end)
 Run.RenderStepped:Connect(function()
  local now=workspace:GetServerTimeNow()
  Spells.Update(now)
  for model in models do
   if not model.Parent then models[model]=nil;continue end
   if model:GetAttribute("HeroId")~="Sasuke" then continue end
   Spells.Avatar(model,now)
   local hand=model:FindFirstChild("LeftHand") or model:FindFirstChild("RightHand")
   local variant=model:GetAttribute("ChidoriVariant")
   if variant=="SusanooChidori" then local costume=model:FindFirstChild("DisplayedHeroAppearance");hand=if costume then costume:FindFirstChild("Larm2") or hand else hand end
   local active=model:GetAttribute("ChidoriHeld")==true or ((model:GetAttribute("ChidoriStrikeUntil") or 0) :: number)>now
   if active and hand and hand:IsA("BasePart") then
    local f=held[model]
    if not f then
     f=Instance.new("Folder");f.Name="ChidoriHeld";f.Parent=folder;held[model]=f
     local orb=part(f,"Core",Color3.fromRGB(213,245,255),Vector3.one*.45,hand.CFrame);orb.Shape=Enum.PartType.Ball;particles(orb,"Chidori")
     local light=Instance.new("PointLight");light.Color=Color3.fromRGB(130,205,255);light.Brightness=2;light.Range=8;light.Parent=orb
     for _=1,12 do part(f,"Arc",Color3.fromRGB(144,215,255),Vector3.one*.1,hand.CFrame) end
    end
    local index=0
    for _,p in f:GetChildren() do if p:IsA("BasePart") then
     if p.Name=="Core" then p.CFrame=hand.CFrame;p.Size=Vector3.one*(if variant=="SusanooChidori" then 1.8 else .45);p.Color=if variant=="OnyxChidori" then Color3.fromRGB(155,80,255) elseif variant=="AmaterasuChidori" then Color3.fromRGB(47,15,77) else Color3.fromRGB(213,245,255) else index+=1;local a=now*17+index*2.399
      local endPoint=hand.Position+Vector3.new(math.sin(a),math.cos(a*1.3),math.cos(a))*(if variant=="SusanooChidori" then 3 else 1.1)
      p.Size=Vector3.new(.045,.045,(endPoint-hand.Position).Magnitude);p.CFrame=CFrame.lookAt((endPoint+hand.Position)/2,endPoint)
     end
    end end
   elseif held[model] then held[model]:Destroy();held[model]=nil end
   local appearance=model:FindFirstChild("DisplayedHeroAppearance")
   local root=model:FindFirstChild("HumanoidRootPart")
   local attackAt=(model:GetAttribute("CombatLastAttackAt") or 0) :: number
   local swordHand=model:FindFirstChild("RightHand")
   if swordHand and swordHand:IsA("BasePart") and not swordTrails[model] then
    local base=Instance.new("Attachment");base.Name="SasukeSwordTrailBase";base.Position=Vector3.new(.088,-.144,-.6);base.Parent=swordHand
    local tip=Instance.new("Attachment");tip.Name="SasukeSwordTrailTip";tip.Position=Vector3.new(.088,-.144,-4.5);tip.Parent=swordHand
    local trail=Instance.new("Trail");trail.Name="SwordArc";trail.Attachment0=base;trail.Attachment1=tip;trail.Lifetime=.12;trail.MinLength=.06
    trail.Color=ColorSequence.new(Color3.fromRGB(180,216,245));trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.65),NumberSequenceKeypoint.new(1,1)})
    trail.LightEmission=.4;trail.FaceCamera=true;trail.Enabled=false;trail.Parent=swordHand
    swordTrails[model]={trail=trail,base=base,tip=tip}
   end
   local sword=swordTrails[model]
   if sword then
    local ends=(model:GetAttribute("CombatAttackEndsAt") or 0) :: number
    local phase=(now-attackAt)/math.max(.001,ends-attackAt)
    sword.trail.Enabled=not active and ((model:GetAttribute("SusanooForm") or 0) :: number)<3 and phase>.12 and phase<.7 and now<ends
   end
   if appearance and root and root:IsA("BasePart") then for _,p in appearance:GetChildren() do
    if p:IsA("BasePart") and p:GetAttribute("CosmeticBody")=="RightHand" then
     local offset=p:GetAttribute("CosmeticOffset");local handPart=model:FindFirstChild("RightHand")
     if typeof(offset)=="CFrame" and handPart and handPart:IsA("BasePart") then
      local weld=p:FindFirstChild("FormVisualWeld");if weld then weld:Destroy() end;p.Anchored=true
      local casting=((model:GetAttribute("SasukeCastPoseUntil") or 0) :: number)>now and model:GetAttribute("SasukeCastPose")~="ChidoriKatana"
      local grip=if casting then root.CFrame*CFrame.new(1,-.7,.8)*CFrame.Angles(0,math.pi/2,.12) else handPart.CFrame
      p.CFrame=grip*offset
     end
    end
    if p:IsA("BasePart") and p:GetAttribute("GarudaWing") then
     local w=p:FindFirstChild("FormVisualWeld");local offset=p:GetAttribute("CosmeticOffset")
     if typeof(offset)=="CFrame" then
      if w then w:Destroy() end;p.Anchored=true
      p.CFrame=root.CFrame*CFrame.new(0,-4,0)*CFrame.Angles(0,0,math.sin(now*7)*.35*(p:GetAttribute("GarudaWing") :: number))*CFrame.new(0,4,0)*offset
     end
    end
    if p:IsA("BasePart") and p:GetAttribute("SusanooChakra")==true then
    local w=p:FindFirstChild("FormVisualWeld");local offset=p:GetAttribute("CosmeticOffset")
    if typeof(offset)=="CFrame" then
     -- Animate the displayed cosmetic copy, never the server character assembly.
     if w then w:Destroy() end;p.Anchored=true
     local ends=(model:GetAttribute("CombatAttackEndsAt") or 0) :: number
     local hit=(model:GetAttribute("CombatAttackHitAt") or 0) :: number
     local duration=math.max(.001,ends-attackAt)
     local phase=(now-attackAt)/duration;local swing=Presentation.susanooSwing(phase,(hit-attackAt)/duration)
     local pivot=p:GetAttribute("SusanooPivot")
     local side=if p:GetAttribute("SusanooLimb")=="Right" then 1 else -1
     local angle=if side==1 then swing*1.25 else swing*.3
     p.CFrame=root.CFrame*(if typeof(pivot)=="Vector3" then CFrame.new(pivot)*CFrame.Angles(angle,0,-side*swing*.2)*CFrame.new(-pivot)*offset else offset)
    end
   end end end
  end
  for model,f in held do if not models[model] then f:Destroy();held[model]=nil end end
  for model,sword in swordTrails do if not models[model] then sword.trail:Destroy();sword.base:Destroy();sword.tip:Destroy();swordTrails[model]=nil end end
  for i=#effects,1,-1 do local e=effects[i];local progress=(now-e.at)/e.duration
   if progress>=1 or not e.folder.Parent or (e.caster and not e.caster.Parent) then e.folder:Destroy();table.remove(effects,i);continue end
   if e.id=="ChidoriHit" then
    for _,p in e.folder:GetChildren() do if p:IsA("BasePart") then
     p.Transparency=math.clamp(progress*1.8,0,1)
     local light=p:FindFirstChildOfClass("PointLight");if light then light.Brightness=4*(1-progress) end
    end end
   end
   if e.extra and e.extra.follow and e.caster and e.caster.Parent then
    local point=e.caster:GetPivot().Position;local delta=point-e.point
    for _,p in e.folder:GetChildren() do if p:IsA("BasePart") then p.CFrame+=delta end end;e.point=point
   end
   for j,p in e.parts do
    if e.id=="Projectile" and e.extra then p.Position=e.point:Lerp(e.extra.finish,math.clamp(progress,0,1))
    elseif e.id=="Chibaku" and e.moveAt then p.Position=e.moveFrom[j]:Lerp(e.movePoints[j]+Vector3.new(0,18,0),math.clamp((now-e.moveAt)/math.max(.01,e.moveDuration),0,1))
    elseif e.id=="Chibaku" then p.Position=e.extra.points[j]+Vector3.new(0,18*math.clamp((now-e.at)/(e.extra.rise or 2),0,1),0)
    elseif e.id=="ChibakuDrop" then p.Position=e.extra.points[j]+Vector3.new(0,18*(1-progress),0)
    elseif e.id=="Amaterasu" or e.id=="Fire" then if j>1 then p.Size=Vector3.new(.5,1.5+math.sin(now*13+j)^2*2,.5) end
    elseif e.id~="Chibaku" and e.id~="ChibakuMove" then p.Transparency=math.max(p.Transparency,progress) end
   end
  end
 end)
 require(script.Parent.RoundController).Watch(function() Spells.Clear();for _,e in effects do e.folder:Destroy() end;table.clear(effects) end)
end
return V
