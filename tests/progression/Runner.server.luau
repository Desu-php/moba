--!strict
assert(game:GetService("RunService"):IsStudio())
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match = require(services.MatchService)
local Progression = require(services.HeroProgressionService)
local Economy = require(services.EconomyService)
local Stats = require(services.CharacterStatsService)
local Rewards = require(services.RewardService)
local Shop = require(services.ItemShopService)
local Damage = require(services.DamageService)
local Life = require(services.CombatLifeService)
local Fighters = require(services.FighterStateService)
local Spawner = require(services.MinionSpawnerService)
local AI = require(services.MinionAIService)
local Bases = require(services.BaseService)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.ProgressionConfig)
local Rules = require(Shared.Game.ProgressionRules).configure(Config, require(Shared.Config.ItemConfig).Items)
local driver = Instance.new("RemoteEvent"); driver.Name = "ProgressionTestDriver"; driver.Parent = ReplicatedStorage
local responses: { [Player]: { id: number, data: any } } = {}
driver.OnServerEvent:Connect(function(player: Player, id: number, data: any) responses[player] = { id = id, data = data } end)
local count, commandId, purchaseId = 0, 0, 0
local function check(name: string, value: boolean)
 assert(value, "FAIL: " .. name); count += 1; print("[ProgressionTests] PASS: " .. name)
end
local function untilTrue(predicate: () -> boolean, seconds: number, message: string)
 local deadline = os.clock() + seconds
 repeat if predicate() then return end; task.wait(0.03) until os.clock() >= deadline
 error(message)
end
local function command(player: Player, mode: string, request: number?, item: string?): any
 commandId += 1; local id = commandId; driver:FireClient(player, id, mode, request, item)
 untilTrue(function() return responses[player] ~= nil and responses[player].id == id end, 10, "Client did not reply: " .. mode)
 return responses[player].data
end
local function profile(player: Player)
 local p = Progression.Get(player); assert(p); return p
end
local function body(player: Player): (Model, Humanoid, BasePart)
 local model = player.Character; assert(model)
 local humanoid = model:FindFirstChildOfClass("Humanoid"); local root = model:FindFirstChild("HumanoidRootPart")
 assert(humanoid and root and root:IsA("BasePart")); return model, humanoid, root
end
local function arrange(player: Player, position: Vector3, face: Vector3?)
 local model, humanoid, root = body(player)
 for _, child in model:GetChildren() do
  if child:IsA("ForceField") or (child:IsA("Script") and child.Name == "Health") then child:Destroy() end
 end
 humanoid.AutoRotate = false; root:SetNetworkOwner(nil); root.AssemblyLinearVelocity = Vector3.zero
 root.CFrame = CFrame.lookAt(position, face or position + Vector3.new(0, 0, -1))
end
local function totalXP(player: Player): number
 local p = profile(player); local total = p.CurrentXP
 for level = 1, p.Level - 1 do total += Rules.required(level) end
 return total
end
local function buy(player: Player, id: string): (boolean, string)
 purchaseId += 1; return Shop.TryPurchase(player, purchaseId, id)
end
local function npc(team: string, kind: string, position: Vector3): (Model, Humanoid)
 local model = Spawner.Spawn(team, "Mid", kind, 2); assert(model)
 local record = AI.GetAll()[model]; record.root.CFrame = CFrame.new(position); record.root.Anchored = true
 return model, record.humanoid
end
local function cleanupNPCs()
 local list = {}; for model in AI.GetAll() do table.insert(list, model) end
 for _, model in list do AI.Remove(model) end
