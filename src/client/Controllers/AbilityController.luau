--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local Gui = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.AbilityConfig)
local Sasuke=require(Shared.Abilities.SasukeDefinitions)
local SasukeRules=require(Shared.Abilities.SasukeRules)
local VFX = require(script.Parent.AbilityVFXController)
local Rounds = require(script.Parent.RoundController)
local Gama=require(Shared.Abilities.GamakichiState)
local Targeting=require(script.Parent.AbilityTargeting)
local Feedback=require(script.Parent.VFXController)
local quickKey: Enum.KeyCode? = nil
local UpgradeQueue=require(Shared.Abilities.RasenganUpgradeQueue)
local upgrades: UpgradeQueue.State? = nil
local upgradeCharacter: Model? = nil
local pendingAbility: string? = nil
local function clearUpgrades()
 if upgrades then UpgradeQueue.clear(upgrades) end
 upgrades=nil; upgradeCharacter=nil
end
local Controller = { Changed = Instance.new("BindableEvent") }
local remote: RemoteEvent? = nil
local serial, pendingId, pendingAt = 0, 0, 0
local corrections: { [string]: number } = {}
local correctionModel: Model? = nil
-- Corrections bridge replication latency; replicated deadlines remain authoritative after that window.
local correctionUntil = 0
local lastReason = ""
local selectingCommand: string? = nil
local needsTarget = Targeting.IsTargeted
function Controller.CancelCloneCommand()
	selectingCommand = nil; quickKey = nil; Targeting.Clear(); Players.LocalPlayer:SetAttribute("SelectingCloneTarget", nil); lastReason = ""
end
function Controller.SelectedAbility(): string? return selectingCommand end
function Controller.GetUpgradeQueue(): {string} return if upgrades then table.clone(upgrades.items) else {} end
function Controller.GetQueuedUpgrade(id: string): boolean
 local queue=upgrades
 return queue~=nil and not queue.closed and (queue.awaiting==id or table.find(queue.items,id)~=nil)
end
function Controller.IsSelectingCloneTarget(): boolean return selectingCommand~=nil end
function Controller.ClearCooldownCorrections()
 if not RunService:IsStudio() then return end
 corrections={};correctionUntil=0;Controller.Changed:Fire()
end
local function sasukeContinuation(id:string):boolean
 local m=Players.LocalPlayer.Character;if not m or m:GetAttribute("HeroId")~="Sasuke" then return false end
 return (id=="Garuda" and m:GetAttribute("GarudaActive")==true) or (id=="Sharingan" and ((m:GetAttribute("SasukeMode") or 0) :: number)>0) or (id=="SusanooRibs" and m:GetAttribute("SusanooForm")==1) or (id=="Amenotejikara" and ((m:GetAttribute("AmenotejikaraSelectingUntil") or 0) :: number)>workspace:GetServerTimeNow())
end
function Controller.Remaining(id: string): number
 if sasukeContinuation(id) then return 0 end
 if Sasuke.Spells[id] then id=Sasuke.cooldownKey(id) end
 if id=="ShadowSleep" then id="ShadowClones" elseif id=="MeditationCast" then id="SageMode" end
	if RunService:IsStudio() and Players.LocalPlayer:GetAttribute("DeveloperNoCooldown")==true then return 0 end
	local model = Players.LocalPlayer.Character; if not model then return 0 end
	local deadline = model:GetAttribute("Ready_" .. id)
	return math.max(0, math.max(if typeof(deadline) == "number" then deadline else 0,
		if correctionModel == model and workspace:GetServerTimeNow() < correctionUntil then corrections[id] or 0 else 0) - workspace:GetServerTimeNow())
