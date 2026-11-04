--!strict
-- Opt-in Studio QA: insert this Script during solo Play with player controls disabled.
if not game:GetService("RunService"):IsStudio() or workspace:GetAttribute("RunFormsCollisionQA")~=true then return end
local Players=game:GetService("Players")
local S=game.ServerScriptService.Server.Services
local Factory=require(S.MinionFactory)
local Config=require(game.ReplicatedStorage.Shared.Config.MinionConfig)
local checks={}
local function check(ok: boolean,message: string) assert(ok,message);table.insert(checks,message) end
local player=Players:GetPlayers()[1];assert(player and player.Character)
local model=player.Character;local root=model:FindFirstChild("HumanoidRootPart") :: BasePart
local humanoid=model:FindFirstChildOfClass("Humanoid");assert(humanoid)
local saved=root.CFrame
local folder=Instance.new("Folder");folder.Name="FormsCollisionQA";folder.Parent=workspace
local function run()
 local physics=game:GetService("PhysicsService")
 check(physics:CollisionGroupsAreCollidable("SurvivalHeroes","SurvivalMinions"),"heroes collide with minions")
 local floor=Instance.new("Part");floor.Size=Vector3.new(80,1,80);floor.Anchored=true;floor.Position=Vector3.new(0,149,0);floor.Parent=folder
 root:SetNetworkOwner(nil);humanoid.AutoRotate=false
 for _,team in {"Blue","Red"} do
  for _,kind in {"Melee","Ranged"} do
   local creep=Factory.Create(kind,team,Color3.new(1,1,1),Vector3.new(0,152,0),Config.Types[kind]);creep.Parent=folder
   local creepRoot=creep.PrimaryPart :: BasePart;creepRoot.Anchored=true
   root.CFrame=CFrame.new(-5,153,0);root.AssemblyLinearVelocity=Vector3.zero
   humanoid:MoveTo(Vector3.new(7,153,0));task.wait(1.3)
   check(root.Position.X<-.8 and root.Position.X> -4,"body block "..team.." "..kind)
   creep:Destroy()
  end
 end
 humanoid:MoveTo(root.Position);root.CFrame=saved;root.AssemblyLinearVelocity=Vector3.zero;root:SetNetworkOwnershipAuto()
 -- Use an isolated cosmetic rig so authoritative Sage publication cannot overwrite test attributes.
 model.Archivable=true
 local model=model:Clone();model.Name="AppearanceLifecycleQA"
 for _,item in model:GetDescendants() do
  if item:IsA("LuaSourceContainer") then item:Destroy() elseif item:IsA("BasePart") then item.Anchored=true end
 end
 model.Parent=folder;model:SetAttribute("HeroAppearanceVersion",nil)
 require(S.HeroAppearanceService).Apply(model)
 local root=model:FindFirstChild("HumanoidRootPart") :: BasePart
 local originalSize=root.Size
 for _,form in {"Normal","Sage","KCM","Rikudo","Kurama","Normal"} do
  model:SetAttribute("SagePhase",if form=="Sage" then "Active" else "Idle")
  model:SetAttribute("KcmRank",if form=="Rikudo" then 3 else 1)
  model:SetAttribute("KcmActive",form=="KCM" or form=="Rikudo")
  model:SetAttribute("KuramaActive",form=="Kurama");task.wait(.15)
  check(model:GetAttribute("HeroVisualForm")==form,"appearance selected "..form)
  local appearances=0
  for _,c in model:GetChildren() do if c.Name=="HeroAppearance" then appearances+=1 end end
  check(appearances==1,"one costume "..form)
  local costume=model:FindFirstChild("HeroAppearance");assert(costume)
  for _,p in costume:GetDescendants() do
   if p:IsA("BasePart") then check(not p.CanCollide and not p.CanTouch and not p.CanQuery and p.Massless,"cosmetic physics "..p.Name) end
   assert(not p:IsA("LuaSourceContainer"),"imported script in cosmetic")
  end
  check(root.Size==originalSize and root.CollisionGroup=="SurvivalHeroes","rig retained "..form)
 end
 check((model:FindFirstChild("UpperTorso") :: BasePart).Transparency==0,"normal body restored")
end
local ok,message=pcall(run)
humanoid:MoveTo(root.Position);root.CFrame=saved;root.AssemblyLinearVelocity=Vector3.zero;root:SetNetworkOwnershipAuto();folder:Destroy()
workspace:SetAttribute("FormsCollisionQA",game:GetService("HttpService"):JSONEncode({ok=ok,count=#checks,checks=checks,error=if ok then nil else tostring(message)}))
assert(ok,tostring(message));print("PASS form/collision QA: "..#checks.." checks")
