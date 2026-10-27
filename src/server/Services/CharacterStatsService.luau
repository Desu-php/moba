--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.ProgressionConfig)
local Logic = require(Shared.Game.ProgressionRules)
local Rules = Logic.configure(Config, require(Shared.Config.ItemConfig).Items)
local Progression = require(script.Parent.HeroProgressionService)
local Fighters = require(script.Parent.FighterStateService)
local Stats = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local healthConnections: { [Player]: RBXScriptConnection } = {}
local applied: { [Player]: Model } = {}
local started = false
function Stats.Get(player: Player): Logic.Stats
 return Rules.stats(Progression.Get(player) or Rules.new())
end
function Stats.GetForModel(model: Model): Logic.Stats?
 local player = Players:GetPlayerFromCharacter(model)
 return if player and Progression.Get(player) then Stats.Get(player) else nil
end
function Stats.RecalculateStats(player: Player, fullHealth: boolean?, healing: number?)
 local model = player.Character; local profile = Progression.Get(player)
 if not model or not profile then return end
 local humanoid = model:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
 local values = Stats.Get(player); local before = humanoid.Health
 humanoid.MaxHealth = values.MaxHealth
 if before > 0 then humanoid.Health = if fullHealth then values.MaxHealth else math.min(values.MaxHealth, before + (healing or 0)) end
 Fighters.SetWalkSpeed(model, values.WalkSpeed)
 local folder = Progression.GetFolder(player)
 if folder then
  local fields: { [string]: number } = { MaxHealth = values.MaxHealth, WalkSpeed = values.WalkSpeed,
   AttackDamageMultiplier = values.AttackDamageMultiplier, Defense = values.Defense, Level = values.Level }
  for key, value in fields do folder:SetAttribute(key, value) end
  folder:SetAttribute("CurrentHealth", humanoid.Health)
 end
end
local function bind(player: Player, model: Model)
 task.spawn(function()
  local humanoid = model:WaitForChild("Humanoid", 10)
  if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= model or player.Parent ~= Players or applied[player] == model then return end
  applied[player] = model
  if healthConnections[player] then healthConnections[player]:Disconnect() end
  healthConnections[player] = humanoid.HealthChanged:Connect(function(health)
   local folder = Progression.GetFolder(player); if folder then folder:SetAttribute("CurrentHealth", health) end
  end)
  Stats.RecalculateStats(player, true)
 end)
end
function Stats.Start()
 if started then return end; started = true
 Progression.Changed.Event:Connect(function(player: Player, reason: string, levels: number)
  Stats.RecalculateStats(player, reason == "Reset", levels * Config.LevelHeal)
 end)
 local function add(player: Player)
  connections[player] = {
   player.CharacterAdded:Connect(function(model) bind(player, model) end),
   player.CharacterRemoving:Connect(function()
    if healthConnections[player] then healthConnections[player]:Disconnect(); healthConnections[player] = nil end
    applied[player] = nil
   end),
  }
  if player.Character then bind(player, player.Character) end
 end
 Players.PlayerAdded:Connect(add)
 Players.PlayerRemoving:Connect(function(player)
  for _, c in connections[player] or {} do c:Disconnect() end
  if healthConnections[player] then healthConnections[player]:Disconnect() end
  healthConnections[player] = nil; connections[player] = nil; applied[player] = nil
 end)
 for _, player in Players:GetPlayers() do add(player) end
end
return Stats