end
function Controller.Unavailable(summonOrder: boolean?): string?
	local player = Players.LocalPlayer; local model = player.Character
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if not model or not humanoid or humanoid.Health <= 0 or model:GetAttribute("CombatDisabled") == true or player:GetAttribute("Eliminated") == true then return "Недоступно" end
	if player:GetAttribute("HeroSelectionOpen")==true then return "Выберите героя" end
	if player:GetAttribute("ShopOpen") == true then return "Закройте магазин" end
	if Input:GetFocusedTextBox() then return "Ввод текста" end
	-- Alt only exposes the cursor for HUD buttons and mouse targeting.
	if Gui.MenuIsOpen or player:GetAttribute("StatsOpen")==true or player:GetAttribute("DeveloperConsoleOpen")==true then return "Закройте меню" end
	local match = ReplicatedStorage:FindFirstChild("SurvivalState")
	if not match or match:GetAttribute("Phase") ~= "InProgress" then return "Ожидание матча" end
	if ((model:GetAttribute("SleepUntil") or 0) :: number)>workspace:GetServerTimeNow() then return "Sleep" end
	if not summonOrder and model:GetAttribute("CombatState") == "Stunned" then return "Контроль" end
	if not summonOrder and model:GetAttribute("AbilityId") ~= "" and model:GetAttribute("AbilityId") ~= nil then return "Подготовка" end
	local nextM1 = model:GetAttribute("CombatNextAttackAt")
	if not summonOrder and typeof(nextM1) == "number" and nextM1 > workspace:GetServerTimeNow() then return "Восстановление" end
	if pendingId > 0 and workspace:GetServerTimeNow() - pendingAt < 1.5 then return "Ожидание ответа" end
	return nil
end
function Controller.Cost(id: string): number
 if sasukeContinuation(id) then return 0 end
 if Sasuke.Spells[id] then local state=Players.LocalPlayer:FindFirstChild("HeroState");return Sasuke.cost(id,if state then (state:GetAttribute("Rank_"..Sasuke.Spells[id].line) or 0) :: number else 0) end
 if id=="MeditationCast" then id="SageMode" end
 local state=Players.LocalPlayer:FindFirstChild("HeroState")
 return if id=="RikudoHY" or id=="RikudoHZ" then 1800 elseif id=="KcmDash" then 100 elseif id=="Odama" or id=="Rasenshuriken" or id=="ShadowSleep" then 200 elseif id=="SageMode" then 25 elseif id == "Rasengan" then 100 elseif id == "ShadowClones" then 200 elseif id=="Gamakichi" then Gama.rank(if state then (state:GetAttribute("Rank_Gamakichi") or 0) :: number else 0) or 0 else 0
