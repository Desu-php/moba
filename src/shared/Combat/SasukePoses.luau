--!strict
-- Retarget the actual Creator Store R6 keyframe clips to the R15 joints.
local Data=require("../Config/SasukeVisualData")
local Factory=require("../CreatorVisualFactory")
local P={}
local mapping:{[string]:string}={Torso="Waist",Head="Neck",["Right Arm"]="RightShoulder",["Left Arm"]="LeftShoulder",["Right Leg"]="RightHip",["Left Leg"]="LeftHip"}
function P.sample(model:Model,key:string,now:number,progress:number,base:{[string]:{number}}):{[string]:{number}}
 local ready=(model:GetAttribute("ChidoriReadyAt") or 0) :: number
 local held=model:GetAttribute("ChidoriHeld")==true
 local clip:any=nil;local time=0
 if held and now<ready then clip=Data.animations[1];time=math.clamp(1-(ready-now)/.8,0,1)*2
 elseif (held or ((model:GetAttribute("ChidoriStrikeUntil") or 0) :: number)>now) and string.find(key,"Punch") then clip=Data.animations[3];time=progress*.6
 elseif held then clip=Data.animations[2];time=if key=="Run" then now%.6 else .3
 elseif string.find(key,"Punch") then clip=Data.animations[4+((tonumber(string.match(key,"%d")) or 1)-1)%3];time=progress*clip.frames[#clip.frames].time end
 if not clip then return base end
 local first,last=clip.frames[1],clip.frames[#clip.frames]
 for i=1,#clip.frames-1 do if time>=clip.frames[i].time and time<=clip.frames[i+1].time then first=clip.frames[i];last=clip.frames[i+1];break end end
 local alpha=if last.time>first.time then math.clamp((time-first.time)/(last.time-first.time),0,1) else 0
 for part,joint in mapping do
  local a,b=first.poses[part],last.poses[part]
  if a and b and not (held and key=="Idle" and (joint=="LeftHip" or joint=="RightHip")) then
   local basis=if string.find(part,"Left") then CFrame.Angles(0,-math.pi/2,0) elseif string.find(part,"Right") then CFrame.Angles(0,math.pi/2,0) else CFrame.new(0,0,0,-1,0,0,0,0,1,0,1,0)
   local rotation=Factory.Frame(a):Lerp(Factory.Frame(b),alpha).Rotation
   local x,y,z=(basis*rotation*basis:Inverse()):ToEulerAnglesXYZ();base[joint]={x,y,z}
  end
 end
 if held and key=="Idle" then
  -- R15 has separate elbows; keep the source shoulder motion, then present the charge beside the hip.
  base.LeftShoulder={.45,-.15,-.3};base.LeftElbow={.55,0,0}
 end
 return base
end
return P
