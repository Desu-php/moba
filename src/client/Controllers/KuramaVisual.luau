--!strict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Players=game:GetService("Players")
local Avatar=require(Shared.KuramaAvatar)
local Config=require(Shared.Config.KuramaAvatarConfig)
local Visual={}
type Wave={folder:Folder,parts:{Part},center:Vector3,radius:number,at:number}
local waves:{Wave}={}
local function claws(part:BasePart,enabled:boolean)
 if not part:GetAttribute("KuramaTrailsReady") then
  part:SetAttribute("KuramaTrailsReady",true)
  for i=-1,1 do
   local a=Instance.new("Attachment");a.Position=Vector3.new(i*part.Size.X*.32,0,-part.Size.Z*.46);a.Parent=part
   local b=Instance.new("Attachment");b.Position=a.Position+Vector3.new(.24,.08,.15);b.Parent=part
   local trail=Instance.new("Trail");trail.Name="KuramaClawTrail";trail.Attachment0=a;trail.Attachment1=b
   trail.Color=ColorSequence.new(Color3.fromRGB(255,239,142),Color3.fromRGB(255,147,18))
   trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})
   trail.Lifetime=.22;trail.LightEmission=1;trail.FaceCamera=true;trail.MinLength=.04;trail.Enabled=false;trail.Parent=part
  end
 end
 for _,child in part:GetChildren() do if child:IsA("Trail") then child.Enabled=enabled end end
end
function Visual.Avatar(model:Model,root:BasePart,now:number)
 local costume=model:FindFirstChild("DisplayedHeroAppearance")
 if not costume or costume:GetAttribute("AppearanceForm")~="Kurama" then return end
 local move=math.clamp(Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude/22,0,1)
 local started,ends=model:GetAttribute("CombatLastAttackAt"),model:GetAttribute("CombatAttackEndsAt")
 local phase:number?=nil
 if model:GetAttribute("CombatState")=="Attacking" and typeof(started)=="number" and typeof(ends)=="number" and ends>started and now<ends then
  phase=math.clamp((now-started)/(ends-started),0,1)
 end
 local serial=(model:GetAttribute("CombatAttackSerial") or 0) :: number
 for _,part in costume:GetChildren() do
  if not part:IsA("BasePart") then continue end
  local weld=part:FindFirstChild("FormVisualWeld");local base=part:GetAttribute("CosmeticOffset")
  if not weld or not weld:IsA("Weld") or typeof(base)~="CFrame" then continue end
  weld.C0=Avatar.Motion(part.Name,base,now,move,phase,serial)
  -- The giant tail fan must not hide the crosshair and enemies from its owner.
  if model==Players.LocalPlayer.Character and string.find(part.Name,"Tail",1,true) then
   local camera=workspace.CurrentCamera
   local behind=camera~=nil and root.CFrame:PointToObjectSpace(camera.CFrame.Position).Z>0
   part.LocalTransparencyModifier=if behind then .62 else 0
  end
  if string.find(part.Name,"Hand",1,true) then
   local side=if string.find(part.Name,"Left",1,true) then -1 else 1
   claws(part,phase~=nil and phase>=Config.SwipeStart and phase<=Config.SwipeEnd and side==(if serial%2==0 then -1 else 1))
  end
 end
end
function Visual.Event(message:any,parent:Folder)
 if message.kind~="KuramaShockwave" or typeof(message.center)~="Vector3" or typeof(message.radius)~="number"
  or typeof(message.startAt)~="number" or message.radius<=0 or message.radius>50 then return end
 local now=workspace:GetServerTimeNow();if now-message.startAt>.65 then return end
 local camera=workspace.CurrentCamera;if camera and (camera.CFrame.Position-message.center).Magnitude>220 then return end
 while #waves>=6 do local old=table.remove(waves,1);if old then old.folder:Destroy() end end
 local group=Instance.new("Folder");group.Name="KuramaShockwave";group.Parent=parent
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 if typeof(message.character)=="Instance" then params.FilterDescendantsInstances={message.character} end
 params.RespectCanCollide=true
 local ground=workspace:Raycast(message.center,Vector3.new(0,-20,0),params)
 local center=if ground then ground.Position+Vector3.new(0,.12,0) else message.center-Vector3.new(0,2.8,0)
 local parts:{Part}={}
 for _=1,48 do
  local p=Instance.new("Part");p.Name="ShockwaveEdge";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
  p.CastShadow=false;p.Material=Enum.Material.Neon;p.Color=Color3.fromRGB(255,205,79);p.Parent=group;table.insert(parts,p)
 end
 group:SetAttribute("DamageRadius",message.radius)
 table.insert(waves,{folder=group,parts=parts,center=center,radius=message.radius,at=message.startAt})
end
function Visual.Update(now:number)
 for i=#waves,1,-1 do
  local wave=waves[i];local age=now-wave.at
  if age>=.65 or not wave.folder.Parent then wave.folder:Destroy();table.remove(waves,i);continue end
  -- Inset by half the line width so even the ring's outer edge stays in the damage area.
  local radius=math.max(0,wave.radius-.07)*math.clamp(age/.12,0,1)
  for j,p in wave.parts do
   local a=(j-1)*math.pi*2/48;local b=j*math.pi*2/48
   local from=wave.center+Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius)
   local to=wave.center+Vector3.new(math.cos(b)*radius,0,math.sin(b)*radius)
   p.Size=Vector3.new(.12,.10,math.max(.01,(to-from).Magnitude));p.CFrame=CFrame.lookAt((from+to)/2,to)
   p.Transparency=math.clamp(age/.65,0,1)
  end
 end
end
function Visual.Clear() for _,wave in waves do wave.folder:Destroy() end;table.clear(waves) end
return Visual