end
function Controller.AbilityUnavailable(id: string): string?
 if Sasuke.Spells[id] then
  local common=Controller.Unavailable(id=="SasukeModeOff");if common then return common end
  local player=Players.LocalPlayer;local m=player.Character;local state=player:FindFirstChild("HeroState")
  if player:GetAttribute("HeroId")~="Sasuke" or not m or not state then return "Другой герой" end
  local function n(key:string):number return (m:GetAttribute(key) or 0) :: number end
  local reason=SasukeRules.reason(id,{rank=(state:GetAttribute("Rank_"..Sasuke.Spells[id].line) or 0) :: number,mode=n("SasukeMode"),held=m:GetAttribute("ChidoriHeld")==true,readyAt=n("ChidoriReadyAt"),now=workspace:GetServerTimeNow(),form=n("SusanooForm"),kirinAt=n("KirinReadyAt"),kirinUntil=n("KirinUntil"),spheres=n("ChibakuCount"),beasts=n("SasukeBijuu"),garuda=m:GetAttribute("GarudaActive")==true})
  if reason then return reason end
  if id=="ChakraAbsorb" then return "На поле пока нет источников чакры хвостатых" end
  if n("Mana")<Controller.Cost(id) and id~="SasukeModeOff" then return "Недостаточно чакры" end
  return nil
 end
 if id=="MeditationCast" then return Controller.AbilityUnavailable("SageMode") end
	if not (Config.PrototypeEnabled :: { [string]: boolean })[id] then return "В разработке" end
	local unavailable = Controller.Unavailable(id=="CloneCommand" or id=="KcmCancel" or id=="GamakichiOil" or id=="GamakichiChop"); if unavailable then return unavailable end
	local player = Players.LocalPlayer; local model = player.Character; if not model then return "Недоступно" end
	if (id=="RikudoHY" or id=="RikudoHZ") and model:GetAttribute("RikudoRangedGranted")~=true then return "Нужен активный Рикудо" end
 local state = player:FindFirstChild("HeroState"); local level = if state then state:GetAttribute("Level") else nil
 local line=if id=="KcmDash" or id=="KcmCancel" then "KCM" elseif id=="MeditationToggle" or id=="MeditationRecall" then "SageMode" elseif id=="CloneCommand" then "ShadowClones" elseif id=="GamakichiOil" or id=="GamakichiChop" then "Gamakichi" else id
 if (id=="KCM" or id=="KcmDash" or id=="KcmCancel" or id=="GamakichiOil" or id=="GamakichiChop" or id=="Rasengan" or id=="ShadowClones" or id=="Gamakichi" or id=="SageMode" or id=="MeditationToggle" or id=="MeditationRecall" or id=="CloneCommand") and (not state or (if id=="CloneCommand" then math.max((state:GetAttribute("Rank_ShadowClones") or 0) :: number,(state:GetAttribute("Rank_Gamakichi") or 0) :: number) else ((state:GetAttribute("Rank_"..line) or 0) :: number))<1) then return "Не изучено" end
	if id == "Rasengan" and (typeof(level) ~= "number" or level < 4) then return "С уровня 4" end
	if id=="MeditationRecall" and (model:GetAttribute("MeditationCloneCount") or 0)==0 then return "Нет медитирующих клонов" end
	if id=="Odama" or id=="Rasenshuriken" then
  if model:GetAttribute("KcmActive")==true or model:GetAttribute("KuramaActive")==true or (model:GetAttribute("SagePhase")~=nil and model:GetAttribute("SagePhase")~="" and model:GetAttribute("SagePhase")~="Active") then return "Нужна обычная форма или готовый режим мудреца" end
  local rank=if state then (state:GetAttribute("Rank_Rasengan") or 0) :: number else 0
  local untilAt=(model:GetAttribute("RasenganVariantUntil") or 0) :: number
  local wanted=if id=="Odama" or model:GetAttribute("RasenganVariant")=="Rasengan" then "Rasengan" else "Odama"
  if rank<(if id=="Odama" then 2 else 3) then return if id=="Odama" then "Нужен II ранг Расенгана" else "Нужен III ранг Расенгана" end
  if model:GetAttribute("RasenganVariant")~=wanted then return if id=="Odama" then "Сначала Q — Расенган" else "Сначала Q — Расенган" end
  if untilAt<=workspace:GetServerTimeNow() then return "Окно усиления закрыто" end
 end
 if id=="RasenshurikenThrow" and (model:GetAttribute("SagePhase")~="Active" or model:GetAttribute("SageTechniquesReady")~=true or model:GetAttribute("RasenganVariant")~="Rasenshuriken" or model:GetAttribute("RasenganPhase")~="Holding") then return "Мудрец → Q → X → дождитесь формирования" end
 if id=="ShadowSleep" and (not state or ((state:GetAttribute("Rank_ShadowClones") or 0) :: number)<2) then return "Нужен II ранг клонов" end
	if id=="KuramaForm" then
  if typeof(level)~="number" or level<21 then return "Курама с уровня 21" end
  if model:GetAttribute("KcmActive")==true then return "Сначала выйдите из KCM / Рикудо: C → V" end
  if model:GetAttribute("KuramaLocked")==true then return "Форма Курамы уже действует" end
  if ((model:GetAttribute("KuramaChakra") or 0) :: number)<2500 then return "Нужно 2500 чакры Курамы" end
 end
 local kcm=model:GetAttribute("KcmActive")==true
 if id=="KCM" and not kcm and state and state:GetAttribute("Rank_KCM")==3 and model:GetAttribute("HagoromoUnlocked")~=true then return "Для Рикудо нужен дар Хагоромо" end
 if id=="KCM" and model:GetAttribute("KcmAllowed")~=true then
  if kcm then return "Режим уже действует • C → V — выйти" end
  return "Сначала завершите текущий режим"
 end
 if id=="KCM" and ((model:GetAttribute("KuramaChakra") or 0) :: number)<200 then return "Нужно 200 чакры Курамы" end
 if id=="KcmCancel" and not kcm then return "KCM не активен" end
 if id=="KcmDash" and model:GetAttribute("KcmDashReady")~=true then return "Рывок доступен в KCM" end
 if id=="Gamakichi" and kcm then return "Недоступно в KCM" end
 if id=="KuramaConvert" and (typeof(level)~="number" or level<16 or ((model:GetAttribute("KuramaChakra") or 0) :: number)<200) then return "Уровень 16 и 200 чакры Курамы" end

 local mana = model:GetAttribute("Mana")
 if id=="SageMode" and model:GetAttribute("SagePhase")~="" and model:GetAttribute("SagePhase")~=nil then return "Режим уже действует" end
 if id=="SageMode" and model:GetAttribute("RikudoActive")==true then return "В Рикудо нельзя заново включить режим мудреца" end
 local cost = Controller.Cost(id)
	if cost > 0 and (typeof(mana) ~= "number" or mana < cost) then return "Недостаточно маны" end
	if id == "CloneCommand" and (model:GetAttribute("NativeCloneCount") or 0) == 0 and (model:GetAttribute("GamakichiCount") or 0)==0 then return "Нет клонов" end
 if (id=="GamakichiOil" or id=="GamakichiChop") and (model:GetAttribute("GamakichiCount") or 0)==0 then return "Нет Гамакичи" end
 if id=="GamakichiChop" and model:GetAttribute("GamakichiAdult")~=true then return "Только взрослый Гамакичи" end
 return nil
