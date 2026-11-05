--!nocheck
-- Optional Studio storyboard. Replace the QA runner with this file for visual review only.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Match=require(S.MatchService);local Ability=require(S.AbilityService);local Sasuke=require(S.SasukeAbilityService)
local Dev=require(S.DeveloperCommandService)
repeat task.wait(.1) until Match.GetState() and Match.GetState().phase=="InProgress"
local player=game.Players:GetPlayers()[1]
player:SetAttribute("HeroId","Sasuke");player:LoadCharacterAsync()
repeat task.wait(.1) until player.Character and player.Character:GetAttribute("HeroAppearanceVersion") and string.find(player.Character:GetAttribute("HeroAppearanceVersion"),"Sasuke")
Match.GetState().nextWaveAt=workspace:GetServerTimeNow()+10000
require(S.MinionAIService).Reset();require(S.JungleService).Stop();require(game.ReplicatedStorage.Shared.Config.TowerConfig).Range=0
local c=player.Character;local root=c.HumanoidRootPart
root:SetNetworkOwner(nil);root.CFrame=CFrame.new(-275,36,0)
Dev.Execute(player,"level 30");Dev.Execute(player,"learnall");Dev.Execute(player,"nocd on");Dev.Execute(player,"refresh")
local id=5000
local function cast(spell,point) task.wait(.4);id+=1;if point then return Ability.TryCast(player,id,c,spell,point) else return Ability.TryCast(player,id,c,spell) end end
local function eyes() if (c:GetAttribute("SasukeMode") or 0)==0 then cast("Sharingan") end;if (c:GetAttribute("SasukeMode") or 0)<2 then cast("Mangekyo") end end
workspace:SetAttribute("SasukeReviewReady",true)
local last=""
while c.Parent and c.Humanoid.Health>0 do
 local scene=workspace:GetAttribute("SasukeReviewScene") or ""
 if scene~=last then
  last=scene;Dev.Execute(player,"refresh")
  local point=root.Position+Vector3.new(0,0,-20)
  if scene=="Flames" then eyes();cast("Amaterasu",point)
  elseif scene=="Susanoo" then eyes();cast("CompleteSusanoo");task.wait(3.3)
  elseif scene=="KirinStoryboard" then
   -- Only visual time is slowed; real damage/delay were verified by Runner.server.
   local now=workspace:GetServerTimeNow();c:SetAttribute("SasukeCastPose","Kirin");c:SetAttribute("SasukeCastPoseAt",now);c:SetAttribute("SasukeCastPoseUntil",now+10)
   Sasuke.Visual:Fire({kind="Sasuke",id="KirinWarning",character=c,position=point,radius=550/16,duration=10,at=now})
   task.delay(10,function() Sasuke.Visual:Fire({kind="Sasuke",id="Kirin",character=c,position=point,radius=550/16,duration=3,at=workspace:GetServerTimeNow()}) end)
  elseif scene=="Fireball" then cast("SasukeFireball",point+Vector3.new(0,0,-25))
  elseif scene=="Lightning" then cast("ChidoriKatana");cast("ChidoriNagashi")
  end
 end
 task.wait(.1)
end
