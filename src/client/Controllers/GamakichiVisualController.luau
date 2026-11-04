--!strict
local Run=game:GetService("RunService")
local Appearance=require(game.ReplicatedStorage.Shared.GamakichiAppearance)
local M={};local started=false
function M.Start()
 if started then return end;started=true
 Run.RenderStepped:Connect(function()
  local folder=workspace:FindFirstChild("HeroSummons");if not folder then return end
  local now=workspace:GetServerTimeNow()
  for _,model in folder:GetChildren() do
   if not model:IsA("Model") or model:GetAttribute("NativeGamakichi")~=true then continue end
   local root=model:FindFirstChild("HumanoidRootPart");local skin=model:FindFirstChild("GamakichiSkin")
   if not root or not root:IsA("BasePart") or not skin or not skin:IsA("BasePart") then continue end
   local pose=Appearance.Motion(now,model:GetAttribute("SummonMoving")==true,
    (model:GetAttribute("SummonSwingAt") or -100) :: number,(model:GetAttribute("SummonSpellAt") or -100) :: number,
    tostring(model:GetAttribute("SummonSpell")),model:GetAttribute("Channeling")==true)
   skin.CFrame=root.CFrame*(skin:GetAttribute("ToadOffset") :: CFrame)*pose
   for _,blade in model:GetChildren() do
    if blade:IsA("BasePart") and blade:GetAttribute("ToadSword")==true then
     local at=(model:GetAttribute("SummonSpellAt") or now) :: number
     local angle=if model:GetAttribute("Channeling")==true then math.sin((now-at)*math.pi*2)*1.3 else .3
     blade.CFrame=root.CFrame*pose*(blade:GetAttribute("ToadGrip") :: CFrame)*CFrame.Angles(0,angle,0)*(blade:GetAttribute("ToadOffset") :: CFrame)
    end
   end
  end
 end)
end
return M