end
local function reject(reason: string): boolean
 lastReason=reason; Controller.Changed:Fire(); return false
end
function Controller.BeginTarget(id: string): boolean
 if not needsTarget(id) then return false end
 local reason=Controller.AbilityUnavailable(id)
 if reason then return reject(reason) end
 if Controller.Remaining(id)>0 then return reject("Способность восстанавливается") end
 quickKey=nil; selectingCommand=id; Players.LocalPlayer:SetAttribute("SelectingCloneTarget",true)
 lastReason="ЛКМ — применить · ПКМ / Esc — отмена"; Controller.Changed:Fire(); return true
end
function Controller.BeginCloneCommand(): boolean return Controller.BeginTarget("CloneCommand") end
function Controller.PickCloneTarget(point: Vector2?): Model? return Targeting.PickModel(point) end
function Controller.ConfirmTarget(): boolean
 if not selectingCommand then return false end
 local target,reason=Targeting.Evaluate(selectingCommand)
 if reason then return reject(reason) end
 return Controller.TryCast(selectingCommand,target)
end
function Controller.Command(mode: string): boolean
 if mode=="Follow" or mode=="Hold" then return Controller.TryCast("CloneCommand",mode) end
 if not Controller.BeginCloneCommand() then return false end
 return Controller.ConfirmTarget()
end
local function dispatch(id: string, selectedTarget: any): boolean
	if not remote or not Config.Abilities[id] then return false end
	local reason=Controller.AbilityUnavailable(id); if reason then return reject(reason) end
	if Controller.Remaining(id)>0 then return reject("Способность восстанавливается") end
	local model = Players.LocalPlayer.Character; if not model then return false end
	local target = if needsTarget(id) or id=="RasenshurikenThrow" then selectedTarget else nil
	if needsTarget(id) and not target then return Controller.BeginTarget(id) end
	serial += 1; if serial > Config.MaxRequestId then return false end
	pendingId = serial; pendingAt = workspace:GetServerTimeNow(); pendingAbility=id; lastReason = ""
	if selectingCommand then
		selectingCommand = nil; quickKey=nil; Targeting.Clear()
		-- Consume the target-selection click for every InputBegan listener this frame.
		RunService.PreRender:Once(function()
			if not selectingCommand then Players.LocalPlayer:SetAttribute("SelectingCloneTarget", nil) end
		end)
	end
	if target then remote:FireServer(serial, model, id, target, Rounds.Current())
	else remote:FireServer(serial, model, id, Rounds.Current()) end
	Controller.Changed:Fire(); return true
