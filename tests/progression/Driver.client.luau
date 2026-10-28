--!strict
assert(game:GetService("RunService"):IsStudio())
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local driver = ReplicatedStorage:WaitForChild("ProgressionTestDriver") :: RemoteEvent
local shop = ReplicatedStorage:WaitForChild("ItemShop") :: RemoteEvent
local combat = ReplicatedStorage:WaitForChild("CombatRemotes"):WaitForChild("BasicAttack") :: RemoteEvent
local replies: { [number]: { success: boolean, reason: string } } = {}
shop.OnClientEvent:Connect(function(kind, id, success, reason)
 if kind == "Result" then replies[id] = { success = success, reason = reason } end
end)
local controller = require(player.PlayerScripts:WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("CombatController"))
driver.OnClientEvent:Connect(function(id: number, mode: string, request: number?, item: string?)
 local result: any = {}
 if mode == "attack" then combat:FireServer(controller.NextRequestId(), player.Character, ReplicatedStorage:WaitForChild("SurvivalState"):GetAttribute("RoundId")); task.wait(0.45)
 elseif mode == "buy" or mode == "forged" then
  assert(request and item)
  local roundId = ReplicatedStorage:WaitForChild("SurvivalState"):GetAttribute("RoundId")
  if mode == "forged" then shop:FireServer(request, item, 0, roundId) else shop:FireServer(request, item, roundId) end
  local deadline = os.clock() + 5
  repeat task.wait(0.03) until replies[request] ~= nil or os.clock() > deadline
  result = replies[request] or { success = false, reason = "NoReply" }
 elseif mode == "stats" then
  local state = player:FindFirstChild("HeroState")
  result = if state then state:GetAttributes() else {}
  result.hud = player.PlayerGui:FindFirstChild("HeroHUD") ~= nil
 end
 driver:FireServer(id, result)
end)
