--!strict
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Appearance=require(Shared.GamakichiAppearance)
local Reaction=require(Shared.Combat.HitReaction)
local M={};local started=false
function M.Start()
 if started then return end;started=true
 Run.RenderStepped:Connect(function()
  local folder=workspace:FindFirstChild("HeroSummons");if not folder then return end
  local now=workspace:GetServerTimeNow()
  for _,model in folder:GetChildren() do
   if not model:IsA("Model") or model:GetAttribute("NativeGamakichi")~=true then continue end
   local root=model:FindFirstChild("HumanoidRootPart")
   if not root or not root:IsA("BasePart") then continue end
   local moving=model:GetAttribute("SummonMoving")==true
   local swing=(model:GetAttribute("SummonSwingAt") or -100) :: number
   local at=(model:GetAttribute("SummonSpellAt") or -100) :: number
   local spell=tostring(model:GetAttribute("SummonSpell"));local channel=model:GetAttribute("Channeling")==true
   local pose=Appearance.Motion(now,moving,swing,at,spell,channel)*Reaction.Offset(model,"Root",now)
   local scale=(model:GetAttribute("ToadScale") or 1) :: number;local lift=(model:GetAttribute("ToadLift") or 0) :: number
   for _,part in model:GetChildren() do
    if part:IsA("BasePart") and part:GetAttribute("ToadVisual")==true then
     local limb=Appearance.Limb(tostring(part:GetAttribute("ToadGroup")),scale,lift,now,moving,swing,at,spell,channel)
     part.CFrame=root.CFrame*pose*limb*(part:GetAttribute("ToadOffset") :: CFrame)
    end
   end
  end
 end)
end
return M
