--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ledger = require(Shared.Game.RewardLedger)
local Config = require(Shared.Config.ProgressionConfig)
local Structures = require(Shared.Game.StructureRules)
export type Death = { lifeId: number, roundId: number?, model: Model, victimUserId: number?, teamId: string, kind: string, minionType: string,
 position: Vector3, killer: Ledger.Actor?, assists: { Ledger.Actor } }
type Life = { id: number, model: Model, humanoid: Humanoid, ledger: Ledger.Ledger, scheduled: boolean, onDeath: (() -> ())?, connections: { RBXScriptConnection } }
local LifeService = { Died = Instance.new("BindableEvent") }
local lives: { [Model]: Life } = {}
local serial, generation = 0, 0
function LifeService.Remove(model: Model)
 local life = lives[model]; if not life then return end
 for _, connection in life.connections do connection:Disconnect() end
 lives[model] = nil
end
function LifeService.Register(model: Model)
	if lives[model] or Structures.isStructure(model:GetAttribute("EntityKind")) or model:GetAttribute("EntityKind") == "Summon" then return end
 local humanoid = model:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
 serial += 1
 local life: Life = { id = serial, model = model, humanoid = humanoid, ledger = Ledger.new(), scheduled = false, connections = {} }
 lives[model] = life; model:SetAttribute("LifeId", serial)
 local function died()
  if life.scheduled then return end; life.scheduled = true
  local time = workspace:GetServerTimeNow()
  local position = model:GetPivot().Position
  local epoch = generation
  -- Defer until Damage.Apply has recorded the confirmed lethal damage.
  task.defer(function()
   if epoch ~= generation then return end
   local claimed, killer, assists = Ledger.claim(life.ledger, math.max(time, workspace:GetServerTimeNow()), Config.AttributionWindow)
   if not claimed then return end
   local player = Players:GetPlayerFromCharacter(model)
   local death: Death = { lifeId = life.id, roundId = model:GetAttribute("RoundId") :: number?, model = model, victimUserId = if player then player.UserId else nil,
    teamId = tostring(model:GetAttribute("TeamId") or ""), kind = tostring(model:GetAttribute("EntityKind") or ""),
    minionType = tostring(model:GetAttribute("MinionType") or ""), position = position, killer = killer, assists = assists }
   LifeService.Died:Fire(death)
  end)
 end
 life.onDeath = died
 table.insert(life.connections, humanoid.Died:Connect(died))
 table.insert(life.connections, model.AncestryChanged:Connect(function()
  if not model:IsDescendantOf(workspace) then LifeService.Remove(model) end
 end))
 if humanoid.Health <= 0 then died() end
end
function LifeService.Record(attacker: Model, victim: Model)
 LifeService.Register(victim)
 local life = lives[victim]; if not life then return end
 local player = Players:GetPlayerFromCharacter(attacker)
 if not player and attacker:GetAttribute("NativeNarutoClone") == true then
  local owner = attacker:GetAttribute("SummonOwner")
  if typeof(owner) == "number" then player = Players:GetPlayerByUserId(owner) end
 end
 local actor: Ledger.Actor = { userId = if player then player.UserId else nil, teamId = tostring(attacker:GetAttribute("TeamId") or "") }
 Ledger.record(life.ledger, actor, tostring(victim:GetAttribute("TeamId") or ""), workspace:GetServerTimeNow())
 -- A freshly spawned Humanoid can reach zero HP before its first physics step
 -- without firing Died. Confirm death after recording the lethal hit; the same
 -- scheduled flag deduplicates the later engine event.
 if life.humanoid.Health <= 0 and life.onDeath then life.onDeath() end
end
function LifeService.ResetHistory()
 generation += 1
 for _, life in lives do life.ledger = Ledger.new() end
end
function LifeService.Reset()
 generation += 1
 for model in lives do LifeService.Remove(model) end
end
Players.PlayerRemoving:Connect(function(player)
 for _, life in lives do Ledger.forget(life.ledger, player.UserId) end
 if player.Character then LifeService.Remove(player.Character) end
end)
return LifeService
