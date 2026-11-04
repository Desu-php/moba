--!strict
-- Insert during solo Studio Play with RunCloneAutonomyQA=true. Restart Play afterward.
if not game:GetService("RunService"):IsStudio() or workspace:GetAttribute("RunCloneAutonomyQA") ~= true then return end
local S = game.ServerScriptService.Server.Services
local Shared = game.ReplicatedStorage.Shared
local Summons = require(S.NarutoSummonService)
local Fighters = require(S.FighterStateService)
local Native = require(S.NarutoAbilityService)
local Commands = require(Shared.Abilities.CloneCommands)
local W = require(Shared.Abilities.CloneState).configure(require(Shared.Abilities.NarutoDefinitions).Clones)
local player = game:GetService("Players"):GetPlayers()[1]
assert(player and player.Character)
local character = player.Character
local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
local session = Native.Get(player); assert(session)
local folder = Instance.new("Folder"); folder.Name = "CloneAutonomyQA"; folder.Parent = workspace
local targets: { Model } = {}
local checks = {}
local saved = root.CFrame
local function check(name: string, ok: boolean) assert(ok, name); table.insert(checks, name) end
local function waitFor(fn: () -> boolean, seconds: number, label: string)
	local finish = os.clock() + seconds
	repeat if fn() then return end; task.wait(.05) until os.clock() >= finish
	error("Timeout: " .. label)
end
local function order(name: string)
	assert(Commands.order(session.commands, session.commands.ownerId, session.commands.round, session.life, session.commands.lastRequest + 1, name))
end
local function enemy(name: string, x: number, z: number, ally: boolean): (Model, Humanoid)
	local model = Instance.new("Model"); model.Name = name
	local part = Instance.new("Part"); part.Name = "HumanoidRootPart"; part.Size = Vector3.new(2, 2, 1)
	part.Position = Vector3.new(x, 503, z); part.Anchored = true; part.CollisionGroup = "SurvivalMinions"; part.Parent = model
	local hp = Instance.new("Humanoid"); hp.RequiresNeck = false; hp.MaxHealth = 100000; hp.Health = 100000; hp.Parent = model
	model.PrimaryPart = part; model:SetAttribute("EntityKind", "Minion")
	model:SetAttribute("TeamId", if ally then character:GetAttribute("TeamId") else (if character:GetAttribute("TeamId") == "Red" then "Blue" else "Red"))
	model:SetAttribute("RoundId", character:GetAttribute("RoundId")); model.Parent = folder
	Fighters.GetOrCreate(model); table.insert(targets, model)
	return model, hp
end
local function spawn(count: number, y: number): { Model }
	Summons.ClearOwner(player); root.CFrame = CFrame.new(0, y, 0)
	session.clones.burst = nil; session.clones.cooldownAt = 0
	local now = workspace:GetServerTimeNow()
	local burst = W.begin(session.clones, now, session.clones.lastRequest + 1, count, 0); assert(burst)
	local models = {}
	for index = 1, count do
		local clone = W.spawnOne(session.clones, burst, now + index * .02, true, false); assert(clone)
		local model = Summons.Spawn(player, character, session.clones, clone, session.commands); assert(model); table.insert(models, model)
	end
	return models