end
local function queueUpgrade(id: string): boolean
 local player=Players.LocalPlayer; local model=player.Character
 if not model then return reject("Недоступно") end
 local now=workspace:GetServerTimeNow()
 local unavailable=Controller.Unavailable()
 if unavailable and unavailable~="Ожидание ответа" then clearUpgrades(); return reject(unavailable) end
 if unavailable=="Ожидание ответа" and pendingAbility~="Rasengan" and pendingAbility~="Odama" and pendingAbility~="Rasenshuriken" then
  return reject(unavailable)
 end
 if model:GetAttribute("KcmActive")==true or model:GetAttribute("KuramaActive")==true
  or (model:GetAttribute("SagePhase")~=nil and model:GetAttribute("SagePhase")~="" and model:GetAttribute("SagePhase")~="Active") then
  clearUpgrades(); return reject("Нужна обычная форма или готовый режим мудреца")
 end
 local hero=player:FindFirstChild("HeroState")
 local rank=if hero then (hero:GetAttribute("Rank_Rasengan") or 0) :: number else 0
 if rank<(if id=="Odama" then 2 else 3) then return reject(if id=="Odama" then "Нужен II ранг Расенгана" else "Нужен III ранг Расенгана") end
 local queue=upgrades
 -- Repeated presses on a submitted/queued step never send a second request.
 if queue and not queue.closed and (queue.awaiting==id or queue.stage==id or table.find(queue.items,id)) then return true end
 if Controller.Remaining(id)>0 then return reject("Способность восстанавливается") end
 if ((model:GetAttribute("Mana") or 0) :: number)<200 then return reject("Для усиления нужно ещё 200 чакры") end
 if not queue or queue.closed or upgradeCharacter~=model then
  local variant=model:GetAttribute("RasenganVariant")
  if variant~="Rasengan" and variant~="Odama" then return reject(if id=="Odama" then "Сначала Q — Расенган" else "Сначала Q — Расенган") end
  queue=UpgradeQueue.new((model:GetAttribute("NarutoCastId") or 0) :: number,variant,
   (model:GetAttribute("RasenganVariantUntil") or 0) :: number,nil)
  upgrades=queue; upgradeCharacter=model
 end
 assert(queue)
 local ok,reason=UpgradeQueue.enqueue(queue,id,now)
 if not ok then return reject(if reason=="Window" then "Окно усиления закрыто" else "Сначала Q — Расенган") end
 lastReason=""; Controller.Changed:Fire(); return true
end
function Controller.TryCast(id: string, selectedTarget: any): boolean
 if id=="Odama" or id=="Rasenshuriken" then return queueUpgrade(id) end
 local ok=dispatch(id,selectedTarget)
 if ok then
  clearUpgrades()
  if id=="Rasengan" then
   local model=Players.LocalPlayer.Character
   if model then
    upgradeCharacter=model
    upgrades=UpgradeQueue.new(((model:GetAttribute("NarutoCastId") or 0) :: number)+1,"Rasengan",workspace:GetServerTimeNow()+1.25,"Rasengan")
   end
  end
 end
 return ok
end
function Controller.TryThrowRasenshuriken(): boolean
 local model=Players.LocalPlayer.Character
 if not model or model:GetAttribute("SageTechniquesReady")~=true or model:GetAttribute("SagePhase")~="Active" or model:GetAttribute("RasenganVariant")~="Rasenshuriken" then return false end
 if model:GetAttribute("RasenganPhase")~="Holding" or ((model:GetAttribute("RasenganReadyAt") or 0) :: number)>workspace:GetServerTimeNow() then return true end
 local camera=require(script.Parent.CameraController);local ray=camera.GetAimRay()
 if not ray then return true end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={model}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*120,params)
 dispatch("RasenshurikenThrow",if hit then hit.Position else ray.Origin+ray.Direction*120)
 return true
