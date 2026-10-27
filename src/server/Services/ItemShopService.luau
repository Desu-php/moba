--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.ProgressionConfig)
local Items = require(Shared.Config.ItemConfig)
local Rules = require(Shared.Game.ProgressionRules).configure(Config, Items.Items)
local Progression = require(script.Parent.HeroProgressionService)
local Economy = require(script.Parent.EconomyService)
local Stats = require(script.Parent.CharacterStatsService)
local Limiter = require(script.Parent.RequestLimiter)
type Session = { bucket: Limiter.Bucket, lastId: number, busy: boolean }
local Shop = {}
local shops: { [string]: BasePart } = {}
local sessions: { [Player]: Session } = {}
local remote: RemoteEvent? = nil
local started = false
function Shop.GetLocation(teamId: string): BasePart? return shops[teamId] end
function Shop.Availability(player: Player): (Humanoid?, string?)
 if not Economy.IsEligible(player) then return nil, "Unavailable" end
 local model = player.Character
 local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
 local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
 if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return nil, "Dead" end
 local id = player:GetAttribute("TeamId")
 local shop = if typeof(id) == "string" then shops[id] else nil
 if not shop or not shop:IsDescendantOf(workspace) then return nil, "Unavailable" end
 local distance = (root.Position - shop.Position).Magnitude
 if distance ~= distance or distance > Config.ShopDistance then return nil, "TooFar" end
 return humanoid, nil
end
function Shop.TryPurchase(player: Player, ...: any): (boolean, string)
 if player.Parent ~= Players then return false, "Unavailable" end
 local now = workspace:GetServerTimeNow()
 local session = sessions[player]
 if not session then session = { bucket = Limiter.new(Config.ShopBurst, Config.ShopRequestsPerSecond, now), lastId = 0, busy = false }; sessions[player] = session end
 if not Limiter.Consume(session.bucket, now) then return false, "RateLimited" end
 local requestId, itemId = ...
 if select("#", ...) ~= 2 or typeof(requestId) ~= "number" or requestId ~= requestId or requestId < 1
  or requestId > Config.MaxRequestId or requestId % 1 ~= 0 or typeof(itemId) ~= "string" or #itemId > 48 then return false, "Malformed" end
 if requestId <= session.lastId then return false, "Replay" end
 session.lastId = requestId
 if not Items.Items[itemId] then return false, "UnknownItem" end
 if session.busy then return false, "Busy" end
 session.busy = true
 -- Entire transaction is non-yielding, including all server validation and mutations.
 local function transaction(): (boolean, string)
  local humanoid, reason = Shop.Availability(player)
  if not humanoid then return false, reason or "Unavailable" end
  local profile = Progression.Get(player); if not profile then return false, "Unavailable" end
  reason = Rules.purchaseReason(profile, Economy.GetGold(player), itemId, humanoid.Health, humanoid.MaxHealth)
  if reason then return false, reason end
  local item = Items.Items[itemId]
  if not Economy.SpendGold(player, item.Cost, "Purchase:" .. itemId) then return false, "NotEnoughGold" end
  if item.Permanent then
   assert(Progression.Equip(player, itemId), "Validated equipment transaction failed")
   Stats.RecalculateStats(player)
  elseif item.Heal then
   humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + item.Heal)
  end
  return true, "Purchased"
 end
 local ok, success, reason = pcall(transaction)
 session.busy = false
 if not ok then warn("[Shop] " .. tostring(success)); return false, "Unavailable" end
 return success, reason
end
function Shop.ResetSessions() table.clear(sessions) end
function Shop.Start(arena: Folder)
 if started then return end; started = true
 remote = Instance.new("RemoteEvent"); remote.Name = "ItemShop"; remote.Parent = ReplicatedStorage
 local locations = arena:FindFirstChild("Shops"); assert(locations, "Map.Shops missing")
 for _, part in locations:GetChildren() do
  if not part:IsA("BasePart") then continue end
  local id = part:GetAttribute("TeamId"); assert(typeof(id) == "string", "Shop needs TeamId")
  shops[id] = part
  local prompt = part:FindFirstChildOfClass("ProximityPrompt"); assert(prompt, "Shop needs ProximityPrompt")
  prompt.Triggered:Connect(function(player)
   local humanoid = Shop.Availability(player)
   if humanoid and player:GetAttribute("TeamId") == id and remote then remote:FireClient(player, "Open") end
  end)
 end
 ;(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ...: any)
  local requestId = ...
  local success, reason = Shop.TryPurchase(player, ...)
  -- Invalid floods receive no amplification; well-formed requests get a bounded response.
  if typeof(requestId) == "number" and requestId == requestId and requestId >= 1 and requestId <= Config.MaxRequestId
   and reason ~= "RateLimited" and remote then remote:FireClient(player, "Result", requestId, success, reason) end
 end)
 Players.PlayerRemoving:Connect(function(player) sessions[player] = nil end)
end
return Shop
