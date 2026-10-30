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
local Gama=require(Shared.Abilities.GamakichiState)
local Controller = { Changed = Instance.new("BindableEvent") }
local remote: RemoteEvent? = nil
local serial, pendingId, pendingAt = 0, 0, 0
local corrections: { [string]: number } = {}
local correctionModel: Model? = nil
-- Corrections bridge replication latency; replicated deadlines remain authoritative after that window.
local correctionUntil = 0
local lastReason = ""
local selectingCommand = false
function Controller.CancelCloneCommand()
	selectingCommand = false; Players.LocalPlayer:SetAttribute("SelectingCloneTarget", nil); lastReason = ""
end
function Controller.IsSelectingCloneTarget(): boolean return selectingCommand end
function Controller.Remaining(id: string): number
	local model = Players.LocalPlayer.Character; if not model then return 0 end
	local deadline = model:GetAttribute("Ready_" .. id)
	return math.max(0, math.max(if typeof(deadline) == "number" then deadline else 0,
		if correctionModel == model and workspace:GetServerTimeNow() < correctionUntil then corrections[id] or 0 else 0) - workspace:GetServerTimeNow())
end
function Controller.Unavailable(): string?
	local player = Players.LocalPlayer; local model = player.Character
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if not model or not humanoid or humanoid.Health <= 0 or model:GetAttribute("CombatDisabled") == true or player:GetAttribute("Eliminated") == true then return "Недоступно" end
	if player:GetAttribute("ShopOpen") == true then return "Закройте магазин" end
	if Input:GetFocusedTextBox() then return "Ввод текста" end
	local match = ReplicatedStorage:FindFirstChild("SurvivalState")
	if not match or match:GetAttribute("Phase") ~= "InProgress" then return "Ожидание матча" end
	if model:GetAttribute("CombatState") == "Stunned" then return "Контроль" end
	if model:GetAttribute("AbilityId") ~= "" and model:GetAttribute("AbilityId") ~= nil then return "Подготовка" end
	local nextM1 = model:GetAttribute("CombatNextAttackAt")
	if typeof(nextM1) == "number" and nextM1 > workspace:GetServerTimeNow() then return "Восстановление" end
	if pendingId > 0 and workspace:GetServerTimeNow() - pendingAt < 1.5 then return "Ожидание ответа" end
	return nil
end
function Controller.AbilityUnavailable(id: string): string?
	if not (Config.PrototypeEnabled :: { [string]: boolean })[id] then return "В разработке" end
	local unavailable = Controller.Unavailable(); if unavailable then return unavailable end
	local player = Players.LocalPlayer; local model = player.Character; if not model then return "Недоступно" end
	local state = player:FindFirstChild("HeroState"); local level = if state then state:GetAttribute("Level") else nil
 local line=if id=="CloneCommand" then "ShadowClones" else id
 if (id=="Rasengan" or id=="ShadowClones" or id=="Gamakichi" or id=="CloneCommand") and (not state or (if id=="CloneCommand" then math.max((state:GetAttribute("Rank_ShadowClones") or 0) :: number,(state:GetAttribute("Rank_Gamakichi") or 0) :: number) else ((state:GetAttribute("Rank_"..line) or 0) :: number))<1) then return "Не изучено" end
	if id == "Rasengan" and (typeof(level) ~= "number" or level < 4) then return "С уровня 4" end
	local mana = model:GetAttribute("Mana")
	local cost = if id == "Rasengan" then 100 elseif id == "ShadowClones" then 200 elseif id=="Gamakichi" then Gama.rank(if state then (state:GetAttribute("Rank_Gamakichi") or 0) :: number else 0) or 0 else 0
	if cost > 0 and (typeof(mana) ~= "number" or mana < cost) then return "Недостаточно маны" end
	if id == "CloneCommand" and (model:GetAttribute("NativeCloneCount") or 0) == 0 and (model:GetAttribute("GamakichiCount") or 0)==0 then return "Нет клонов" end
	return nil
