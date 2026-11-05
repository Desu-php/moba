--!strict
-- Presentation only: no stun, displacement of the hurtbox, or extra damage.
local Reaction={}
function Reaction.Offset(model:Model,key:string,now:number):CFrame
 local at=model:GetAttribute("PawHitAt")
 local lightningAt=model:GetAttribute("ChidoriHitAt")
 local lightning=typeof(lightningAt)=="number" and (typeof(at)~="number" or lightningAt>at)
 if lightning then at=lightningAt end
 if typeof(at)~="number" then return CFrame.identity end
 local age=now-at
 local duration=if lightning then .62 else .44
 if age<0 or age>=duration then return CFrame.identity end
 local force=if age<.07 then math.sin(age/.07*math.pi/2) else (1-(age-.07)/(duration-.07))^2
 local root=model:FindFirstChild("HumanoidRootPart")
 local direction=model:GetAttribute(if lightning then "ChidoriHitDirection" else "PawHitDirection")
 local localDir=if root and root:IsA("BasePart") and typeof(direction)=="Vector3" then root.CFrame:VectorToObjectSpace(direction) else Vector3.new(0,0,1)
 if key=="Root" or key=="RootJoint" then
  return CFrame.new(localDir.X*.55*force,-.16*force,localDir.Z*.55*force)*CFrame.Angles(localDir.Z*.32*force,0,-localDir.X*.32*force)
 elseif key=="Neck" then return CFrame.Angles(-localDir.Z*.18*force,0,localDir.X*.15*force)
 elseif key=="LeftShoulder" or key=="Left Shoulder" then return CFrame.Angles(-.28*force,0,-.3*force)
 elseif key=="RightShoulder" or key=="Right Shoulder" then return CFrame.Angles(-.28*force,0,.3*force) end
 return CFrame.identity
end
return Reaction
