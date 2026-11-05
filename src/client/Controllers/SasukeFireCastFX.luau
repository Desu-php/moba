--!strict
local F=require(game.ReplicatedStorage.Shared.Abilities.SasukeFireRules)
local Flame=require(script.Parent.SasukeFlameFX)
local FX={}
local active:{any}={}
local function source(folder:Folder,point:Vector3,scale:number,black:boolean):Part
 local p=Instance.new("Part");p.Name="FlameSource";p.Size=Vector3.one*.1;p.Anchored=true
 p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Transparency=1;p.Position=point;p.Parent=folder
 Flame.Attach(p,scale,black,false);return p
end
function FX.Clear() for _,e in active do e.folder:Destroy() end;table.clear(active) end
function FX.Message(m:any,parent:Folder):boolean
 if m.id=="FireEnd" then
  for i=#active,1,-1 do if active[i].serial==m.extra.fireSerial then active[i].folder:Destroy();table.remove(active,i) end end
  return true
 end
 if m.id~="FireBreath" and m.id~="BlackBurn" and m.id~="BlackCoating" then return false end
 local f=Instance.new("Folder");f.Name=m.id;f.Parent=parent
 local e:any={id=m.id,folder=f,at=m.at,untilAt=m.at+m.duration,serial=m.extra.fireSerial,caster=m.character,target=m.extra.target,origin=m.position,direction=m.extra.direction,nodes={},spine={},rails={}}
 table.insert(active,e)
 if e.id=="FireBreath" then
  e.ground=m.extra.origin.Y-2.5
  for i=1,18 do
   local scale=if i==1 then 1.2 else 2+i*.32
   local p=source(f,e.origin,scale,false);table.insert(e.nodes,p)
   if i%6==0 then Flame.Light(p,scale,false) end
  end
  for i=1,9 do
   local p=source(f,e.origin,.7+i*.65,false)
   for _,v in p:GetChildren() do if v:IsA("ParticleEmitter") then
    v.EmissionDirection=Enum.NormalId.Front;v.Speed=NumberRange.new(12,24);v.Acceleration=Vector3.yAxis*2
    if v.Name=="FlameTongues" then v.Rate=28;v:Emit(8) end
   end end
   table.insert(e.spine,p)
  end
  -- Lightweight outline follows the expanding front, then the three reference circles.
  for _=1,72 do local p=Instance.new("Part");p.Name="DamageBoundary";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
   p.Material=Enum.Material.Neon;p.Color=Color3.fromRGB(255,125,30);p.Transparency=.7;p.Parent=f;table.insert(e.rails,p)
  end
 else
  for i=1,if e.id=="BlackCoating" then 8 else 4 do table.insert(e.nodes,source(f,m.position,if e.id=="BlackCoating" then 1.7 else .9,true)) end
 end
 return true
end
function FX.Update(now:number)
 for i=#active,1,-1 do local e=active[i]
  local target=e.target or e.caster;local h=if target and target.Parent then target:FindFirstChildOfClass("Humanoid") else nil
  if now>=e.untilAt or not h or h.Health<=0 or (e.id=="BlackCoating" and ((target:GetAttribute("AmaterasuCoatingUntil") or 0) :: number)<=now) then
   e.folder:Destroy();table.remove(active,i);continue
  end
  local age=math.max(0,now-e.at)
  if e.id=="FireBreath" then
   local dir=e.direction;local side=dir:Cross(Vector3.yAxis);local center=e.origin+dir*(F.front(age)/16)
   for j,p in e.nodes do
    if age<1 then
     local radius=F.radius(age)/16;local angle=j*2.399
     p.Position=if j==1 then e.origin else center+side*(math.cos(angle)*radius*.65)+dir*(math.sin(angle)*radius*.55)+Vector3.yAxis*((j%3)*.7)
    else
     local fraction=(j-1)/17;local along=fraction*1060;local width=0
     for _,circle in {{100,100},{300,300},{675,450}} do width=math.max(width,math.sqrt(math.max(0,circle[2]^2-(along-circle[1])^2))) end
     p.Position=e.origin+dir*(along/16)+side*(math.sin(j*2.399+now*.8)*width/16*.7)+Vector3.yAxis*(math.sin(now*6+j)*.35)
    end
    p.CFrame=CFrame.lookAt(p.Position,p.Position+dir)
   end
   for j,p in e.spine do
    local along=(j-1)/8*(if age<1 then F.front(age)/16 else 62)
    local pos=e.origin+dir*along
    p.CFrame=CFrame.lookAt(pos,pos+dir)
   end
   for j,p in e.rails do
    local group=math.ceil(j/24);local index=(j-1)%24;local offset:number;local radius:number
    if age<1 then offset=F.front(age)/16;radius=F.radius(age)/16;p.Transparency=if group==1 then .65 else 1
    else local circle=({{100,100},{300,300},{675,450}})[group];offset=circle[1]/16;radius=circle[2]/16;p.Transparency=.78 end
    local base=e.origin+dir*offset;local a=index*math.pi/12;local b=(index+1)*math.pi/12
    local first=Vector3.new(base.X+math.cos(a)*radius,e.ground,base.Z+math.sin(a)*radius)
    local last=Vector3.new(base.X+math.cos(b)*radius,e.ground,base.Z+math.sin(b)*radius)
    p.Size=Vector3.new(.09,.09,(last-first).Magnitude);p.CFrame=CFrame.lookAt((first+last)/2,last)
   end
  else
   local root=target:FindFirstChild("HumanoidRootPart")
   if root and root:IsA("BasePart") then for j,p in e.nodes do local angle=j*math.pi*2/#e.nodes+now*.7
    local radius=if e.id=="BlackCoating" then 2.4 else .65
    p.Position=root.Position+Vector3.new(math.cos(angle)*radius,if e.id=="BlackCoating" then -.4 else (j%2)-.7,math.sin(angle)*radius)
   end end
  end
 end
end
return FX