end
local ok, message = pcall(function()
	root.Anchored = true
	local floor = Instance.new("Part"); floor.Size = Vector3.new(200, 2, 200); floor.Position = Vector3.new(0, 499, 0); floor.Anchored = true; floor.Parent = folder
	order("Hold")
	local models = spawn(3, 515)
	local initialY = (models[1].PrimaryPart :: BasePart).Position.Y
	task.wait(.15)
	check("airborne clones descend instead of freezing", (models[1].PrimaryPart :: BasePart).Position.Y < initialY - .2)
	waitFor(function()
		for _, model in models do if model:GetAttribute("SummonGrounded") ~= true then return false end end
		return true
	end, 2, "all airborne clones land while holding")
	for _, model in models do check("clone feet land on floor", math.abs((model.PrimaryPart :: BasePart).Position.Y - 503) < .1) end
	root.CFrame = CFrame.new(0, 503, 0)
	local nearest, nearestHp = enemy("NearestEnemy", 12, 0, false)
	local distant, distantHp = enemy("OtherEnemy", 23, 0, false)
	local _, allyHp = enemy("Ally", 3, 0, true)
	order("Follow")
	waitFor(function() return nearestHp.Health < nearestHp.MaxHealth end, 6, "automatic nearest enemy attack")
	check("automatic acquisition needs no owner attack or F", nearestHp.Health < nearestHp.MaxHealth)
	check("allies are not attacked", allyHp.Health == allyHp.MaxHealth)
	check("nearest enemy chosen before distant enemy", distantHp.Health == distantHp.MaxHealth)
	assert(Commands.command(session.commands, session.commands.ownerId, session.commands.round, session.life, session.commands.lastRequest + 1, Summons.EntityId(distant), true))
	waitFor(function() return distantHp.Health < distantHp.MaxHealth end, 4, "manual target overrides nearest")
	check("F overrides automatic target", distantHp.Health < distantHp.MaxHealth)
	order("Hold"); task.wait(.15)
	local hpBefore = nearestHp.Health + distantHp.Health
	local held = (models[1].PrimaryPart :: BasePart).Position
	task.wait(.7)
	check("Hold prevents attacks and horizontal movement", hpBefore == nearestHp.Health + distantHp.Health and ((models[1].PrimaryPart :: BasePart).Position - held).Magnitude < .05)
	order("Follow")
	waitFor(function() return nearestHp.Health + distantHp.Health < hpBefore end, 5, "automatic combat resumes after recall")
	nearestHp.Health = 0; distantHp.Health = 0
	local replacement, replacementHp = enemy("ReplacementEnemy", 18, 8, false)
	waitFor(function() return replacementHp.Health < replacementHp.MaxHealth end, 4, "dead target reacquired")
	check("clones acquire another enemy after target death", replacementHp.Health < replacementHp.MaxHealth)
	-- A fresh cast keeps the leash check independent of the normal 20-second lifetime.
	order("Hold"); models = spawn(3, 503); root.CFrame = CFrame.new(-65, 503, 0); order("Follow")
	local before = ((models[1].PrimaryPart :: BasePart).Position - root.Position).Magnitude
	task.wait(1.2)
	check("recall returns clones toward owner instead of distant enemy", ((models[1].PrimaryPart :: BasePart).Position - root.Position).Magnitude < before - 8)
	check("leash prevents remote automatic combat", models[1]:GetAttribute("SummonBehavior") == "Return")
	Fighters.Remove(replacement); replacement:Destroy(); Fighters.Remove(nearest); nearest:Destroy(); Fighters.Remove(distant); distant:Destroy()
	-- Autonomous sensing does not see through solid scenery; explicit orders still route around it.
	local wall = Instance.new("Part"); wall.Size = Vector3.new(2, 8, 16); wall.Position = Vector3.new(8, 504, 0); wall.Anchored = true; wall.Parent = folder
	local hidden, hiddenHp = enemy("BehindWall", 14, 0, false)
	local visible, visibleHp = enemy("VisibleEnemy", -18, 0, false)
	order("Follow"); models = spawn(3, 503)
	waitFor(function() return visibleHp.Health < visibleHp.MaxHealth end, 5, "visible enemy chosen around blocked enemy")
	check("automatic targeting excludes enemy behind wall", hiddenHp.Health == hiddenHp.MaxHealth)
	Fighters.Remove(visible); visible:Destroy()
	assert(Commands.command(session.commands, session.commands.ownerId, session.commands.round, session.life, session.commands.lastRequest + 1, Summons.EntityId(hidden), true))
	waitFor(function() return hiddenHp.Health < hiddenHp.MaxHealth end, 10, "path around wall")
	check("explicit order routes around wall and attacks", hiddenHp.Health < hiddenHp.MaxHealth)
	Fighters.Remove(hidden); hidden:Destroy(); wall:Destroy()
	-- Thirty clones are a test-only cast count; production rank/lifetime settings stay intact.
	order("Follow"); models = spawn(30, 515); root.CFrame = CFrame.new(0, 503, 0)
	enemy("MassTargetA", 14, -12, false); enemy("MassTargetB", 14, 0, false); enemy("MassTargetC", 14, 12, false)
	task.wait(7)
	local landed, attacking = 0, 0
	for _, model in models do
		if model:GetAttribute("SummonGrounded") == true then landed += 1 end
		if typeof(model:GetAttribute("SummonSwingAt")) == "number" then attacking += 1 end
	end
	check("all thirty airborne clones land", landed == 30)
	check("mass clones reach automatic combat", attacking >= 6)
end)
Summons.ClearOwner(player)
for _, target in targets do Fighters.Remove(target); target:Destroy() end
root.CFrame = saved; root.Anchored = false; root.AssemblyLinearVelocity = Vector3.zero
folder:Destroy(); order("Follow")
workspace:SetAttribute("CloneAutonomyQAResult", game:GetService("HttpService"):JSONEncode({ ok = ok, checks = checks, error = if ok then nil else tostring(message) }))
assert(ok, tostring(message)); print("PASS clone autonomy: " .. #checks .. " checks")
