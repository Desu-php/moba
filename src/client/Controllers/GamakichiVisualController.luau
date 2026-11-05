--!strict
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Clips:{[string]:{duration:number,frames:{{[string]:CFrame}}}}=require(Shared.GamakichiClips) :: any
local Reaction=require(Shared.Combat.HitReaction)
local M={};local started=false
local cached: {[Model]:{skin:MeshPart,bones:{Bone}}}=setmetatable({},{__mode="k"}) :: any
function M.Start()
 if started then return end;started=true
 Run.RenderStepped:Connect(function(dt)
  local folder=workspace:FindFirstChild("HeroSummons");if not folder then return end
  local now=workspace:GetServerTimeNow()
  for _,model in folder:GetChildren() do
   if not model:IsA("Model") or model:GetAttribute("NativeGamakichi")~=true then continue end
   local root=model:FindFirstChild("HumanoidRootPart")
   if not root or not root:IsA("BasePart") then continue end
   local rec=cached[model]
   if not rec then
    local skin=model:FindFirstChild("GamakichiSkin")
    if not skin or not skin:IsA("MeshPart") then continue end
    local bones:{Bone}={}
    for _,b in skin:GetDescendants() do if b:IsA("Bone") then table.insert(bones,b) end end
    rec={skin=skin,bones=bones};cached[model]=rec
   end
   local swing=now-((model:GetAttribute("SummonSwingAt") or -100) :: number)
   local cast=now-((model:GetAttribute("SummonSpellAt") or -100) :: number)
   local channel=model:GetAttribute("Channeling")==true
   local moving=model:GetAttribute("SummonMoving")==true
   local clip=if moving then Clips.Walk else Clips.Idle
   local age=now%clip.duration
   if model:GetAttribute("SummonSpell")=="GamakichiOil" and cast>=0 and cast<Clips.Oil.duration then clip=Clips.Oil;age=cast
   elseif channel then clip=Clips.Attack;age=cast%clip.duration
   elseif swing>=0 and swing<Clips.Attack.duration then clip=Clips.Attack;age=swing end
   local frame=math.clamp(age/clip.duration*(#clip.frames-1),0,#clip.frames-1)
   local a=math.floor(frame)+1;local b=math.min(a+1,#clip.frames)
   local scale=(model:GetAttribute("ToadScale") or 1) :: number
   for _,bone in rec.bones do
    local one=clip.frames[a][bone.Name];local two=clip.frames[b][bone.Name]
    if one and two then
     local goal=one:Lerp(two,frame%1)
     goal=CFrame.new(goal.Position*scale)*goal.Rotation
     bone.Transform=bone.Transform:Lerp(goal,1-math.exp(-35*dt))
    end
   end
   rec.skin.CFrame=root.CFrame*Reaction.Offset(model,"Root",now)*(rec.skin:GetAttribute("ToadOffset") :: CFrame)
  end
 end)
end
return M
