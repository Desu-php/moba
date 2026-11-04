--!strict
-- Locally authored articulated anime toad. No third-party scripts or static skin.
local A={}
local orange=Color3.fromRGB(219,104,35)
local light=Color3.fromRGB(246,145,57)
local purple=Color3.fromRGB(91,45,88)
local cream=Color3.fromRGB(238,199,134)
local dark=Color3.fromRGB(47,28,37)
local vest=Color3.fromRGB(39,49,70)
local function pivot(p:Vector3,rotation:CFrame):CFrame return CFrame.new(p)*rotation*CFrame.new(-p) end
function A.Build(model:Model,root:BasePart,adult:boolean)
 local scale=(if adult then 7 else 5)/7
 local floor=-math.max(4,root.Size.Y)/2
 local lift=floor+2.1*scale
 local function piece(name:string,size:Vector3,cf:CFrame,color:Color3,group:string,box:boolean?):Part
  local p=Instance.new("Part");p.Name=name;p.Size=size*scale;p.Color=color;p.Material=Enum.Material.SmoothPlastic
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=true
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  if not box then local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=p end
  local offset=CFrame.new(cf.Position*scale+Vector3.new(0,lift,0))*cf.Rotation
  p:SetAttribute("HeroCosmetic",true);p:SetAttribute("ToadVisual",true);p:SetAttribute("ToadGroup",group);p:SetAttribute("ToadOffset",offset)
  p.CFrame=root.CFrame*offset;p.Parent=model;return p
 end
 local function ball(name:string,size:Vector3,pos:Vector3,color:Color3,group:string):Part return piece(name,size,CFrame.new(pos),color,group) end
 local function link(name:string,a:Vector3,b:Vector3,width:number,color:Color3,group:string)
  piece(name,Vector3.new(width,width,(b-a).Magnitude+width*.35),CFrame.lookAt((a+b)/2,b),color,group)
 end
 ball("GamakichiSkin",Vector3.new(4.8,3.5,4.2),Vector3.new(0,-.1,.65),orange,"Body")
 ball("HaoriBack",Vector3.new(4.95,2.65,3.65),Vector3.new(0,.1,1.05),vest,"Body")
 ball("Belly",Vector3.new(3.8,2.8,1.25),Vector3.new(0,-.15,-1.05),cream,"Body")
 for _,side in {-1,1} do
  piece("HaoriLapel",Vector3.new(.55,2.9,.4),CFrame.new(side*1.65,.2,-1.48)*CFrame.Angles(0,0,side*-.18),vest,"Body")
  link("HaoriPiping",Vector3.new(side*1.28,1.45,-1.5),Vector3.new(side*1.75,-1.0,-1.52),.10,cream,"Body")
 end
 ball("BroadHead",Vector3.new(5.65,2.15,3.5),Vector3.new(0,1.25,-.65),orange,"Head")
 ball("LowerJaw",Vector3.new(4.9,.85,2.35),Vector3.new(0,.53,-1.18),light,"Jaw")
 ball("Chin",Vector3.new(3.65,.42,1.48),Vector3.new(0,.24,-1.22),cream,"Jaw")
 -- Curved mouth seam and distinct purple lip follow the actual muzzle surface.
 local previous:Vector3?=nil
 for i=0,32 do
  local a=-1.25+i/32*2.5
  local point=Vector3.new(math.sin(a)*2.46,.68+math.abs(a)*.07,-1.05-math.cos(a)*1.48)
  if previous then
   link("PurpleLip",previous,point,.20,purple,"Jaw")
   link("MouthSeam",previous+Vector3.new(0,.05,-.07),point+Vector3.new(0,.05,-.07),.055,dark,"Head")
  end
  previous=point
 end
 for _,side in {-1,1} do
  local label=if side<0 then "Left" else "Right"
  ball(label.."EyeMark",Vector3.new(1.65,1.25,1.55),Vector3.new(side*1.73,2.03,-1.07),purple,"Head")
  ball(label.."Eye",Vector3.new(1.13,.73,.23),Vector3.new(side*1.78,2.07,-1.91),Color3.fromRGB(239,191,61),"Head")
  ball(label.."Pupil",Vector3.new(.71,.21,.12),Vector3.new(side*1.78,2.05,-2.02),dark,"Head")
  ball(label.."EyeGlint",Vector3.new(.13,.10,.04),Vector3.new(side*1.78-.23,2.2,-2.06),Color3.fromRGB(255,243,198),"Head")
  piece(label.."Brow",Vector3.new(1.45,.40,.8),CFrame.new(side*1.72,2.32,-1.66)*CFrame.Angles(0,0,side*.12),orange,"Head")
  ball(label.."Nostril",Vector3.new(.18,.09,.07),Vector3.new(side*.54,1.42,-2.34),dark,"Head")
  for j=1,4 do
   ball(label.."CheekMark",Vector3.new(.34+j*.06,.27,.14),Vector3.new(side*(1.65+j*.19),1.54-j*.19,-1.78+j*.12),purple,"Head")
  end
  local arm=label.."Arm";local leg=label.."Leg"
  local shoulder=Vector3.new(side*2.18,.45,-.35);local elbow=Vector3.new(side*2.78,-.65,-1.02)
  local wrist=Vector3.new(side*2.55,-1.53,-2.23)
  ball(label.."Shoulder",Vector3.new(1.3,1.4,1.4),shoulder,orange,arm)
  link(label.."UpperArm",shoulder,elbow,1.0,orange,arm)
  ball(label.."Elbow",Vector3.new(.95,.9,.9),elbow,purple,arm)
  link(label.."Forearm",elbow,wrist,.77,orange,arm)
  ball(label.."Palm",Vector3.new(1.05,.40,.9),wrist,light,arm)
  for toe=-1,1 do
   local from=wrist+Vector3.new(toe*.23,-.05,-.22)
   local tip=from+Vector3.new(toe*.22,-.05,-.74+math.abs(toe)*.10)
   link(label.."Finger",from,tip,.20,light,arm)
   ball(label.."FingerTip",Vector3.new(.28,.15,.28),tip,cream,arm)
  end
  ball(label.."Haunch",Vector3.new(2.4,1.9,2.65),Vector3.new(side*2.25,-.98,1.3),orange,leg)
  piece(label.."ThighMark",Vector3.new(1.15,.20,1.8),CFrame.new(side*2.58,-.20,1.1)*CFrame.Angles(0,0,-side*.35),purple,leg)
  link(label.."Shin",Vector3.new(side*2.85,-1.25,1.6),Vector3.new(side*3.0,-1.78,.15),.67,light,leg)
  ball(label.."Foot",Vector3.new(1.05,.40,1.6),Vector3.new(side*2.9,-1.80,.15),orange,leg)
  for toe=-1,1 do
   local from=Vector3.new(side*2.9+toe*.24,-1.88,-.35)
   local tip=from+Vector3.new(toe*.23,0,-.85+math.abs(toe)*.15)
   link(label.."Toe",from,tip,.23,orange,leg)
   ball(label.."ToeTip",Vector3.new(.32,.18,.34),tip,cream,leg)
  end

 end
 if adult then
  -- The blade and hilt share the right-arm pivot, including the chopping channel.
  local grip=CFrame.new(2.55,-1.45,-2.25)*CFrame.Angles(0,-.15,-.15)
  piece("SwordGrip",Vector3.new(.27,.27,1.0),grip*CFrame.new(0,0,.35),dark,"RightArm",true)
  piece("SwordGuard",Vector3.new(.7,.13,.25),grip*CFrame.new(0,0,-.20),Color3.fromRGB(163,133,67),"RightArm",true)
  piece("SwordBlade",Vector3.new(.12,.55,3.4),grip*CFrame.new(0,0,-1.98),Color3.fromRGB(199,212,221),"RightArm",true)
  piece("SwordEdge",Vector3.new(.13,.10,3.3),grip*CFrame.new(0,-.27,-1.98),Color3.fromRGB(244,242,222),"RightArm",true)
 end
 model:SetAttribute("GamakichiVisualWidth",7*scale);model:SetAttribute("GamakichiVisualVersion",2)
 model:SetAttribute("ToadScale",scale);model:SetAttribute("ToadLift",lift)
