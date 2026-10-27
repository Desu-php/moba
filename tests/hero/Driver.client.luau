--!strict
assert(game:GetService("RunService"):IsStudio())
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local driver = ReplicatedStorage:WaitForChild("HeroTestDriver") :: RemoteEvent
local ability = ReplicatedStorage:WaitForChild("HeroAbility") :: RemoteEvent
local controllers = player.PlayerScripts:WaitForChild("Client"):WaitForChild("Controllers")
local motion = require(controllers:WaitForChild("HeroMotionController"))
local RigJoints = require(ReplicatedStorage:WaitForChild("Shared").Combat.RigJoints)
local replies: { [number]: any } = {}
ability.OnClientEvent:Connect(function(message: any) if message.kind == "Result" then replies[message.requestId] = message end end)
driver.OnClientEvent:Connect(function(id: number, mode: string, data: any)
	local result: any = {}
	if mode == "cast" then
		ability:FireServer(table.unpack(data, 1, data.n))
		local deadline = os.clock() + 2
		repeat task.wait(0.02) until replies[data[1]] or os.clock() >= deadline
		result = replies[data[1]] or { reason = "NoReply", accepted = false }
	elseif mode == "flood" then
		for i = 1, 30 do ability:FireServer(data + i, player.Character, "Unknown") end
		task.wait(0.25); local replyCount = 0
		for requestId in replies do if requestId > data and requestId <= data + 30 then replyCount += 1 end end
		result.replies = replyCount
	elseif mode == "motion" then
		local model = data :: Model; local first: { [RigJoints.Joint]: CFrame } = {}
		for _, entry in RigJoints.Collect(model) do first[entry.joint] = entry.joint.Transform end
		for _ = 1, 5 do RunService.PreRender:Wait() end
		local changed = 0
		for motor, transform in first do
			local x, y, z = transform:ToObjectSpace(motor.Transform):ToOrientation()
			if math.abs(x) + math.abs(y) + math.abs(z) > 0.015 then changed += 1 end
		end
		local key, moved = motion.GetDiagnostics(model)
		result = { key = key, moved = moved, changed = changed, appearance = model:FindFirstChild("HeroAppearance") ~= nil }
	elseif mode == "hud" then
		result = { hero = player.PlayerGui:FindFirstChild("HeroHUD") ~= nil, abilities = player.PlayerGui:FindFirstChild("AbilityHUD") ~= nil,
			match = player.PlayerGui:FindFirstChild("SurvivalHUD") ~= nil }
	elseif mode == "prediction" then
		local combat = require(controllers.CombatController)
		local animation = require(controllers.AnimationController)
		local before = animation.GetLogicalPlayCount()
		local accepted = combat.TryAttack(); task.wait(0.6)
		result = { accepted = accepted, plays = animation.GetLogicalPlayCount() - before }
	end
	driver:FireServer(id, result)
end)
