--!strict
local Players = game:GetService("Players")
local Controller = {}
local remote: RemoteEvent? = nil
local serial, messageUntil = 0, 0
local message = ""
local reasons: { [string]: string } = { Learned="Способность изучена", NoPoints="Нет очков обучения", Level="Недостаточный уровень", NotImplemented="Ранг пока недоступен", Replay="Повторный запрос", StaleLife="Герой изменился", RateLimited="Слишком часто" }
function Controller.GetMessage(): string return if os.clock()<messageUntil then message else "" end
function Controller.Start()
	if remote then return end
	local event=game:GetService("ReplicatedStorage"):WaitForChild("AbilityLearning",15)
	assert(event and event:IsA("RemoteEvent")); remote=event
	event.OnClientEvent:Connect(function(_ok: boolean,reason: string) message=reasons[reason] or "Обучение недоступно"; messageUntil=os.clock()+3 end)
end
function Controller.TryLearn(id: string)
	local player=Players.LocalPlayer; local model=player.Character
	local state=game:GetService("ReplicatedStorage"):FindFirstChild("SurvivalState")
	if not remote or not model or not state then return end
	serial += 1
	remote:FireServer(serial,model,model:GetAttribute("LifeId"),id,state:GetAttribute("RoundId"))
end
return Controller