end
local function flushUpgrades()
 local queue=upgrades; if not queue then return end
 local player=Players.LocalPlayer; local model=player.Character; local now=workspace:GetServerTimeNow()
 local hp=if model then model:FindFirstChildOfClass("Humanoid") else nil
 if model~=upgradeCharacter or not model or not hp or hp.Health<=0 or model:GetAttribute("CombatDisabled")==true
  or Gui.MenuIsOpen or Input:GetFocusedTextBox() or player:GetAttribute("ShopOpen")==true or player:GetAttribute("StatsOpen")==true
  or model:GetAttribute("KcmActive")==true or model:GetAttribute("KuramaActive")==true
  or (model:GetAttribute("SagePhase")~=nil and model:GetAttribute("SagePhase")~="" and model:GetAttribute("SagePhase")~="Active") or UpgradeQueue.expired(queue,now) then
  clearUpgrades(); return
 end
 local cast=(model:GetAttribute("NarutoCastId") or 0) :: number
 -- A base request creates the next cast; replication can precede or trail Result.
 if queue.awaiting=="Rasengan" and cast==queue.castId-1 then return end
 if not UpgradeQueue.observe(queue,cast,tostring(model:GetAttribute("RasenganVariant")),
  (model:GetAttribute("RasenganVariantUntil") or 0) :: number,now) then clearUpgrades(); return end
 if pendingId>0 then return end
 local nextId=UpgradeQueue.next(queue,now); if not nextId then return end
 local reason=Controller.AbilityUnavailable(nextId)
 if reason or Controller.Remaining(nextId)>0 then clearUpgrades(); reject(reason or "Способность восстанавливается"); return end
 if dispatch(nextId,nil) then UpgradeQueue.sent(queue,nextId,now) else clearUpgrades() end
end
function Controller.GetMessage(): string
 local model=Players.LocalPlayer.Character
 if lastReason~="" then return lastReason end
 if model and model:GetAttribute("RasenganHeld")==true then
  local variant=tostring(model:GetAttribute("RasenganVariant"))
  if variant=="Rasenshuriken" and model:GetAttribute("SageTechniquesReady")==true and model:GetAttribute("SagePhase")=="Active" then return "Расенсюрикен · ЛКМ — бросить по прицелу" end
  local name=if variant=="Odama" then "Одама Расенган" elseif variant=="Rasenshuriken" then "Расенсюрикен" else "Расенган"
  local nextId=if variant=="Rasengan" then "Odama" elseif variant=="Odama" then "Rasenshuriken" else nil
  if nextId and not Controller.AbilityUnavailable(nextId) and Controller.Remaining(nextId)<=0 then
   local hero=Players.LocalPlayer:FindFirstChild("HeroState")
   local third=hero~=nil and ((hero:GetAttribute("Rank_Rasengan") or 0) :: number)>=3
   return if nextId=="Odama" then (if third then "Z — Одама / X — Расенсюрикен · +200 чакры" else "Z — Одама · +200 чакры") else "X — усилить до Расенсюрикена · +200 чакры"
  end
  local phase=model:GetAttribute("RasenganPhase")
  return if phase=="Consumed" then name..": попадание" elseif phase=="Preparing" then name..": формирование в руке…" else name.." готов · подойдите к врагу и нажмите ЛКМ"
 end
 return if model and model:GetAttribute("MeditationMode")==true then "Медитация: T → T · вернуть чакру: T → Z" else ""
