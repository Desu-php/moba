--!strict
-- Original procedural art. Seven/nine visuals remain one authoritative damage zone.
local Run=game:GetService("RunService")
local Units=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Abilities.WorldUnits)
local Rounds=require(script.Parent.RoundController)
type Projectile={core:Part,a:Part,b:Part}
type Effect={folder:Folder,caster:Model,life:number,code:string,origin:Vector3,target:Vector3,
 startedAt:number,releaseAt:number,arrivalAt:number?,center:Vector3,projectiles:{Projectile},ring:{Part},radius:number}
local active:{[string]:Effect}={}
local starts,arrivals,pulses,ends=0,0,0,0
local started=false
local V={}
local function remove(key:string)
 local e=active[key];if e then active[key]=nil;e.folder:Destroy() end
end
local function clear() for key in active do remove(key) end end
local function part(parent:Folder,name:string,color:Color3):Part
 local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.CastShadow=false;p.Material=Enum.Material.Neon;p.Color=color;p.Size=Vector3.one;p.Parent=parent;return p
end
function V.Diagnostics():(number,number,{number})
 local n,parts=0,0;for _,e in active do n+=1;parts+=#e.projectiles*3+#e.ring end
 return n,parts,{starts,arrivals,pulses,ends}
end
function V.Event(message:any)
 if typeof(message.key)~="string" then return end
 local key=message.key
 if message.kind=="RikudoEnd" then ends+=1;remove(key);return end
 if message.kind=="RikudoStart" then
  if typeof(message.caster)~="Instance" or not (message.caster :: Instance):IsA("Model")
   or typeof(message.origin)~="Vector3" or typeof(message.target)~="Vector3" then return end
  local camera=workspace.CurrentCamera
  if camera and (camera.CFrame.Position-message.origin).Magnitude>260 then return end
  remove(key)
  local count=0;local oldest:string?=nil;local at=math.huge
  for id,e in active do count+=1;if e.startedAt<at then at=e.startedAt;oldest=id end end
  if count>=12 and oldest then remove(oldest) end
  local folder=Instance.new("Folder");folder.Name="RikudoRasenshurikenVFX";folder.Parent=workspace
  local e:Effect={folder=folder,caster=message.caster :: Model,life=message.life,code=message.abilityId,
   origin=message.origin,target=message.target,startedAt=message.startedAt,releaseAt=message.releaseAt,
   arrivalAt=nil,center=message.target,projectiles={},ring={},radius=0}
  local color=if e.code=="A0HY" then Color3.fromRGB(107,216,255) else Color3.fromRGB(187,138,255)
  for _=1,(if e.code=="A0HY" then 7 else 9) do
   local core=part(folder,"ChakraCore",Color3.fromRGB(38,31,65));core.Shape=Enum.PartType.Ball
   table.insert(e.projectiles,{core=core,a=part(folder,"WindBlade",color),b=part(folder,"WindBlade",color)})
  end
  for _=1,16 do local p=part(folder,"DamageZoneEdge",color);p.Transparency=1;table.insert(e.ring,p) end
  active[key]=e;starts+=1;return
 end
 local e=active[key];if not e then return end
 if message.kind=="RikudoArrived" and typeof(message.position)=="Vector3" then
  e.arrivalAt=message.at;e.center=message.position;arrivals+=1
 elseif message.kind=="RikudoPulse" and typeof(message.radius)=="number" then
  e.radius=message.radius;pulses+=1
 end
end
function V.Start()
 if started then return end;started=true;Rounds.Watch(clear)
 Run.RenderStepped:Connect(function()
  local now=workspace:GetServerTimeNow()
  for key,e in active do
   local hp=e.caster:FindFirstChildOfClass("Humanoid")
   if not e.caster.Parent or not hp or hp.Health<=0 or e.caster:GetAttribute("LifeId")~=e.life or now>e.startedAt+10 then remove(key);continue end
   local delta=(e.target-e.origin)*Vector3.new(1,0,1)
   local length=delta.Magnitude;local direction=if length>.001 then delta.Unit else Vector3.xAxis
   local preparing=now<e.releaseAt
   local travel=math.min(length,math.max(0,now-e.releaseAt)*Units.toStuds(1000))
   local center=if e.arrivalAt then e.center else e.origin+direction*travel+Vector3.new(0,(e.target.Y-e.origin.Y)*(if length>.001 then travel/length else 1),0)
   local spread=Units.toStuds(300)*(if preparing then .15 else 1)
   local size=if e.code=="A0HY" then 1.05 else 1.45
   local elapsed=if e.arrivalAt then math.max(0,now-e.arrivalAt) else 0
   local radius=if e.arrivalAt then Units.toStuds(636+4*(if e.code=="A0HY" then math.min(58,math.floor((elapsed+.03)/.06)) else math.min(116,math.floor(elapsed/.03)+1))) else 0
   radius=math.max(radius,e.radius)
   for i,p in e.projectiles do
    local angle=(i-2)*math.pi*2/(#e.projectiles-1)
    local offset=if i==1 then Vector3.zero else Vector3.new(math.cos(angle),0,math.sin(angle))*spread
    local point=center+offset
    if e.arrivalAt then point=e.center+offset*.3+Vector3.new(0,math.sin(now*6+i)*.4,0) end
    p.core.Size=Vector3.one*size*(if preparing then .7 else 1);p.core.CFrame=CFrame.new(point)
    local cf=CFrame.new(point)*CFrame.Angles(0,now*15+i,0)
    p.a.Size=Vector3.new(size*3.8,.1,size*.28);p.b.Size=Vector3.new(size*.28,.1,size*3.8)
    p.a.CFrame=cf;p.b.CFrame=cf
   end
   for i,p in e.ring do
    if radius<=0 then p.Transparency=1;continue end
    local a=(i-1)*math.pi/8;local b=i*math.pi/8
    local first=e.center+Vector3.new(math.cos(a)*radius,-.85,math.sin(a)*radius)
    local second=e.center+Vector3.new(math.cos(b)*radius,-.85,math.sin(b)*radius)
    p.Size=Vector3.new(.12,.12,(second-first).Magnitude);p.CFrame=CFrame.lookAt((first+second)/2,second);p.Transparency=.22
   end
  end
 end)
end
return V