end
function A.Motion(now:number,moving:boolean,swingAt:number,spellAt:number,spell:string,channel:boolean):CFrame
 local hop=if moving then math.max(0,math.sin(now*9)) else 0
 local age=now-swingAt
 local strike=if age>=0 and age<.65 then math.sin(age/.65*math.pi) else 0
 local cast=now-spellAt
 local oil=if spell=="GamakichiOil" and cast>=0 and cast<.6 then math.sin(cast/.6*math.pi) else 0
 return CFrame.new(0,hop*.42+math.sin(now*2)*.035,-strike*.35+oil*.18)*CFrame.Angles(-hop*.055-strike*.10+oil*.10,0,if channel then math.sin(cast*math.pi*2)*.06 else 0)
end
function A.Limb(group:string,scale:number,lift:number,now:number,moving:boolean,swingAt:number,spellAt:number,spell:string,channel:boolean):CFrame
 local hop=if moving then math.sin(now*9) else 0
 local age=now-swingAt
 local strike=if age>=0 and age<.65 then math.sin(age/.65*math.pi) else 0
 local oilAge=now-spellAt
 local oil=if spell=="GamakichiOil" and oilAge>=0 and oilAge<.65 then math.sin(oilAge/.65*math.pi) else 0
 local function joint(x:number,y:number,z:number,cf:CFrame):CFrame return pivot(Vector3.new(x*scale,y*scale+lift,z*scale),cf) end
 if group=="Head" then return joint(0,.5,-.3,CFrame.Angles(-oil*.16,0,0)) end
 if group=="Jaw" then return joint(0,.6,-.4,CFrame.Angles(oil*.32,0,0)) end
 local side=if string.find(group,"Left",1,true) then -1 else 1
 if string.find(group,"Arm",1,true) then
  local chop=if channel and side==1 then math.sin(oilAge*math.pi*2) else 0
  return joint(side*2.18,.45,-.35,CFrame.Angles(hop*.18-strike*.55-chop*.75,side*strike*.15,side*chop*.3))
 elseif string.find(group,"Leg",1,true) then return joint(side*1.7,-.6,1.1,CFrame.Angles(-hop*.25,0,side*hop*.08)) end
 return CFrame.identity
end
return A
