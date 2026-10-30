--!strict
assert(game:GetService("RunService"):IsStudio())
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match = require(services.MatchService)
local Ability = require(services.AbilityService)
local Native = require(services.NarutoAbilityService)
local Summons = require(services.NarutoSummonService)
local Fighters = require(services.FighterStateService)
local Combat = require(services.CombatService)
local Damage = require(services.DamageService)
local Progression = require(services.HeroProgressionService)
local Stats = require(services.CharacterStatsService)
local AI = require(services.MinionAIService)
local RigJoints = require(ReplicatedStorage:WaitForChild("Shared").Combat.RigJoints)
local driver = Instance.new("RemoteEvent"); driver.Name = "HeroTestDriver"; driver.Parent = ReplicatedStorage
local responses: { [Player]: { id: number, data: any } } = {}
driver.OnServerEvent:Connect(function(player: Player, id: number, data: any) responses[player] = { id = id, data = data } end)
local count, commandId, requestId, m1Id = 0, 0, 1000, 1000
local targets: { Model } = {}
local fixtureStarted = os.clock()
local quick = workspace:GetAttribute("NarutoQuickFixture") == true
local finishEvents, trailEvents = 0, 0
local firstTrailAt = math.huge
Native.Visual.Event:Connect(function(message: any)
	if message.kind=="RasenganFinish" then finishEvents+=1
	elseif message.kind=="RasenganTrail" then trailEvents+=1; firstTrailAt=math.min(firstTrailAt,workspace:GetServerTimeNow()) end
end)
local function check(name: string, value: boolean) assert(value, "FAIL: " .. name); count += 1; print("[HeroTests] PASS: " .. name) end
local function untilTrue(predicate: () -> boolean, seconds: number, message: string)
	local deadline = os.clock() + seconds
	repeat if predicate() then return end; task.wait(0.01) until os.clock() >= deadline
	error(message)
end
local function command(player: Player, mode: string, data: any): any
	commandId += 1; local id = commandId; driver:FireClient(player, id, mode, data)
	untilTrue(function() return responses[player] ~= nil and responses[player].id == id end, 10, "No client response: " .. mode)
	return responses[player].data
end
local function body(player: Player): (Model, Humanoid, BasePart)
	local model = player.Character; assert(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid"); local root = model:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and root:IsA("BasePart")); return model, humanoid, root
end
local function arrange(player: Player, at: Vector3)
	local model, humanoid, root = body(player)
	for _, item in model:GetChildren() do if item:IsA("ForceField") or (item:IsA("Script") and item.Name == "Health") then item:Destroy() end end
	root.Anchored = false; root:SetNetworkOwner(nil); root.CFrame = CFrame.new(at)
	root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero; humanoid.AutoRotate = false
end
local function target(team: string, at: Vector3, kind: string?): (Model, Humanoid, BasePart)
	local model = Instance.new("Model"); model.Name = "NarutoFixture"
	local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2, 4, 2); root.Anchored = true; root.CFrame = CFrame.new(at); root.Parent = model
	local humanoid = Instance.new("Humanoid"); humanoid.MaxHealth = 1000; humanoid.Health = 1000; humanoid.Parent = model
	model.PrimaryPart = root; model:SetAttribute("TeamId", team); model:SetAttribute("EntityKind", kind or "Minion")
	model:SetAttribute("MinionType", "Melee"); model:SetAttribute("RoundId", (Match.GetState() :: any).roundId)
	model.Parent = workspace; Fighters.GetOrCreate(model); table.insert(targets, model)
	return model, humanoid, root
end
local function cast(player: Player, id: string, aim: any?): (boolean, string)
	requestId += 1
	if aim ~= nil then return Ability.TryCast(player, requestId, player.Character, id, aim) end
	return Ability.TryCast(player, requestId, player.Character, id)
end
local function attack(player: Player): string m1Id += 1; return Combat.TryAttack(player, m1Id, player.Character) end
local function clean()
	Ability.Reset()
	for _, model in targets do Fighters.Remove(model); model:Destroy() end; table.clear(targets)
	task.wait(1.2)