end
function Controller.BeginCloneCommand(): boolean
	if Controller.AbilityUnavailable("CloneCommand") then return false end
	selectingCommand = true; Players.LocalPlayer:SetAttribute("SelectingCloneTarget", true)
	lastReason = "Выберите врага · Esc — отмена"; Controller.Changed:Fire(); return true
end
function Controller.PickCloneTarget(point: Vector2?): Model?
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
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local item: Instance? = if hit then hit.Instance else nil
	while item and item ~= workspace do
		if item:IsA("Model") and item:FindFirstChildOfClass("Humanoid") then return item end
		item = item.Parent
	end
	return nil
end
function Controller.TryCast(id: string, selectedTarget: Model?): boolean
	if not remote or not Config.Abilities[id] or Controller.AbilityUnavailable(id) or Controller.Remaining(id) > 0 then return false end
	local model = Players.LocalPlayer.Character; if not model then return false end
	local target = if id == "CloneCommand" then selectedTarget or Controller.PickCloneTarget(nil) else nil
	if id == "CloneCommand" and not target then return Controller.BeginCloneCommand() end
	serial += 1; if serial > Config.MaxRequestId then return false end
	pendingId = serial; pendingAt = workspace:GetServerTimeNow(); lastReason = ""
	if selectingCommand then
		selectingCommand = false
		-- Consume the target-selection click for every InputBegan listener this frame.
		RunService.PreRender:Once(function()
			if not selectingCommand then Players.LocalPlayer:SetAttribute("SelectingCloneTarget", nil) end
		end)
	end
	if target then remote:FireServer(serial, model, id, target, Rounds.Current())
	else remote:FireServer(serial, model, id, Rounds.Current()) end
	Controller.Changed:Fire(); return true
end
function Controller.GetMessage(): string return lastReason end
function Controller.Start()
	if remote then return end
	Rounds.Watch(function() pendingId = 0; corrections = {}; correctionModel = nil; Controller.CancelCloneCommand(); Controller.Changed:Fire() end)
	local event = ReplicatedStorage:WaitForChild("HeroAbility", 15); assert(event and event:IsA("RemoteEvent"), "HeroAbility missing")
	remote = event; VFX.Start()
	RunService.Heartbeat:Connect(function()
		if selectingCommand and Controller.AbilityUnavailable("CloneCommand") then Controller.CancelCloneCommand(); Controller.Changed:Fire() end
	end)
	event.OnClientEvent:Connect(function(message: any)
		if not Rounds.Accepts(message.roundId) then return end
		if message.kind ~= "Result" then VFX.Event(message); return end
		if message.character ~= Players.LocalPlayer.Character or message.requestId ~= pendingId then return end
		pendingId = 0; correctionModel = message.character; corrections = message.ready; correctionUntil = workspace:GetServerTimeNow() + 1.5
		local reasons: { [string]: string } = { Busy = "Дождитесь завершения действия", Cooldown = "Способность восстанавливается",
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
				local target = Controller.PickCloneTarget(Vector2.new(input.Position.X, input.Position.Y))
				if target then Controller.TryCast("CloneCommand", target) end
				return
			end
		end
		local alias = (Config.InputAliases :: {[string]: string})[input.KeyCode.Name]
		if alias then
   if alias~="CloneCommand" and (Input:IsKeyDown(Enum.KeyCode.LeftControl) or Input:IsKeyDown(Enum.KeyCode.RightControl)) then Learning.TryLearn(alias); return end
			if alias == "CloneCommand" then Controller.BeginCloneCommand() else Controller.TryCast(alias) end
			return
		end
		for _, id in Config.Order do
			if input.KeyCode.Name == Config.Abilities[id].Key then
    if Input:IsKeyDown(Enum.KeyCode.LeftControl) or Input:IsKeyDown(Enum.KeyCode.RightControl) then Learning.TryLearn(id) else Controller.TryCast(id) end
    break
   end
		end
	end)
end
return Controller