end
local ok, failure = xpcall(function()
 print("[ProgressionTests] Waiting for 3 clients...")
 untilTrue(function() return #Players:GetPlayers() == 3 and Match.GetState() ~= nil end, 120, "Start Server & Clients with 3")
 local state = Match.GetState(); assert(state)
 untilTrue(function() return state.phase == "InProgress" end, 30, "Match not started")
 local bluePlayers: { Player } = {}; local red: Player? = nil
 for _, player in Players:GetPlayers() do
  if player:GetAttribute("TeamId") == "Blue" then table.insert(bluePlayers, player) else red = player end
 end
 assert(#bluePlayers == 2 and red)
 table.sort(bluePlayers, function(a: Player, b: Player) return a.UserId > b.UserId end)
 local hero, assistant, victim = bluePlayers[1], bluePlayers[2], red :: Player
 untilTrue(function()
  return hero.Character ~= nil and assistant.Character ~= nil and victim.Character ~= nil
   and hero:FindFirstChild("HeroState") ~= nil
 end, 20, "Characters missing")
 task.wait(0.5)
 state.nextWaveAt = workspace:GetServerTimeNow() + 10000
 state.startedAt = workspace:GetServerTimeNow() + 10000; Rewards.Reset()
 AI.SetRunning(false); cleanupNPCs()
 -- Reset fixtures after all clients join; slow client startup may already earn passive gold.
 for _, player in Players:GetPlayers() do Progression.ResetPlayer(player) end
 task.wait(0.1)
 for _, player in Players:GetPlayers() do
  check("initial level and gold " .. player.Name, profile(player).Level == 1 and Economy.GetGold(player) == 100)
 end
 local client = command(hero, "stats")
 check("event HUD has server profile", client.hud == true and client.Level == 1 and client.Gold == 100 and client.MaxHealth == 100)
 arrange(hero, Vector3.new(0, 36, 0)); arrange(assistant, Vector3.new(10, 36, 0)); arrange(victim, Vector3.new(130, 36, 0))
 local heroModel, heroHumanoid = body(hero)
 local dead, deadHumanoid = npc("Red", "Melee", Vector3.new(5, 36, 0))
 local observedDeath: Life.Death? = nil
 local deathConnection = Life.Died.Event:Connect(function(event: Life.Death) if event.model == dead then observedDeath = event end end)
 check("melee lethal damage confirmed", Damage.Apply(heroModel, deadHumanoid, 100) == 100)
 untilTrue(function() return observedDeath ~= nil end, 3, "No lifecycle event after lethal hit")
 local death = observedDeath :: Life.Death
 check("death belongs to current round", death.roundId == state.roundId)
 check("last hit attributed to hero", death.killer ~= nil and death.killer.userId == hero.UserId)
 untilTrue(function() return profile(hero).TotalMinionKills == 1 end, 3, "No last hit reward")
 check("melee last hit gold", Economy.GetGold(hero) == 120)
 check("nearby allies get full XP", totalXP(hero) == 30 and totalXP(assistant) == 30)
 local gold = Economy.GetGold(hero)
 untilTrue(function() return observedDeath ~= nil end, 2, "No lifecycle event")
 Life.Died:Fire(observedDeath)
 Life.Register(dead); Damage.Apply(heroModel, deadHumanoid, 100); task.wait(0.1)
 check("same death never rewarded twice", Economy.GetGold(hero) == gold and profile(hero).TotalMinionKills == 1)
 deathConnection:Disconnect()
 local alliedNPC = npc("Blue", "Melee", Vector3.new(5, 36, 0))
 local _, rangedHealth = npc("Red", "Ranged", Vector3.new(6, 36, 0))
 Damage.Apply(alliedNPC, rangedHealth, 100)
 untilTrue(function() return totalXP(hero) == 70 end, 3, "NPC kill did not share XP")
 check("NPC last hit gives XP but no gold", totalXP(assistant) == 70 and Economy.GetGold(hero) == gold and Economy.GetGold(assistant) == 100)
 local _, allyHealth = npc("Blue", "Melee", Vector3.new(5, 36, 0))
 check("friendly damage cannot yield rewards", Damage.Apply(heroModel, allyHealth, 100) == 0 and allyHealth.Health == 100)
 arrange(assistant, Vector3.new(-150, 36, 80))
 local _, farHealth = npc("Red", "Melee", Vector3.new(5, 36, 0))
 Damage.Apply(heroModel, farHealth, 100)
 untilTrue(function() return profile(hero).TotalMinionKills == 2 end, 3, "Second last hit missing")
 check("XP radius excludes distant ally", totalXP(assistant) == 70)
 cleanupNPCs()
 Progression.ResetPlayer(hero); task.wait(0.1); heroHumanoid.Health = 50
 Progression.AddXP(hero, 450); task.wait(0.1)
 check("multiple levels and capped healing", profile(hero).Level == 4 and heroHumanoid.MaxHealth == 130 and heroHumanoid.Health == 80)
 check("M1 stat multiplier reflects level", math.abs(Stats.Get(hero).AttackDamageMultiplier - 1.06) < 0.0001)
 Progression.AddXP(hero, Config.MaxGrant); task.wait(0.1)
 check("max level stops XP", profile(hero).Level == 10 and profile(hero).CurrentXP == 0 and heroHumanoid.MaxHealth == 190)
 Progression.ResetPlayer(hero); task.wait(0.1)
 local ownShop = Shop.GetLocation("Blue"); local enemyShop = Shop.GetLocation("Red"); assert(ownShop and enemyShop)
 check("both generated shops have prompts", ownShop:FindFirstChildOfClass("ProximityPrompt") ~= nil and enemyShop:FindFirstChildOfClass("ProximityPrompt") ~= nil)
 arrange(hero, ownShop.Position + Vector3.new(0, 2, -5)); Shop.ResetSessions()
 local bought, reason = buy(hero, "IronBlade")
 check("insufficient funds refused", not bought and reason == "NotEnoughGold" and Economy.GetGold(hero) == 100)
 Economy.AddGold(hero, 1000, "Test")
 Shop.ResetSessions()
 local remoteBuy = command(hero, "buy", 1000, "IronBlade")
 check("real remote buys blade", remoteBuy.success == true and profile(hero).Owned.IronBlade == true and Economy.GetGold(hero) == 900)
 local forged = command(hero, "forged", 1001, "GuardianArmor")
 check("client supplied price rejected", not forged.success and forged.reason == "Malformed" and Economy.GetGold(hero) == 900)
 Shop.ResetSessions(); gold = Economy.GetGold(hero)
 bought, reason = buy(hero, "IronBlade")
 check("duplicate equipment refused", not bought and reason == "Purchased" and Economy.GetGold(hero) == gold)
 Shop.ResetSessions()
 local successes, completed = 0, 0
 for _ = 1, 2 do task.spawn(function()
  if buy(hero, "GuardianArmor") then successes += 1 end
  completed += 1
 end) end
 untilTrue(function() return completed == 2 end, 2, "Transactions did not finish")
 check("concurrent requests charge once", successes == 1 and Economy.GetGold(hero) == gold - 200)
 task.wait(0.1)
 check("armor adds HP without free healing", heroHumanoid.MaxHealth == 140 and heroHumanoid.Health == 100)
 local fighter = Fighters.GetOrCreate(heroModel); assert(fighter)
 Fighters.Stun(fighter, 0.65, false); Shop.ResetSessions(); bought = buy(hero, "SwiftBoots")
 check("boots purchase preserves stun", bought and heroHumanoid.WalkSpeed == 0)
 task.wait(0.8)
 check("stun restores upgraded speed", heroHumanoid.WalkSpeed == 18)
 for _ = 1, 10 do Stats.RecalculateStats(hero) end
 check("stats cannot stack on recalculation", heroHumanoid.MaxHealth == 140 and heroHumanoid.WalkSpeed == 18 and math.abs(Stats.Get(hero).AttackDamageMultiplier - 1.15) < 0.0001)
 heroHumanoid.Health = 50; Shop.ResetSessions(); bought = buy(hero, "HealingPotion")
 check("potion heals exactly sixty", bought and heroHumanoid.Health == 110)
 Shop.ResetSessions(); bought = buy(hero, "HealingPotion")
 check("potion clamps to max", bought and heroHumanoid.Health == 140)
 gold = Economy.GetGold(hero); Shop.ResetSessions(); bought, reason = buy(hero, "HealingPotion")
 check("full health potion does not charge", not bought and reason == "FullHealth" and Economy.GetGold(hero) == gold)
 arrange(hero, enemyShop.Position + Vector3.new(0, 2, -4)); Shop.ResetSessions(); bought, reason = buy(hero, "HealingPotion")
 check("enemy shop refused by server distance", not bought and reason == "TooFar")
 arrange(hero, Vector3.new(0, 36, 0)); Shop.ResetSessions(); bought, reason = buy(hero, "HealingPotion")
 check("remote purchase outside base refused", not bought and reason == "TooFar")
 check("negative gold and NaN rejected", Economy.AddGold(hero, -100, "Test") == 0 and not Economy.SpendGold(hero, 0/0, "Test") and Economy.GetGold(hero) == gold)
 arrange(hero, ownShop.Position + Vector3.new(0, 2, -5)); Shop.ResetSessions(); heroHumanoid.Health = 10
 Economy.ResetPlayerEconomy(hero); purchaseId += 1
 bought = Shop.TryPurchase(hero, purchaseId, "HealingPotion")
 local second, repeatReason = Shop.TryPurchase(hero, purchaseId, "HealingPotion")
 check("potion request replay cannot double-spend", bought and not second and repeatReason == "Replay" and Economy.GetGold(hero) == 0)
 Shop.ResetSessions()
 for i = 1, 20 do Shop.TryPurchase(hero, purchaseId + i, {}) end
 local _, floodReason = buy(hero, "IronBlade")
 check("malformed flood rate limited", floodReason == "RateLimited")
 local base = Bases.Get("Red"); assert(base)
 -- Open the core before the unchanged blade/base regression; tower rewards have their own suite.
 for _, tower in require(services.TowerService).GetAll() do
  if tower.structure.teamId == "Red" then Damage.Apply(heroModel, tower.structure.humanoid, 9999) end
 end
 task.wait(0.2)
 arrange(hero, base.root.Position + Vector3.new(-4.5, 0, 0), base.root.Position)
 task.wait(1.3); local hp = base.humanoid.Health; command(hero, "attack")
 check("real M1 uses blade multiplier", math.abs(base.humanoid.Health - (hp - 5.75)) < 0.01)
 -- Reset only test profiles, then isolate hero kill + assistant.
 for _, player in Players:GetPlayers() do Progression.ResetPlayer(player) end
 task.wait(0.1); Shop.ResetSessions()
 arrange(victim, enemyShop.Position + Vector3.new(0, 2, -5)); Economy.AddGold(victim, 100, "Test")
 check("victim equipment setup", buy(victim, "SwiftBoots"))
 Progression.AddXP(victim, 125); task.wait(0.1)
 local victimModel, victimHumanoid = body(victim)
 local victimGold, victimXP = Economy.GetGold(victim), totalXP(victim)
 arrange(hero, Vector3.new(0, 36, 0)); arrange(assistant, Vector3.new(8, 36, 0)); arrange(victim, Vector3.new(0, 36, -4))
 local assistantModel = body(assistant)
 Damage.Apply(assistantModel, victimHumanoid, 10); Damage.Apply(assistantModel, victimHumanoid, 10)
 Damage.Apply(heroModel, victimHumanoid, 1000)
 untilTrue(function() return profile(hero).TotalKills == 1 end, 3, "Hero kill not rewarded")
 check("hero killer XP and gold", totalXP(hero) == 150 and Economy.GetGold(hero) == 200)
 check("assist paid once", profile(assistant).Assists == 1 and totalXP(assistant) == 50 and Economy.GetGold(assistant) == 125)
 check("killer not also assistant", profile(hero).Assists == 0)
 check("death retains XP gold equipment", profile(victim).TotalDeaths == 1 and totalXP(victim) == victimXP and Economy.GetGold(victim) == victimGold and profile(victim).Owned.SwiftBoots == true)
 untilTrue(function() return victim.Character ~= nil and victim.Character ~= victimModel end, 12, "No respawn")
 task.wait(0.5)
 local nextModel, nextHumanoid, nextRoot = body(victim)
 check("respawn uses level and equipment", nextHumanoid.MaxHealth == 110 and nextHumanoid.Health == 110 and nextHumanoid.WalkSpeed == 18 and nextRoot.Position.X > 140)
 check("respawn has new life identity", nextModel:GetAttribute("LifeId") ~= victimModel:GetAttribute("LifeId"))
 arrange(victim, Vector3.new(0, 36, -4)); Damage.Apply(heroModel, nextHumanoid, 5)
 nextHumanoid.Health = 0
 untilTrue(function() return profile(hero).TotalKills == 2 end, 3, "Recent hit not credited after environment death")
 check("environment death credits recent attacker", profile(hero).TotalKills == 2)
 check("team scoreboard counts confirmed hero kills", Rewards.GetTeamKills(tostring(hero:GetAttribute("TeamId"))) == 2)
 check("old life assist never reused", profile(assistant).Assists == 1)
 task.wait(0.2)
 client = command(hero, "stats")
 check("HUD replicates XP gold KDA and health", client.hud == true and client.Level == profile(hero).Level and client.Gold == Economy.GetGold(hero) and client.TotalKills == 2)
 state.startedAt = workspace:GetServerTimeNow() - Config.PassiveInterval
 Rewards.Reset(); gold = Economy.GetGold(hero); Rewards.Update(workspace:GetServerTimeNow())
 check("passive income tick", Economy.GetGold(hero) == gold + 5)
 Rewards.Update(workspace:GetServerTimeNow())
 check("passive tick not duplicated", Economy.GetGold(hero) == gold + 5)
 Damage.Apply(heroModel, base.humanoid, 10000)
 untilTrue(function() return state.phase == "Finished" end, 3, "Match failed to finish")
 local endedGold, endedXP = Economy.GetGold(hero), totalXP(hero)
 Rewards.Update(workspace:GetServerTimeNow() + 100); Economy.AddGold(hero, 100, "Late"); Progression.AddXP(hero, 100)
 check("finished match freezes rewards", Economy.GetGold(hero) == endedGold and totalXP(hero) == endedXP)
 Shop.ResetSessions(); bought, reason = buy(victim, "HealingPotion")
 check("eliminated team cannot shop", not bought and reason == "Unavailable")
 check("finished match cannot spend", not Economy.SpendGold(hero, 1, "Late"))
 Match.ResetProgression(); task.wait(0.1)
 check("reset API clears progression and equipment", profile(hero).Level == 1 and profile(hero).CurrentXP == 0 and next(profile(hero).Owned) == nil and profile(hero).TotalKills == 0 and Economy.GetGold(hero) == 100)
 check("reset API restores base stats", Stats.Get(hero).MaxHealth == 100 and Stats.Get(hero).WalkSpeed == 16)
 assistant:Kick("Progression test: cleanup")
 untilTrue(function() return assistant.Parent ~= Players and Progression.Get(assistant) == nil end, 5, "Profile leaked")
 check("departure clears match data", Economy.GetGold(assistant) == 0)
 print("[ProgressionTests] ALL PASS: " .. count .. " integration checks")
 workspace:SetAttribute("ProgressionTestsPassed", count)
 return "passed"
end, function(message) return debug.traceback(tostring(message), 2) end)
if not ok then warn("[ProgressionTests] FAILED after " .. count .. ": " .. tostring(failure)) end
