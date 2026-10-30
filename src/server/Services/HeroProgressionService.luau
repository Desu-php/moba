--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.ProgressionConfig)
local Items = require(Shared.Config.ItemConfig)
local Logic = require(Shared.Game.ProgressionRules)
local Rules = Logic.configure(Config, Items.Items)
local Economy = require(script.Parent.EconomyService)
local Teams = require(script.Parent.TeamService)
local Learning = require(Shared.Abilities.SkillLearning)
local Progression = { Changed = Instance.new("BindableEvent") }
local records: { [Player]: Logic.Profile } = {}
local folders: { [Player]: Folder } = {}
local notice: RemoteEvent? = nil
local started = false
function Progression.Get(player: Player): Logic.Profile? return records[player] end
function Progression.GetFolder(player: Player): Folder? return folders[player] end
function Progression.Notify(player: Player, xp: number, gold: number, levels: number)
 local match = Teams.GetState()
 if notice and player.Parent == Players and match then notice:FireClient(player, xp, gold, levels, match.roundId) end
end
function Progression.Publish(player: Player)
 local data, folder = records[player], folders[player]; if not data or not folder then return end
 for _, key in { "Level", "CurrentXP", "TotalKills", "TotalDeaths", "TotalMinionKills", "Assists" } do
  folder:SetAttribute(key, (data :: any)[key])
 end
 folder:SetAttribute("SkillPoints", data.SkillPoints)
 for _, id in Learning.Order do
  folder:SetAttribute("Rank_"..id, data.Learned[id] or 0)
  folder:SetAttribute("LearnReason_"..id, Learning.reason(data,id) or "Ready")
 end
 folder:SetAttribute("XPToNextLevel", Rules.required(data.Level)); folder:SetAttribute("Gold", Economy.GetGold(player))
 for id in Items.Items do folder:SetAttribute("Own_" .. id, data.Owned[id] == true) end
 folder:SetAttribute("Revision", ((folder:GetAttribute("Revision") or 0) :: number) + 1)
end
function Progression.ResetPlayer(player: Player)
 records[player] = Rules.new(); Economy.ResetPlayerEconomy(player)
 local match = Teams.GetState()
 Progression.Publish(player); Progression.Changed:Fire(player, "Reset", 0, if match then match.roundId else nil)
end
function Progression.ResetMatch()
 for _, player in Players:GetPlayers() do Progression.ResetPlayer(player) end
end
function Progression.AddXP(player: Player, amount: number): number
 local data = records[player]; if not data or not Economy.IsEligible(player) then return 0 end
 local levels, accepted = Rules.addXP(data, amount)
 if accepted > 0 then
  local match = Teams.GetState()
  Progression.Publish(player); Progression.Changed:Fire(player, "XP", levels, if match then match.roundId else nil)
  Progression.Notify(player, accepted, 0, levels)
 end
 return levels
end
function Progression.Increment(player: Player, key: string)
 local data = records[player]; if not data or not Economy.IsEligible(player) then return end
 if key == "TotalKills" then data.TotalKills += 1
 elseif key == "TotalDeaths" then data.TotalDeaths += 1
 elseif key == "TotalMinionKills" then data.TotalMinionKills += 1
 elseif key == "Assists" then data.Assists += 1 else return end
 Progression.Publish(player)
end
function Progression.Equip(player: Player, id: string): boolean
 local data, item = records[player], Items.Items[id]
 if not data or not item or not item.Permanent or data.Owned[id] or not Economy.IsEligible(player) then return false end
 data.Owned[id] = true
 local match = Teams.GetState()
 Progression.Publish(player); Progression.Changed:Fire(player, "Equipment", 0, if match then match.roundId else nil); return true
end
function Progression.Start()
 if started then return end; started = true
 notice = Instance.new("RemoteEvent"); notice.Name = "HeroNotice"; notice.Parent = game:GetService("ReplicatedStorage")
 Economy.GoldChanged.Event:Connect(function(player: Player, _balance: number, delta: number, reason: string, roundId: number?)
  local match = Teams.GetState(); if match and roundId ~= match.roundId then return end
  Progression.Publish(player)
  if delta > 0 and reason ~= "Reset" then Progression.Notify(player, 0, delta, 0) end
 end)
 local function add(player: Player)
  local folder = Instance.new("Folder"); folder.Name = "HeroState"; folder.Parent = player; folders[player] = folder
  Progression.ResetPlayer(player)
 end
 Players.PlayerAdded:Connect(add)
 Players.PlayerRemoving:Connect(function(player)
  records[player] = nil; Economy.Remove(player)
  if folders[player] then folders[player]:Destroy(); folders[player] = nil end
 end)
 for _, player in Players:GetPlayers() do add(player) end
end
return Progression
