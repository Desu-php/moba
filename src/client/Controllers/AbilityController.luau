--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.AbilityConfig)
local VFX = require(script.Parent.AbilityVFXController)
local Rounds = require(script.Parent.RoundController)
local Learning = require(script.Parent.LearningController)
local InputRules = require(Shared.Abilities.AbilityInputRules)
local Gama=require(Shared.Abilities.GamakichiState)
local Controller = { Changed = Instance.new("BindableEvent") }
local remote: RemoteEvent? = nil
local serial, pendingId, pendingAt = 0, 0, 0
local corrections: { [string]: number } = {}
local correctionModel: Model? = nil
-- Corrections bridge replication latency; replicated deadlines remain authoritative after that window.
local correctionUntil = 0
local lastReason = ""
local selectingCommand: string? = nil
local function needsTarget(id: string): boolean return id=="KcmDash" or id=="ShadowSleep" or id=="CloneCommand" or id=="GamakichiOil" or id=="GamakichiChop" end
function Controller.CancelCloneCommand()
	selectingCommand = nil; Players.LocalPlayer:SetAttribute("SelectingCloneTarget", nil); lastReason = ""
end
function Controller.IsSelectingCloneTarget(): boolean return selectingCommand~=nil end
function Controller.Remaining(id: string): number
 if id=="ShadowSleep" then id="ShadowClones" end
	local model = Players.LocalPlayer.Character; if not model then return 0 end
	local deadline = model:GetAttribute("Ready_" .. id)
	return math.max(0, math.max(if typeof(deadline) == "number" then deadline else 0,
		if correctionModel == model and workspace:GetServerTimeNow() < correctionUntil then corrections[id] or 0 else 0) - workspace:GetServerTimeNow())
end
function Controller.Unavailable(summonOrder: boolean?): string?
	local player = Players.LocalPlayer; local model = player.Character
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if not model or not humanoid or humanoid.Health <= 0 or model:GetAttribute("CombatDisabled") == true or player:GetAttribute("Eliminated") == true then return "Недоступно" end
	if player:GetAttribute("ShopOpen") == true then return "Закройте магазин" end
	if Input:GetFocusedTextBox() then return "Ввод текста" end
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
function Controller.AbilityUnavailable(id: string): string?
	if not (Config.PrototypeEnabled :: { [string]: boolean })[id] then return "В разработке" end
	local unavailable = Controller.Unavailable(id=="KcmCancel" or id=="GamakichiOil" or id=="GamakichiChop"); if unavailable then return unavailable end
	local player = Players.LocalPlayer; local model = player.Character; if not model then return "Недоступно" end
	local state = player:FindFirstChild("HeroState"); local level = if state then state:GetAttribute("Level") else nil
 local line=if id=="KcmDash" or id=="KcmCancel" then "KCM" elseif id=="MeditationToggle" or id=="MeditationRecall" then "SageMode" elseif id=="CloneCommand" then "ShadowClones" elseif id=="GamakichiOil" or id=="GamakichiChop" then "Gamakichi" else id
 if (id=="KCM" or id=="KcmDash" or id=="KcmCancel" or id=="GamakichiOil" or id=="GamakichiChop" or id=="Rasengan" or id=="ShadowClones" or id=="Gamakichi" or id=="SageMode" or id=="MeditationToggle" or id=="MeditationRecall" or id=="CloneCommand") and (not state or (if id=="CloneCommand" then math.max((state:GetAttribute("Rank_ShadowClones") or 0) :: number,(state:GetAttribute("Rank_Gamakichi") or 0) :: number) else ((state:GetAttribute("Rank_"..line) or 0) :: number))<1) then return "Не изучено" end
	if id == "Rasengan" and (typeof(level) ~= "number" or level < 4) then return "С уровня 4" end
	if id=="MeditationRecall" and (model:GetAttribute("MeditationCloneCount") or 0)==0 then return "Нет медитирующих клонов" end
	if id=="Odama" or id=="Rasenshuriken" then
  if model:GetAttribute("KcmActive")==true or (model:GetAttribute("SagePhase")~=nil and model:GetAttribute("SagePhase")~="") then return "Form variant unavailable" end
  local rank=if state then (state:GetAttribute("Rank_Rasengan") or 0) :: number else 0
  local untilAt=(model:GetAttribute("RasenganVariantUntil") or 0) :: number
  local wanted=if id=="Odama" then "Rasengan" else "Odama"
  if rank<(if id=="Odama" then 2 else 3) or model:GetAttribute("RasenganVariant")~=wanted or untilAt<=workspace:GetServerTimeNow() then return "No selection window" end
 end
 if id=="ShadowSleep" and (not state or ((state:GetAttribute("Rank_ShadowClones") or 0) :: number)<2) then return "Requires clones II" end

	local kcm=model:GetAttribute("KcmActive")==true
 if id=="KCM" and model:GetAttribute("KcmAllowed")~=true then return "KCM недоступен" end
 if id=="KCM" and ((model:GetAttribute("KuramaChakra") or 0) :: number)<200 then return "Нужно 200 чакры Курамы" end
 if id=="KcmCancel" and not kcm then return "KCM не активен" end
 if id=="KcmDash" and model:GetAttribute("KcmDashReady")~=true then return "Рывок доступен в KCM" end
 if id=="Gamakichi" and kcm then return "Недоступно в KCM" end
 if id=="KuramaConvert" and (typeof(level)~="number" or level<16 or ((model:GetAttribute("KuramaChakra") or 0) :: number)<200) then return "Уровень 16 и 200 чакры Курамы" end

 local mana = model:GetAttribute("Mana")
 if id=="SageMode" and model:GetAttribute("SagePhase")~="" and model:GetAttribute("SagePhase")~=nil then return "Режим уже действует" end
 local cost = if id=="KcmDash" then 100 elseif id=="Odama" or id=="Rasenshuriken" or id=="ShadowSleep" then 200 elseif id=="SageMode" then 25 elseif id == "Rasengan" then 100 elseif id == "ShadowClones" then 200 elseif id=="Gamakichi" then Gama.rank(if state then (state:GetAttribute("Rank_Gamakichi") or 0) :: number else 0) or 0 else 0
	if cost > 0 and (typeof(mana) ~= "number" or mana < cost) then return "Недостаточно маны" end
	if id == "CloneCommand" and (model:GetAttribute("NativeCloneCount") or 0) == 0 and (model:GetAttribute("GamakichiCount") or 0)==0 then return "Нет клонов" end
 if (id=="GamakichiOil" or id=="GamakichiChop") and (model:GetAttribute("GamakichiCount") or 0)==0 then return "Нет Гамакичи" end
 if id=="GamakichiChop" and model:GetAttribute("GamakichiAdult")~=true then return "Только взрослый Гамакичи" end
 return nil
