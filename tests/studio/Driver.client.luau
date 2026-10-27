--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local driver = ReplicatedStorage:WaitForChild("CombatTestDriver") :: RemoteEvent
local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local attack = remotes:WaitForChild("BasicAttack") :: RemoteEvent
local events = remotes:WaitForChild("CombatEvent") :: RemoteEvent
local controllers = player.PlayerScripts:WaitForChild("Client"):WaitForChild("Controllers")
local controller = require(controllers.CombatController)
local animations = require(controllers.AnimationController)
local vfx = require(controllers.VFXController)
controller.Start()
local ownStarts, otherStarts, stuns, hits = 0, 0, 0, 0
events.OnClientEvent:Connect(function(message)
	local snapshot = message.snapshot
	if not snapshot then return end
	if message.kind == "Started" then
		if snapshot.character == player.Character then ownStarts += 1 else otherStarts += 1 end
	elseif message.kind == "State" and snapshot.character == player.Character and snapshot.mode == "Stunned" then
		stuns += 1
	elseif message.kind == "Hit" then
		hits += 1
	end
end)

driver.OnClientEvent:Connect(function(sequence: number, mode: string)
	local sent = 0
	local playsBefore = animations.GetLogicalPlayCount()
	local function raw()
		local id = controller.NextRequestId()
		attack:FireServer(id, player.Character)
		sent += 1
		return id
	end
	if mode == "malformed" then
		attack:FireServer(controller.NextRequestId(), player.Character, { damage = 1000000 })
		attack:FireServer(controller.NextRequestId(), CFrame.new())
		attack:FireServer(controller.NextRequestId(), nil)
		attack:FireServer(0 / 0, player.Character)
		attack:FireServer(math.huge, player.Character)
		attack:FireServer({ step = 4, damage = 1000000 })
	elseif mode == "replay" then
		local id = raw()
		attack:FireServer(id, player.Character)
	elseif mode == "controller" or mode == "controllerBurst" then
		for _ = 1, if mode == "controllerBurst" then 20 else 1 do
			if controller.TryAttack() then sent += 1 end
		end
	elseif mode == "buffer" then
		if controller.TryAttack() then sent += 1 end
		task.wait(0.26)
		if controller.TryAttack() then sent += 1 end
	elseif mode == "vfxCap" then
		local character = player.Character
		if character then
			for _ = 1, 100 do vfx.Hit(character, character:GetPivot().Position, false) end
		end
	elseif mode ~= "stats" then
		for _ = 1, if mode == "burst" then 50 else 1 do raw() end
	end
	if mode == "controller" or mode == "controllerBurst" then task.wait(0.2) end
	driver:FireServer(sequence, {
		sent = sent, plays = animations.GetLogicalPlayCount() - playsBefore,
		totalPlays = animations.GetLogicalPlayCount(),
		ownStarts = ownStarts, otherStarts = otherStarts, stuns = stuns, hits = hits,
		activeEffects = vfx.GetActiveCount(), localStep = controller.GetDiagnostics().comboStep,
	})
end)
driver:FireServer(0, {})