end
local ok, failure = xpcall(function()
	untilTrue(function() return #Players:GetPlayers() == 2 and Match.GetState() ~= nil end, 120, "Use Server & Clients -> 2")
	local state = Match.GetState(); assert(state)
	if quick and state.phase~="InProgress" then state.phase="Preparing"; state.preparationEnds=0 end -- Test-build setup only.
	untilTrue(function() return state.phase == "InProgress" end, 40, "Match not started")
	local first, second: Player? = nil, nil
	for _, player in Players:GetPlayers() do if player:GetAttribute("TeamId") == "Blue" then first = player else second = player end end
	assert(first and second); local a, b = first :: Player, second :: Player
	untilTrue(function() return a.Character ~= nil and b.Character ~= nil and a.Character:GetAttribute("HeroAppearanceVersion") ~= nil end, 20, "Appearance not ready")
	state.startedAt = workspace:GetServerTimeNow() + 10000; state.nextWaveAt = workspace:GetServerTimeNow() + 10000
	require(ReplicatedStorage.Shared.Config.TowerConfig).Range = 0
	require(services.TowerService).CancelAll() -- Isolate ability fixtures from unrelated tower shots.
	AI.SetRunning(false); for model in AI.GetAll() do AI.Remove(model) end
	task.wait(0.2)
	check("clone commands activate after lobby without manual reset", (Native.Get(a) :: any).commands.active and (Native.Get(b) :: any).commands.active)
	clean(); arrange(a, Vector3.new(0, 36, 0)); arrange(b, Vector3.new(80, 36, 0))
	local model, humanoid, root = body(a)
	check("R15 and Naruto appearance preserved", humanoid.RigType == Enum.HumanoidRigType.R15 and model:FindFirstChild("HeroAppearance") ~= nil and #RigJoints.Collect(model) >= 15)
	local hud = command(a, "hud", {})
	check("hero ability and match HUD exist", hud.hero and hud.abilities and hud.match)
	local prediction = command(a, "prediction", {})
	check("M1 prediction plays once", prediction.accepted and prediction.plays == 1)
	check("unverified future buttons disabled", hud.gamakichi == false and hud.sage == false and hud.kcm == false)
	local initial = Native.Get(a); assert(initial)
	check("native inference marked provisional", model:GetAttribute("NativeStatsProvisional") == true)
	check("inferred level1 max mana1510", initial.pool.maximum == 1510)
	check("unlearned Q cannot cast", select(2, cast(a, "Rasengan")) == "Unlearned")
	Progression.AddXP(a, 2700); Progression.AddXP(b, 2700) -- Keep the existing level10 damage fixture, cap coverage lives in LearningTests.
 for _, player in {a,b} do
  local learning=require(services.AbilityLearningService); local character=player.Character :: Model
  assert(learning.HandleRequest(player,1,character,character:GetAttribute("LifeId"),"Rasengan",state.roundId))
  assert(learning.HandleRequest(player,2,character,character:GetAttribute("LifeId"),"ShadowClones",state.roundId))
 end
	model:SetAttribute("StrengthBonus", 2); (b.Character :: Model):SetAttribute("StrengthBonus", 2)
	check("source integer STR input fixture30", select(2, Native.GetStats(a)) == 30 and Stats.Get(a).Level == 10)
	clean(); arrange(a,Vector3.new(0,36,0)); target("Blue",Vector3.new(0,36,-4))
	assert(cast(a,"Rasengan"))
	check("first variant second allows ordinary explicit M1",attack(a)=="Started")
	task.wait(1.12)
	local visual = command(a,"presentation",{offset=1.12})
	check("one helper and preparation pose before hand light " .. game:GetService("HttpService"):JSONEncode(visual),visual.helper==true and visual.orb==false and visual.key=="RasenganPrepare" and visual.elapsed<1.5)
	task.wait(.45); visual=command(a,"presentation",{})
	check("right hand sphere appears before preparation finishes",visual.helper==true and visual.orb==true)
	task.wait(.55); visual=command(a,"presentation",{})
	check("helper poofs while sphere stays for free movement",visual.helper==false and visual.orb==true and humanoid.WalkSpeed==Stats.Get(a).WalkSpeed)
	clean(); arrange(a, Vector3.new(0, 36, 0)); arrange(b, Vector3.new(80, 36, 0))
	local _, hp, victimRoot = target("Red", Vector3.new(1, 36, -4))
	local before = (Native.Get(a) :: any).pool.mana
	requestId += 1; local response = command(a, "cast", { requestId, model, "Rasengan" })
	check("real client Q accepted", response.accepted == true)
	check("Q spends100 once", math.abs((Native.Get(a) :: any).pool.mana - (before - 100)) < 1)
	check("no immediate spell damage", hp.Health == 1000)
	task.wait(1.2); check("Q self-stun blocks M1 in second preparation second", attack(a) == "Rejected")
	check("ordinary cast cannot be repeated", not cast(a, "Rasengan"))
	task.wait(1.0)
	check("Q holds without auto damage", hp.Health == 1000 and model:GetAttribute("RasenganHeld") == true and (Native.Get(a) :: any).q.active.phase == "Holding")
	local contactAt=workspace:GetServerTimeNow(); local contactPosition=victimRoot.Position
	check("held Q admits M1", attack(a) == "Started")
	task.wait(0.2)
	local victim = Fighters.Get(hp.Parent :: Model); assert(victim)
	check("source3.5s spell stun not M1 .8 clamp", victim.logic.stunUntil - workspace:GetServerTimeNow() > 3)
	check("spell damage waits1sec", hp.Health == 1000)
	check("caster faces chosen target and pauses",root.CFrame.LookVector:Dot(((victimRoot.Position-root.Position)*Vector3.new(1,0,1)).Unit)>.999 and humanoid.WalkSpeed==0)
	check("initial push is slow and has no endpoint effect",(victimRoot.Position-contactPosition).Magnitude<1 and finishEvents==0)
	task.wait(1.05)
	check("raw250 ignores physical level multiplier", math.abs(hp.Health - 750) < 0.001)
	check("caster released before target stun ends",humanoid.WalkSpeed==Stats.Get(a).WalkSpeed and victim.logic.stunUntil>workspace:GetServerTimeNow()+2)
	check("endpoint effect waits for fast push",finishEvents==0)
	local fastPosition=victimRoot.Position
	task.wait(.85)
	check("fast push travels farther and ends with one effect",(victimRoot.Position-fastPosition).Magnitude>5 and finishEvents==1)
	check("trail starts in fast phase",trailEvents>0 and firstTrailAt>=contactAt+1)
	local endPosition=victimRoot.Position; task.wait(.15)
	check("push ends after two phases",(victimRoot.Position-endPosition).Magnitude<.001)
	check("held marker clears after impact", model:GetAttribute("RasenganHeld") == false)
	check("Q cooldown retained", (Native.Get(a) :: any).q.cooldownAt > workspace:GetServerTimeNow() + 50)
	check("Q replay rejected", select(2, Ability.TryCast(a, requestId, model, "Rasengan")) == "Replay")
	if quick then
		clean(); print(string.format("[RasenganFast] ALL PASS: %d checks in %.2fs (cold client setup included)",count,os.clock()-fixtureStarted))
		workspace:SetAttribute("RasenganFastPassed",count); return "passed"
	end
	clean(); arrange(a, Vector3.new(0, 36, 0))
	local _, currentHp = target("Red", Vector3.new(0, 36, -4))
	assert(cast(a, "Rasengan")); task.wait(2.2); assert(attack(a) == "Started"); task.wait(0.2)
	model:SetAttribute("StrengthBonus", 22); task.wait(1.05)
	check("STR resolved at impact", math.abs(currentHp.Health - 730) < 0.001); model:SetAttribute("StrengthBonus", 2)
	clean(); arrange(a, Vector3.new(0, 36, 0))
	local _, unused = target("Red", Vector3.new(0, 36, -4))
	assert(cast(a, "Rasengan")); task.wait(15.2)
	check("unused held Q expires without damage", unused.Health == 1000 and model:GetAttribute("RasenganHeld") == false)
	check("expiry keeps source60 cooldown", (Native.Get(a) :: any).q.cooldownAt > workspace:GetServerTimeNow() + 40)
	clean(); arrange(a, Vector3.new(0, 36, 0))
	local ally, alliedHp = target("Blue", Vector3.new(0, 36, -4))
	assert(cast(a, "Rasengan")); task.wait(2.2); assert(attack(a) == "Started"); task.wait(0.4)
	check("allied attack does not consume Q", alliedHp.Health == 1000 and (Native.Get(a) :: any).q.active.phase == "Holding")
	ally:Destroy(); clean(); arrange(a, Vector3.new(0, 36, 0))
	humanoid.MaxHealth = 1000; humanoid.Health = 1000
	local resourceBefore = (Native.Get(a) :: any).pool.mana
	assert(cast(a, "ShadowClones")); task.wait(0.3)
	check("W makes3 rank1 clones", Summons.GetCount() == 3)
	check("W charges200 once", math.abs((Native.Get(a) :: any).pool.mana - resourceBefore + 200) < 1)
	local sample: any = nil; for _, record in Summons.GetAll() do sample = record; break end; assert(sample)
	check("illusion max/current HP copied without .05 reduction", sample.humanoid.MaxHealth == 1000 and sample.humanoid.Health == 1000)
	check("illusion is a damageable fighter", Fighters.Get(sample.model) ~= nil)
	local enemy = b.Character :: Model
	check("incoming damage is20x", Damage.Apply(enemy, sample.humanoid, 1) == 20)
	check("allied damage rejected", Damage.Apply(model, sample.humanoid, 1) == 0)
	local _, probe = target("Red", Vector3.new(20, 36, -20))
	check("ordinary clone outgoing exactly .30", Damage.Apply(sample.model, probe, 10) == 3 and probe.Health == 997)
	local beforeKills = (Progression.Get(a) :: any).TotalMinionKills
	Damage.Apply(sample.model, probe, 9999)
	untilTrue(function() return (Progression.Get(a) :: any).TotalMinionKills == beforeKills + 1 end, 2, "Clone kill not credited to owner")
	check("clone last hit credits original owner", (Progression.Get(a) :: any).TotalMinionKills == beforeKills + 1)
	check("completed clones retain20s expiry", sample.clone.expiresAt - workspace:GetServerTimeNow() > 19)
	local _, idleHp = target("Red", Vector3.new(0, 36, -4)); task.wait(0.4)
	check("clones follow rather than auto-seek", idleHp.Health == 1000)
	local idleModel = idleHp.Parent :: Model
	local picking = command(a,"targetPicker",idleModel)
	check("selection reproduces original friendly-clone ray interception: " .. tostring(picking.originalHit),picking.originalRayHitsFriendly)
	check("selection reaches enemy behind friendly clones",picking.enemySelected)
	check("selection does not bypass solid walls",picking.wallBlocks)
	check("hostile clones remain selectable",picking.enemyCloneSelectable)
	check("command mode guards selection clicks from M1",picking.commandGuard)
	check("explicit target command admitted", cast(a, "CloneCommand", idleModel))
	untilTrue(function() return idleHp.Health < 1000 end, 3, "Clones did not assist commanded enemy")
	task.wait(0.4)
	check("command produces real clone damage", idleHp.Health < 1000)
	check("group command belongs only to owner", (Native.Get(b) :: any).commands.commandedTarget == nil)
	check("rank1 enemy W branch unavailable", select(2, cast(a, "ShadowClones", idleModel)) == "UnsupportedTarget")
	assert(cast(a, "Rasengan")); task.wait(2.2)
	local noRetrofit = true; for _, record in Summons.GetAll() do noRetrofit = noRetrofit and not record.clone.hasPayload end
	check("W then Q does not retrofit payload", noRetrofit)
	task.wait(math.max(0, sample.clone.expiresAt - workspace:GetServerTimeNow()) + 0.3)
	check("20-second summons expire in world", Summons.GetCount() == 0)
	clean(); arrange(a, Vector3.new(0, 36, 0)); local _, payloadHp = target("Red", Vector3.new(0, 36, -4))
	assert(cast(a, "Rasengan")); task.wait(2.2); assert(cast(a, "ShadowClones")); task.wait(0.3)
	local kept = false
	for _, record in Summons.GetAll() do
		check("fresh clone carries Q payload", record.clone.hasPayload)
		if kept then record.model:PivotTo(CFrame.new(100, 36, 0)) else record.model:PivotTo(CFrame.new(0, 36, -1)); kept = true end
	end
	assert(cast(a, "CloneCommand", payloadHp.Parent)); task.wait(0.3)
	check("clone payload49 plus .30 basic hit", math.abs(payloadHp.Health - (1000 - 49 - 5 * Stats.Get(a).AttackDamageMultiplier * 0.3)) < 0.01)
	local payloadFighter = Fighters.Get(payloadHp.Parent :: Model); assert(payloadFighter)
	check("clone payload adds no original stun", payloadFighter.logic.mode == "Idle")
	check("owner Q remains held after clone payload", (Native.Get(a) :: any).q.active.phase == "Holding")
	clean(); arrange(a, Vector3.new(0, 36, 0)); arrange(b, Vector3.new(80, 36, 0))
	local _, aHp = target("Red", Vector3.new(0, 36, -4)); local _, bHp = target("Blue", Vector3.new(80, 36, -4))
	assert(cast(a, "Rasengan")); assert(cast(b, "Rasengan")); task.wait(2.2)
	assert(attack(a) == "Started"); assert(attack(b) == "Started"); task.wait(1.3)
	print("[HeroTests] simultaneous HP", aHp.Health, bHp.Health)
	check("two Narutos keep independent targets/damage", math.abs(aHp.Health - 750) < 0.001 and math.abs(bHp.Health - 750) < 0.001)
	clean(); arrange(a, Vector3.new(0, 36, 0)); local _, deathHp = target("Red", Vector3.new(0, 36, -4))
	assert(cast(a, "Rasengan")); task.wait(2.2); assert(attack(a) == "Started"); task.wait(0.2); humanoid.Health = 0
	task.wait(1.2); check("death cancels pending spell damage", deathHp.Health == 1000)
	untilTrue(function() return a.Character ~= nil and a.Character ~= model and a.Character:GetAttribute("HeroAppearanceVersion") ~= nil end, 12, "Respawn failed")
	local oldModel = model; model, humanoid, root = body(a)
	check("respawn clears markers and refills provisional mana", model:GetAttribute("RasenganHeld") == false and math.abs((Native.Get(a) :: any).pool.mana - (Native.Get(a) :: any).pool.maximum) < 0.01)
	check("old character packet rejected", not Ability.TryCast(a, requestId + 1, oldModel, "Rasengan")); requestId += 1
	clean(); arrange(a, Vector3.new(0, 36, 0))
	requestId += 1; response = command(a, "cast", { requestId, b.Character, "Rasengan" })
	check("forged character rejected over network", response.accepted == false and response.reason == "Malformed")
	task.wait(0.4); requestId += 1; response = command(a, "cast", { requestId, model, "Rasengan", 999 })
	check("client supplied damage rejected", response.accepted == false and response.reason == "Malformed")
	task.wait(0.4)
	for _, id in { "Gamakichi", "SageMode", "KCM" } do check(id .. " server disabled", not cast(a, id)); task.wait(0.4) end
	check("NaN packet rejected", not Ability.TryCast(a, 0/0, model, "Rasengan"))
	check("infinite packet rejected", not Ability.TryCast(a, math.huge, model, "ShadowClones"))
	for _ = 1, 30 do requestId += 1; Ability.TryCast(a, requestId, model, "Unknown") end
	check("ability flood limited", select(2, cast(a, "ShadowClones")) == "RateLimited")
	clean(); local _, resetHp = target("Red", root.Position + Vector3.new(0, 0, -4))
	assert(cast(a, "Rasengan")); task.wait(2.2); assert(attack(a) == "Started"); task.wait(0.2); Ability.Reset(); task.wait(1.2)
	check("reset cancels delayed damage and summons", resetHp.Health == 1000 and Summons.GetCount() == 0 and (Native.Get(a) :: any).q.active == nil)
	check("reset clears source cooldowns", (Native.Get(a) :: any).q.cooldownAt == 0 and (Native.Get(a) :: any).clones.cooldownAt == 0)
	check("removed palm rejected by server", not cast(a, "WindPalm"))
	clean()
	assert(cast(b, "ShadowClones"))
	untilTrue(function() return Summons.GetCount() > 0 end, 2, "Burst did not start")
	local created = Summons.GetCount(); local _, bh = body(b); bh.Health = 0; task.wait(0.3)
	check("death stops unfinished burst without purging completed illusions", Summons.GetCount() > 0 and Summons.GetCount() <= created and (Native.Get(b) :: any).clones.burst == nil)
	b:Kick("Naruto test: cleanup"); untilTrue(function() return Native.Get(b) == nil end, 5, "Source session leaked")
	check("disconnect clears source state", Native.Get(b) == nil)
	print("[HeroTests] ALL PASS: " .. count .. " integration checks")
	workspace:SetAttribute("HeroTestsPassed", count)
	return "passed"
end, function(message) return debug.traceback(tostring(message), 2) end)
if not ok then warn("[HeroTests] FAILED after " .. count .. ": " .. tostring(failure)) end
