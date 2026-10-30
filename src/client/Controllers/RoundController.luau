--!strict
local Storage = game:GetService("ReplicatedStorage")
local Protocol = require(Storage:WaitForChild("Shared").Game.RoundProtocol)
local Controller = {}
local callbacks: { () -> () } = {}
local bound: Instance? = nil
local function clear() for _, callback in callbacks do callback() end end
local function bind(state: Instance)
	if bound or state.Name ~= "SurvivalState" then return end; bound = state
	state:GetAttributeChangedSignal("RoundId"):Connect(clear)
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = state:GetAttribute("Phase")
		if phase == "Finished" then clear() end
	end)
end
function Controller.Current(): number?
	local state = Storage:FindFirstChild("SurvivalState")
	return if state then state:GetAttribute("RoundId") :: number? else nil
end
function Controller.Accepts(roundId: any): boolean
	local state = Storage:FindFirstChild("SurvivalState")
	local isolated = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("CombatOnlyTest") == true
	return Protocol.acceptsClient(Controller.Current(), roundId, if state then state:GetAttribute("Phase") else nil, isolated)
end
function Controller.Watch(callback: () -> ())
	table.insert(callbacks, callback)
end
Storage.ChildAdded:Connect(bind)
local state = Storage:FindFirstChild("SurvivalState"); if state then bind(state) end
return Controller
