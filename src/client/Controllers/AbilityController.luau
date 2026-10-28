--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.AbilityConfig)
local VFX = require(script.Parent.AbilityVFXController)
local Rounds = require(script.Parent.RoundController)
local Controller = { Changed = Instance.new("BindableEvent") }
local remote: RemoteEvent? = nil
local serial = 0
local pendingId, pendingAt = 0, 0
local corrections: { [string]: number } = {}
local correctionModel: Model? = nil
local lastReason = ""
function Controller.Remaining(id: string): number
	local model = Players.LocalPlayer.Character; if not model then return 0 end
	local deadline = model:GetAttribute("Ready_" .. id)
	return math.max(0, math.max(if typeof(deadline) == "number" then deadline else 0,
		if correctionModel == model then corrections[id] or 0 else 0) - workspace:GetServerTimeNow())
end
function Controller.Unavailable(): string?
	local player = Players.LocalPlayer; local model = player.Character
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if not model or not humanoid or humanoid.Health <= 0 or model:GetAttribute("CombatDisabled") == true or player:GetAttribute("Eliminated") == true then return "Недоступно" end
	if player:GetAttribute("ShopOpen") == true then return "Магазин открыт" end
	if Input:GetFocusedTextBox() then return "Ввод текста" end
	local match = ReplicatedStorage:FindFirstChild("SurvivalState")
	if not match or match:GetAttribute("Phase") ~= "InProgress" then return "Ожидание матча" end
	if model:GetAttribute("CombatState") == "Stunned" then return "Оглушение" end
	local nextM1 = model:GetAttribute("CombatNextAttackAt")
	if model:GetAttribute("AbilityId") ~= "" and model:GetAttribute("AbilityId") ~= nil then return "Способность" end
	if typeof(nextM1) == "number" and nextM1 > workspace:GetServerTimeNow() then return "Восстановление" end
	if pendingId > 0 and workspace:GetServerTimeNow() - pendingAt < 1.5 then return "…" end
	return nil
end
function Controller.TryCast(id: string): boolean
	if not remote or not Config.Abilities[id] or Controller.Unavailable() or Controller.Remaining(id) > 0 then return false end
	local model = Players.LocalPlayer.Character; if not model then return false end
	serial += 1; if serial > Config.MaxRequestId then return false end
	pendingId = serial; pendingAt = workspace:GetServerTimeNow(); lastReason = ""
	remote:FireServer(serial, model, id, Rounds.Current()); Controller.Changed:Fire(); return true
end
function Controller.GetMessage(): string return lastReason end
function Controller.Start()
	if remote then return end
	Rounds.Watch(function() pendingId = 0; corrections = {}; correctionModel = nil; lastReason = ""; Controller.Changed:Fire() end)
	local event = ReplicatedStorage:WaitForChild("HeroAbility", 15); assert(event and event:IsA("RemoteEvent"), "HeroAbility missing")
	remote = event; VFX.Start()
	event.OnClientEvent:Connect(function(message: any)
		if not Rounds.Accepts(message.roundId) then return end
		if message.kind ~= "Result" then VFX.Event(message); return end
		if message.character ~= Players.LocalPlayer.Character then return end
		if typeof(message.requestId) ~= "number" or message.requestId ~= pendingId then return end
		pendingId = 0; correctionModel = message.character; corrections = message.ready
		local reasons: { [string]: string } = { Busy = "Дождитесь конца действия", Cooldown = "Способность восстанавливается", Unavailable = "Сейчас недоступно", RateLimited = "Слишком часто", Replay = "Запрос уже обработан" }
		lastReason = if message.accepted then "" else reasons[message.reason] or "Запрос отклонён"
		Controller.Changed:Fire()
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function() pendingId = 0; corrections = {}; correctionModel = nil; lastReason = "" end)
	Input.InputBegan:Connect(function(input, processed)
		if processed or Input:GetFocusedTextBox() then return end
		local keys: { [Enum.KeyCode]: string } = { [Enum.KeyCode.Z] = "ShadowClones", [Enum.KeyCode.X] = "SpiralSphere", [Enum.KeyCode.C] = "WindPalm" }
		local id = keys[input.KeyCode]; if id then Controller.TryCast(id) end
	end)
end
return Controller