end
function Controller.BeginTarget(id: string): boolean
	if not needsTarget(id) or Controller.AbilityUnavailable(id) or Controller.Remaining(id)>0 then return false end
	selectingCommand = id; Players.LocalPlayer:SetAttribute("SelectingCloneTarget", true)
	lastReason = if id=="GamakichiChop" then "Выберите точку · Esc — отмена" else "Выберите врага · Esc — отмена"; Controller.Changed:Fire(); return true
end
function Controller.BeginCloneCommand(): boolean return Controller.BeginTarget("CloneCommand") end
local function pick(point: Vector2?): RaycastResult?
	local camera = workspace.CurrentCamera; if not camera then return nil end
	local mouse = Input:GetMouseLocation()
	local ray = if point then camera:ScreenPointToRay(point.X, point.Y)
		elseif Input.MouseBehavior == Enum.MouseBehavior.LockCenter or Input.TouchEnabled
		then camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
		else camera:ScreenPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: { Instance } = if Players.LocalPlayer.Character then { Players.LocalPlayer.Character :: Model } else {}
	-- Friendly illusions must not intercept the selection ray. Keep terrain and walls queryable.
	local summons = workspace:FindFirstChild("HeroSummons")
	if summons then
		for _, model in summons:GetChildren() do
			if (model:GetAttribute("NativeNarutoClone") == true or model:GetAttribute("NativeGamakichi")==true) and model:GetAttribute("TeamId") == Players.LocalPlayer:GetAttribute("TeamId") then
				table.insert(excluded, model)
			end
		end
	end
	params.FilterDescendantsInstances = excluded
	return workspace:Raycast(ray.Origin, ray.Direction * 500, params)
end
function Controller.PickCloneTarget(point: Vector2?): Model?
 local hit=pick(point)
	local item: Instance? = if hit then hit.Instance else nil
	while item and item ~= workspace do
		if item:IsA("Model") and item:FindFirstChildOfClass("Humanoid") then return item end
		item = item.Parent
	end
	return nil
end
function Controller.TryCast(id: string, selectedTarget: any): boolean
	if not remote or not Config.Abilities[id] or Controller.AbilityUnavailable(id) or Controller.Remaining(id) > 0 then return false end
	local model = Players.LocalPlayer.Character; if not model then return false end
	local target = if needsTarget(id) then selectedTarget else nil
	if needsTarget(id) and not target then return Controller.BeginTarget(id) end
	serial += 1; if serial > Config.MaxRequestId then return false end
	pendingId = serial; pendingAt = workspace:GetServerTimeNow(); lastReason = ""
	if selectingCommand then
		selectingCommand = nil
		-- Consume the target-selection click for every InputBegan listener this frame.
		RunService.PreRender:Once(function()
			if not selectingCommand then Players.LocalPlayer:SetAttribute("SelectingCloneTarget", nil) end
		end)
	end
	if target then remote:FireServer(serial, model, id, target, Rounds.Current())
	else remote:FireServer(serial, model, id, Rounds.Current()) end
	Controller.Changed:Fire(); return true
