--!strict
local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local Avatar=require(Shared.KuramaAvatar)
local Config=require(Shared.Config.KuramaAvatarConfig)
local Data=require(Shared.Config.NarutoFormVisualData)
local Factory=require(Shared.CreatorVisualFactory)
local Damage=require(script.Parent.DamageService)
local Visibility=require(script.Parent.AbilityTargetService)
local Hitboxes=require(script.Parent.HitboxService)
local M={}
local limbs:{Factory.Spec}={}
for _,spec in Data.Kurama do
 if string.find(spec.name,"Hand",1,true) or string.find(spec.name,"LowerArm",1,true) then table.insert(limbs,spec) end
end
local function humanoid(part:BasePart):Humanoid?
 if part:GetAttribute("HeroCosmetic")==true or part:GetAttribute("StructureCosmetic")==true or part:FindFirstAncestorWhichIsA("Accessory") or part:FindFirstAncestorWhichIsA("Tool") then return nil end
 local p:Instance?=part.Parent
 while p and p~=workspace do
  if p:IsA("Model") then local h=p:FindFirstChildOfClass("Humanoid");if h then return h end end;p=p.Parent
 end
 return nil
end
function M.Targets(attacker:Model,origin:CFrame,previous:CFrame,fromPhase:number,toPhase:number,serial:number,now:number):{Humanoid}
 local result:{Humanoid}={};local seen:{[Humanoid]:boolean}={}
 if not Hitboxes.IsFiniteCFrame(origin) then return result end
 local first=math.max(Config.SwipeStart,fromPhase);local last=math.min(Config.SwipeEnd,toPhase)
 if first>last or toPhase<Config.SwipeStart or fromPhase>Config.SwipeEnd then return result end
 -- Do not turn a teleport into a damaging trail across the map.
 if (origin.Position-previous.Position).Magnitude>8 then previous=origin end
 local count=math.clamp(math.ceil((last-first)/.012+(origin.Position-previous.Position).Magnitude/.5),1,48)
 local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.FilterDescendantsInstances={attacker}
 local side=if serial%2==0 then "Left" else "Right"
 for i=0,count do
  local t=i/count;local phase=first+(last-first)*t;local root=previous:Lerp(origin,t)
  for _,spec in limbs do
   if not string.find(spec.name,side,1,true) then continue end
   local box=root*Avatar.Motion(spec.name,Avatar.Offset(Factory.Frame(spec.cf)),now,0,phase,serial)
   local size=Factory.Vector(spec.size)*Config.Scale
   for _,part in workspace:GetPartBoundsInBox(box,size,overlap) do
    local h=humanoid(part);if not h or seen[h] then continue end
    local model=h.Parent
    if not model or not model:IsA("Model") or model==attacker or h.Health<=0 or not Damage.CanDamage(attacker,model) or model:FindFirstChildOfClass("ForceField") then continue end
    local target=model:FindFirstChild("HumanoidRootPart")
    if target and target:IsA("BasePart") and Visibility.Visible(attacker,model,origin.Position,target.Position) then seen[h]=true;table.insert(result,h) end
   end
  end
 end
 return result
end
return M
