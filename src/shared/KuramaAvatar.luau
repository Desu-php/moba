--!strict
-- Articulate the whitelisted Creator Store fox meshes; no marketplace scripts or animations run.
local Config=require(script.Parent.Config.KuramaAvatarConfig)
local Avatar={}
local function smooth(t:number):number t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function pivot(point:Vector3,rotation:CFrame):CFrame return CFrame.new(point)*rotation*CFrame.new(-point) end
local function point(x:number,y:number,z:number):Vector3 return Vector3.new(x*Config.Scale,y*Config.Scale+Config.Lift,z*Config.Scale) end
function Avatar.Offset(base:CFrame):CFrame return CFrame.new(base.Position*Config.Scale+Vector3.new(0,Config.Lift,0))*base.Rotation end
function Avatar.Style(part:BasePart,mesh:SpecialMesh)
 part.Size*=Config.Scale;mesh.Scale*=Config.Scale;mesh.Offset*=Config.Scale
 -- The complete transformation is a luminous chakra avatar, with dark markings.
 mesh.TextureId="";part.Color=Color3.fromRGB(255,218,92);part.Material=Enum.Material.Neon
 part.Transparency=.08
 if string.find(part.Name,"eyes",1,true) then part.Color=Color3.fromRGB(255,70,12);part.Transparency=0 end
end
function Avatar.Motion(name:string,base:CFrame,now:number,moving:number,phase:number?,serial:number):CFrame
 local wind,hit,follow=0,0,0
 if phase then
  if phase<Config.SwipeStart then wind=smooth(phase/Config.SwipeStart)
  elseif phase<Config.SwipeEnd then
   local f=smooth((phase-Config.SwipeStart)/(Config.SwipeEnd-Config.SwipeStart));wind=1-f;hit=f
  else follow=1-smooth((phase-Config.SwipeEnd)/(1-Config.SwipeEnd));hit=follow end
 end
 local side=if serial%2==0 then -1 else 1
 local body=CFrame.new(side*hit*.35,math.sin(now*1.8)*.08-moving*.08-wind*.35,-hit*1.5)
  *CFrame.Angles(wind*.055,-side*wind*.16+side*hit*.12,side*wind*.04)
 local tail=tonumber(string.match(name,"Tail(%d+)$"))
 if tail then
  local sway=math.sin(now*1.1+tail*.62)*.10+math.sin(now*2.2+tail)*.025
  return body*pivot(point(0,.7,2.5),CFrame.Angles(math.sin(now*.9+tail)*.045, sway+side*wind*.07,math.sin(now*.7+tail)*.035))*base
 end
 if string.find(name,"hea",1,true) or string.find(name,"eyes",1,true) or string.find(name,"FaceMark",1,true) then
  return body*pivot(point(0,.5,-1.45),CFrame.Angles(-wind*.12+hit*.08,side*wind*.08,0))*base
 end
 local limbSide=if string.find(name,"Left",1,true) then -1 elseif string.find(name,"Right",1,true) then 1 else 0
 if limbSide~=0 then
  local hind=string.find(name,"Leg",1,true)~=nil
  local stride=math.sin(now*5.5+(if limbSide<0 then math.pi else 0)+(if hind then math.pi else 0))*moving
  local joint=if hind then point(limbSide*.8,0,1.7) else point(limbSide*1.1,-.15,-1.35)
  local pose=CFrame.Angles(stride*.18,0,0)
  if not hind and limbSide==side and phase then
   -- Lift the paw outside the shoulder, sweep low across the front, then recover.
   -- This exact motion also supplies the server contact volume.
   pose=CFrame.Angles(wind*.72+hit*.08,-side*wind*.70+side*hit*1.10,side*wind*.24-side*hit*.08)
  elseif not hind and phase then pose=CFrame.Angles(-wind*.08,0,0) end
  return body*pivot(joint,pose)*base
 end
 return body*base
end
function Avatar.Markings(folder:Folder,root:BasePart)
 local function mark(name:string,cf:CFrame,size:Vector3,ball:boolean?)
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=root.CFrame*cf;p.Color=Color3.fromRGB(35,20,10)
  p.Material=Enum.Material.SmoothPlastic;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.CastShadow=false
  if ball then p.Shape=Enum.PartType.Ball end
  p:SetAttribute("HeroCosmetic",true);p:SetAttribute("CosmeticBody","HumanoidRootPart");p:SetAttribute("CosmeticOffset",cf);p.Parent=folder
  local w=Instance.new("Weld");w.Name="FormVisualWeld";w.Part0=root;w.Part1=p;w.C0=cf;w.Parent=p
 end
 -- Collar tomoe and whisker markings remain attached to the corresponding animated mesh group.
 for i=1,6 do
  local angle=(i-3.5)*.29
  mark("KuramaCollar"..i,CFrame.new(math.sin(angle)*3.7,Config.Lift+.1-math.cos(angle)*1.8,-8.6),Vector3.new(.65,.9,.22),true)
 end
 for _,side in {-1,1} do for i=1,3 do
  local cf=CFrame.new(side*(3.25+i*.13),Config.Lift+1.0-i*.55,-11.55+i*.35)*CFrame.Angles(0,side*.3,side*-.12)
  mark("KuramaFaceMark"..side.."_"..i,cf,Vector3.new(2.0,.18,.18))
 end end
end
return Avatar