end
function Controller.GetMessage(): string
 local model=Players.LocalPlayer.Character
 if model and model:GetAttribute("KcmActive")~=true and (model:GetAttribute("SagePhase")==nil or model:GetAttribute("SagePhase")=="") and ((model:GetAttribute("RasenganVariantUntil") or 0) :: number)>workspace:GetServerTimeNow() then
  local variant=model:GetAttribute("RasenganVariant")
  return if variant=="Odama" then "X: Rasenshuriken (III)" else "Z: Odama (II+)"
 end
 if lastReason~="" then return lastReason end
 return if model and model:GetAttribute("MeditationMode")==true then "Meditation: 4 / J recall / Right direct" else ""
end
function Controller.GetFormStatus(): string
 local model=Players.LocalPlayer.Character; if not model then return "" end
 local chakra=model:GetAttribute("KuramaChakra"); if typeof(chakra)~="number" then return "" end
 return string.format("Курама %d | %s",math.floor(chakra),if model:GetAttribute("KcmActive")==true then "KCM: E рывок / X выход / ← мана" else "5 KCM / ← 200 чакры в ману (ур.16)")
end
function Controller.Start()
	if remote then return end
	Rounds.Watch(function() pendingId = 0; corrections = {}; correctionModel = nil; Controller.CancelCloneCommand(); Controller.Changed:Fire() end)
	local event = ReplicatedStorage:WaitForChild("HeroAbility", 15); assert(event and event:IsA("RemoteEvent"), "HeroAbility missing")
	remote = event; VFX.Start()
	RunService.Heartbeat:Connect(function()
		if selectingCommand and Controller.AbilityUnavailable(selectingCommand) then Controller.CancelCloneCommand(); Controller.Changed:Fire() end
	end)
	event.OnClientEvent:Connect(function(message: any)
		if not Rounds.Accepts(message.roundId) then return end
		if message.kind ~= "Result" then VFX.Event(message); return end
		if message.character ~= Players.LocalPlayer.Character or message.requestId ~= pendingId then return end
		pendingId = 0; correctionModel = message.character; corrections = message.ready; correctionUntil = workspace:GetServerTimeNow() + 1.5
		local reasons: { [string]: string } = { Hagoromo="Требуется дар Хагоромо", Chakra="Недостаточно чакры Курамы", Form="Недоступно в текущей форме", Range="Слишком далеко", Blocked="Путь перекрыт", Ground="Выберите устойчивую поверхность", Busy = "Дождитесь завершения действия", Cooldown = "Способность восстанавливается",
			Unavailable = "Сейчас недоступно", RateLimited = "Слишком часто", Replay = "Запрос уже обработан", Mana = "Недостаточно маны",
			Level = "Требуется уровень 4", Target = "Выберите доступного врага", Unsupported = "Ещё не доступно", UnsupportedTarget = "Эта ветка ещё не доступна" }
		lastReason = if message.accepted then "" else reasons[message.reason] or "Запрос отклонён"
		Controller.Changed:Fire()
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function() pendingId = 0; corrections = {}; correctionModel = nil; Controller.CancelCloneCommand() end)
	Input.InputBegan:Connect(function(input, processed)
		if selectingCommand and input.KeyCode == Enum.KeyCode.Escape then Controller.CancelCloneCommand(); Controller.Changed:Fire(); return end
		if processed or Input:GetFocusedTextBox() then return end
		if selectingCommand then
			if input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2 then
				Controller.CancelCloneCommand(); Controller.Changed:Fire(); return
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
				local abilityGui = if gui then gui:FindFirstChild("AbilityHUD") else nil
				if gui and abilityGui then
					for _, object in gui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
						if object:IsDescendantOf(abilityGui) then return end
					end
				end
				local point=Vector2.new(input.Position.X,input.Position.Y)
			local hit=if selectingCommand=="GamakichiChop" or selectingCommand=="KcmDash" then pick(point) else nil
			local target: any=if selectingCommand=="KcmDash" then Controller.PickCloneTarget(point) or (if hit then hit.Position else nil) elseif selectingCommand=="GamakichiChop" then (if hit then hit.Position else nil) else Controller.PickCloneTarget(point)
				if target then Controller.TryCast(selectingCommand,target) end
				return
			end
		end
		local model = Players.LocalPlayer.Character
		local alias = InputRules.resolve(Config.InputAliases :: { read [string]: string }, input.KeyCode.Name, model ~= nil and model:GetAttribute("KcmActive") == true)
		if alias then
   if not needsTarget(alias) and (Input:IsKeyDown(Enum.KeyCode.LeftControl) or Input:IsKeyDown(Enum.KeyCode.RightControl)) then Learning.TryLearn(alias); return end
			if alias == "CloneCommand" then Controller.BeginCloneCommand() else Controller.TryCast(alias) end
			return
		end
		for _, id in Config.Order do
			if input.KeyCode.Name == Config.Abilities[id].Key then
    if not needsTarget(id) and (Input:IsKeyDown(Enum.KeyCode.LeftControl) or Input:IsKeyDown(Enum.KeyCode.RightControl)) then Learning.TryLearn(id) else Controller.TryCast(id) end
    break
   end
		end
	end)
end
return Controller