end
function Controller.GetFormStatus(): string
 local model=Players.LocalPlayer.Character; if not model then return "" end
 if model:GetAttribute("HeroId")=="Sasuke" then return if model:GetAttribute("ChidoriHeld")==true then "Чидори в руке • первое попадание ЛКМ расходует заряд" else "" end
 local chakra=model:GetAttribute("KuramaChakra"); if typeof(chakra)~="number" then return "" end
 local now=workspace:GetServerTimeNow()
 local layers={}
 if model:GetAttribute("KuramaActive")==true then
  table.insert(layers,string.format("Форма Курамы %.0fс",math.max(0,((model:GetAttribute("KuramaExpiresAt") or now) :: number)-now)))
 elseif model:GetAttribute("KcmActive")==true then
  local rank=model:GetAttribute("KcmRank")
  table.insert(layers,if rank==3 then "Рикудо" elseif rank==2 then "KCM II" else "KCM I")
 end
 if model:GetAttribute("SagePhase")=="Active" then
  local remaining=math.max(0,((model:GetAttribute("SageExpiresAt") or now) :: number)-now)
  table.insert(layers,string.format("%s %.0fс",if model:GetAttribute("SageTechniquesReady")==true then "Мудрец" else "Бонусы мудреца",remaining))
 elseif model:GetAttribute("SagePhase")=="Preparing" then table.insert(layers,"Сбор природной энергии") end
 return string.format("Чакра Курамы %d | %s",math.floor(chakra),if #layers>0 then table.concat(layers," + ") else "C — режимы · T — чакра")
end
function Controller.Start()
	if remote then return end
	Rounds.Watch(function() pendingId = 0; pendingAbility=nil; clearUpgrades(); corrections = {}; correctionModel = nil; Controller.CancelCloneCommand(); Controller.Changed:Fire() end)
	local event = ReplicatedStorage:WaitForChild("HeroAbility", 15); assert(event and event:IsA("RemoteEvent"), "HeroAbility missing")
	remote = event; VFX.Start()
	RunService.Heartbeat:Connect(function()
  flushUpgrades()
		if selectingCommand then
   if Controller.AbilityUnavailable(selectingCommand) then Controller.CancelCloneCommand(); Controller.Changed:Fire()
   else
    local reason=Targeting.Preview(selectingCommand)
    lastReason=(reason or "Цель доступна")..(if quickKey then " · ЛКМ — рывок · ПКМ — отмена" else " · ЛКМ — применить · ПКМ / Esc — отмена")
   end
  end
	end)
	event.OnClientEvent:Connect(function(message: any)
		if not Rounds.Accepts(message.roundId) then return end
		if message.kind == "DamageFeedback" then Feedback.DamageFeedback(message); return end
		if message.kind ~= "Result" then VFX.Event(message); return end
		if message.character ~= Players.LocalPlayer.Character or message.requestId ~= pendingId then return end
		pendingId = 0; pendingAbility=nil; if not message.accepted then clearUpgrades() end; correctionModel = message.character; corrections = message.ready; correctionUntil = workspace:GetServerTimeNow() + 1.5
		local reasons: { [string]: string } = { Window="Окно усиления закрыто", Rank="Нужен следующий ранг Расенгана", FormAdapterUnverified="Усиления доступны в обычной форме", Unlearned="Способность не изучена", Rikudo="Нужен активный Рикудо", Hagoromo="Требуется дар Хагоромо", Chakra="Недостаточно чакры Курамы", Form="Недоступно в текущей форме", Range="Слишком далеко", Blocked="Путь перекрыт", Ground="Выберите устойчивую поверхность", Busy = "Дождитесь завершения действия", Cooldown = "Способность восстанавливается",
			Unavailable = "Сейчас недоступно", RateLimited = "Слишком часто", Replay = "Запрос уже обработан", Mana = "Недостаточно маны",
			Level = "Требуется уровень 4", Target = "Выберите доступного врага", Unsupported = "Ещё не доступно", UnsupportedTarget = "Эта ветка ещё не доступна" }
		lastReason = if message.accepted then "" else reasons[message.reason] or "Запрос отклонён"
		Controller.Changed:Fire()
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function() pendingId = 0; pendingAbility=nil; clearUpgrades(); corrections = {}; correctionModel = nil; Controller.CancelCloneCommand() end)
 Input.InputBegan:Connect(function(input,processed)
  if selectingCommand and input.KeyCode==Enum.KeyCode.Escape then Controller.CancelCloneCommand();Controller.Changed:Fire();return end
  if processed or Input:GetFocusedTextBox() or Gui.MenuIsOpen then return end
  if selectingCommand then
   if input.UserInputType==Enum.UserInputType.MouseButton2 then Controller.CancelCloneCommand();Controller.Changed:Fire();return end
   if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
    local gui=Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local abilityGui=if gui then gui:FindFirstChild("AbilityHUD") else nil
    if gui and abilityGui then for _,object in gui:GetGuiObjectsAtPosition(input.Position.X,input.Position.Y) do if object:IsDescendantOf(abilityGui) then return end end end
    Controller.ConfirmTarget()
   end
  end
 end)
 Input.WindowFocusReleased:Connect(function() clearUpgrades(); Controller.CancelCloneCommand() end)
 Players.LocalPlayer.CharacterRemoving:Connect(function() clearUpgrades(); Controller.CancelCloneCommand() end)
end
return Controller
