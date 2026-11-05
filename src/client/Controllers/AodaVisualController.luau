--!strict
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Clips:{[string]:{duration:number,frames:{{[string]:CFrame}}}}=require(Shared.AodaClips) :: any
local Reaction=require(Shared.Combat.HitReaction)
local M={};local started=false
local cached:{[Model]:{skin:MeshPart,bones:{Bone},phase:number}}=setmetatable({},{__mode="k"}) :: any
function M.Start()
 if started then return end;started=true
 Run.RenderStepped:Connect(function(dt)
  local folder=workspace:FindFirstChild("HeroSummons");if not folder then return end
  local now=workspace:GetServerTimeNow()
  for _,model in folder:GetChildren() do
   if not model:IsA("Model") or model:GetAttribute("NativeAoda")~=true then continue end
   local root=model:FindFirstChild("HumanoidRootPart")
   if not root or not root:IsA("BasePart") then continue end
   local rec=cached[model]
   if not rec then
    local skin=model:FindFirstChild("AodaSkin")
    if not skin or not skin:IsA("MeshPart") then continue end
    local bones:{Bone}={}
    for _,b in skin:GetDescendants() do if b:IsA("Bone") then table.insert(bones,b) end end
    rec={skin=skin,bones=bones,phase=0};cached[model]=rec
   end
   local controlled=math.max((model:GetAttribute("CombatStunUntil") or 0) :: number,(model:GetAttribute("SleepUntil") or 0) :: number)>now
   local moving=model:GetAttribute("SummonMoving")==true and not controlled
   local strike=now-((model:GetAttribute("AodaStrikeAt") or -100) :: number)
   local coiling=((model:GetAttribute("AodaConstrictUntil") or 0) :: number)>now and not controlled
   local clip=if moving then Clips.Slither else Clips.Idle
   rec.phase=(rec.phase+dt/(if moving then Clips.Slither.duration else Clips.Idle.duration))%1
   local age=rec.phase*clip.duration
   if coiling then clip=Clips.Coil;age=now%clip.duration
   elseif not controlled and strike>=0 and strike<Clips.Bite.duration then clip=Clips.Bite;age=strike end
   local frame=math.clamp(age/clip.duration*(#clip.frames-1),0,#clip.frames-1)
   local a=math.floor(frame)+1;local b=math.min(a+1,#clip.frames)
   local scale=(model:GetAttribute("AodaScale") or 1) :: number
   local alpha=1-math.exp(-(if coiling then 14 else 30)*dt)
   for _,bone in rec.bones do
    local one=clip.frames[a][bone.Name];local two=clip.frames[b][bone.Name]
    if one and two then
     local goal=one:Lerp(two,frame%1)
     -- Blender spine Y is the snake's length axis. Match the lunge to its victim.
     if clip==Clips.Bite and (bone.Name=="Head" or string.sub(bone.Name,1,5)=="Spine") then
      local distance=(model:GetAttribute("AodaStrikeDistance") or (11.4*scale)) :: number
      local reach=math.clamp((distance/scale-3.4)/8,.12,2.1)
      goal=CFrame.new(goal.Position*Vector3.new(1,reach,1))*goal.Rotation
     end
     goal=CFrame.new(goal.Position*scale)*goal.Rotation
     bone.Transform=bone.Transform:Lerp(goal,alpha)
    end
   end
   rec.skin.CFrame=root.CFrame*Reaction.Offset(model,"Root",now)*(rec.skin:GetAttribute("AodaOffset") :: CFrame)
  end
 end)
end
return M
