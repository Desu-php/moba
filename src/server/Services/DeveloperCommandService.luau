--!strict
-- Studio-only command boundary. No arbitrary code, player targets, or live-server access.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Shared=RS:WaitForChild("Shared")
local Parser=require(Shared.Game.DeveloperCommandRules)
local Progression=require(script.Parent.HeroProgressionService)
local Rules=require(Shared.Game.ProgressionRules).configure(require(Shared.Config.ProgressionConfig),require(Shared.Config.ItemConfig).Items)
local Learning=require(Shared.Abilities.SkillLearning)
local Naruto=require(script.Parent.NarutoAbilityService)
local Kcm=require(script.Parent.NarutoKcmService)
local Kurama=require(script.Parent.NarutoKuramaService)
local Ranged=require(script.Parent.NarutoRangedService)
local Gama=require(script.Parent.GamakichiService)
local Service={}
local noCooldown: {[Player]: boolean}={}
local requests: {[Player]: number}={}
local started=false
local help="level 30 — уровень • learnall — изучить навыки\nnocd on / nocd off — убрать / вернуть КД\nrefresh — восстановить HP, чакру и КД\nsolo — начать тест одному • help — команды"
local function cooldowns(player: Player)
 local s=Naruto.Get(player)
 if s then
  s.q.cooldownAt=0;s.clones.cooldownAt=0;s.sage.cooldownAt=0;s.gama.cooldownAt=0;s.meditationRecallAt=0
  table.clear(s.variants.cooldowns);s.nextPublish=0
 end
 local toad=Gama.Get(player);if toad then toad.spells.oilReady=0;toad.spells.chopReady=0 end
 local ranged=Ranged.Inspect(player);if ranged then table.clear(ranged.cooldowns) end
 Kcm.StudioResetCooldowns(player);Kurama.StudioResetCooldowns(player)
 local model=player.Character
 if model then for name in model:GetAttributes() do if string.sub(name,1,6)=="Ready_" then model:SetAttribute(name,0) end end end
end
function Service.Execute(player: Player,raw: any): (boolean,string)
 if not RunService:IsStudio() or player.Parent~=Players then return false,"Команды доступны только в Studio." end
 local command=Parser.parse(raw);if not command then return false,"Неизвестная команда. Введите help." end
 if command.name=="help" then return true,help end
 if command.name=="solo" then
  local match=require(script.Parent.MatchService).GetState()
  if not match or match.phase=="Finished" then return false,"Перезапустите Play для нового матча." end
  workspace:SetAttribute("DeveloperSoloMode",true)
  return true,"Одиночный тест включён. Матч начнётся после подготовки."
 end
 local profile=Progression.Get(player);local s=Naruto.Get(player)
 if not profile or not s then return false,"Дождитесь появления героя." end
 if command.name=="level" then
  local target=command.level :: number
  if target<profile.Level then return false,"Команда повышает уровень. Для сброса перезапустите Play." end
  local xp=-profile.CurrentXP
  for level=profile.Level,target-1 do xp+=Rules.required(level) end
  local gained=Rules.addXP(profile,math.max(0,xp))
  local match=require(script.Parent.TeamService).GetState()
  Progression.Publish(player);Progression.Changed:Fire(player,"XP",gained,if match then match.roundId else nil)
  return true,"Уровень: "..profile.Level..". Очки навыков: "..profile.SkillPoints.."."
 elseif command.name=="learnall" then
  for _,id in Learning.Order do while Learning.reason(profile,id)==nil do Learning.learn(profile,id) end end
  Progression.Publish(player)
  return true,"Изучены все навыки, доступные на текущем уровне."
 elseif command.name=="nocd" then
  noCooldown[player]=command.enabled==true;player:SetAttribute("DeveloperNoCooldown",command.enabled)
  if command.enabled then cooldowns(player) end
  return true,if command.enabled then "КД отключены. Подготовка и условия техник сохраняются." else "Обычные КД включены для следующих применений."
 elseif command.name=="refresh" then
  cooldowns(player);s.pool.mana=s.pool.maximum
  local humanoid=if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
  if humanoid and humanoid.Health>0 then humanoid.Health=humanoid.MaxHealth end
  return true,"HP, чакра и перезарядки восстановлены."
 end
 return false,"Неизвестная команда."
end
function Service.Start()
 if started or not RunService:IsStudio() then return end;started=true
 local remote=Instance.new("RemoteEvent");remote.Name="DeveloperCommand";remote.Parent=RS
 remote.OnServerEvent:Connect(function(player,raw,...)
  if not RunService:IsStudio() or select("#",...)~=0 then return end
  local now=os.clock();if now<(requests[player] or 0) then return end;requests[player]=now+.15
  local ok,message=Service.Execute(player,raw);remote:FireClient(player,ok,message)
 end)
 RunService.Heartbeat:Connect(function()
  for player,enabled in noCooldown do if enabled and player.Parent==Players then cooldowns(player) end end
 end)
 Players.PlayerRemoving:Connect(function(player) noCooldown[player]=nil;requests[player]=nil end)
end
return Service
