--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.ProgressionConfig)
local Rules = require(Shared.Game.ProgressionRules).configure(Config, require(Shared.Config.ItemConfig).Items)
local Teams = require(script.Parent.TeamService)
local Economy = { GoldChanged = Instance.new("BindableEvent"), GoldSpent = Instance.new("BindableEvent") }
local balances: { [Player]: number } = {}
local function roundId(): number? local state = Teams.GetState(); return if state then state.roundId else nil end
function Economy.IsEligible(player: Player): boolean
 local state = Teams.GetState()
 local id = player:GetAttribute("TeamId")
 return player.Parent == game:GetService("Players") and state ~= nil and state.phase == "InProgress"
  and Teams.IsParticipant(player) and typeof(id) == "string" and Teams.IsActive(id) and player:GetAttribute("Eliminated") ~= true
end
function Economy.GetGold(player: Player): number return balances[player] or 0 end
function Economy.ResetPlayerEconomy(player: Player)
 balances[player] = Config.StartingGold; Economy.GoldChanged:Fire(player, Config.StartingGold, 0, "Reset", roundId())
end
function Economy.CanAfford(player: Player, amount: number): boolean
 return balances[player] ~= nil and Rules.validAmount(amount) and Economy.GetGold(player) >= amount
end
function Economy.AddGold(player: Player, amount: number, reason: string): number
 if not Economy.IsEligible(player) or balances[player] == nil then return 0 end
 local before = balances[player]
 local after = Rules.balanceAfter(before, amount, false); if not after then return 0 end
 balances[player] = after
 if after ~= before then Economy.GoldChanged:Fire(player, after, after - before, reason, roundId()) end
 return after - before
end
function Economy.SpendGold(player: Player, amount: number, reason: string): boolean
 if not Economy.IsEligible(player) or balances[player] == nil then return false end
 local before = balances[player]
 local after = Rules.balanceAfter(before, amount, true); if not after then return false end
 -- No yield between balance validation and commit.
 balances[player] = after; Economy.GoldChanged:Fire(player, after, after - before, reason, roundId())
 Economy.GoldSpent:Fire(player, amount, reason); return true
end
function Economy.Remove(player: Player) balances[player] = nil end
return Economy
