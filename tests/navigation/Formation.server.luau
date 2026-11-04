--!strict
-- Insert during solo Studio Play with RunCloneFormationQA=true. Restart Play afterward.
if not game:GetService("RunService"):IsStudio() or workspace:GetAttribute("RunCloneFormationQA") ~= true then return end
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
local folder = Instance.new("Folder"); folder.Name = "CloneFormationQA"; folder.Parent = workspace
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
local metrics = {}
local ok, message = pcall(function()
 root.Anchored = true
 local floor = Instance.new("Part"); floor.Size = Vector3.new(200, 2, 200); floor.Position = Vector3.new(0, 499, 0); floor.Anchored = true; floor.Parent = folder
 local damage = require(S.DamageService)
 local struck: { [Model]: boolean } = {}
 local sectors: { [Model]: { [number]: boolean } } = {}
 local connection = damage.Applied.Event:Connect(function(attacker: Model, target: Model)
  local record = Summons.GetAll()[attacker]
  if record and target.PrimaryPart then
   struck[attacker] = true
   local d = record.root.Position - target.PrimaryPart.Position
   local sector = math.floor((math.atan2(d.Z, d.X) + math.pi) / (math.pi / 4)) % 8
   if not sectors[target] then sectors[target] = {} end
   sectors[target][sector] = true
  end
 end)
 local function participants(models: { Model }): number
  local count = 0; for _, model in models do if struck[model] then count += 1 end end; return count
 end
 order("Follow")
 local a, _ = enemy("FormationA", 16, -16, false)
 local b, _ = enemy("FormationB", 23, 0, false)
 local c, _ = enemy("FormationC", 16, 16, false)
 local models = spawn(30, 503)
 workspace:SetAttribute("CloneFormationQAPhase", "Three targets")
 task.wait(14)
 local spread: { [string]: number } = {}
 local coverage: { [string]: number } = {}
 local minimum = math.huge
 for i, model in models do
  local record = Summons.GetAll()[model]
  if record and record.assignedTarget then
   local name = record.assignedTarget.Name; spread[name] = (spread[name] or 0) + 1
  end
  for j = i + 1, #models do
   if model.PrimaryPart and models[j].PrimaryPart then
    minimum = math.min(minimum, (model.PrimaryPart.Position - (models[j].PrimaryPart :: BasePart).Position).Magnitude)
   end
  end
 end
 for target, angles in sectors do local count = 0; for _ in angles do count += 1 end; coverage[target.Name] = count end
 metrics.multi = { participants = participants(models), spread = spread, coverage = coverage, minimumSpacing = minimum }
 check("thirty clones all participate across three enemies", participants(models) == 30)
 for _, target in { a, b, c } do
  check("balanced target " .. target.Name, (spread[target.Name] or 0) >= 7 and (spread[target.Name] or 0) <= 12)
  check("surround target " .. target.Name, (coverage[target.Name] or 0) >= 4)
 end
 check("crowd bodies stay separated", minimum >= 2.2)
 local deadHumanoid = a:FindFirstChildOfClass("Humanoid") :: Humanoid
 deadHumanoid.Health = 0
 local movedRoot = b.PrimaryPart :: BasePart
 movedRoot.Position += Vector3.new(0, 0, 3)
 task.wait(1)
 for _, record in Summons.GetAll() do check("dead target reservation released", record.assignedTarget ~= a) end
 for _, target in { a, b, c } do Fighters.Remove(target); target:Destroy() end
 struck = {}; sectors = {}
 local solo, _ = enemy("SingleTarget", 14, 0, false)
 order("Follow"); models = spawn(30, 503)
 assert(Commands.command(session.commands, session.commands.ownerId, session.commands.round, session.life, session.commands.lastRequest + 1, Summons.EntityId(solo), true))
 workspace:SetAttribute("CloneFormationQAPhase", "One target rotation")
 task.wait(18)
 metrics.single = { participants = participants(models) }
 check("every clone gets a turn against one commanded enemy", participants(models) == 30)
 connection:Disconnect()
end)
workspace:SetAttribute("CloneFormationQAMetrics", game:GetService("HttpService"):JSONEncode(metrics))
Summons.ClearOwner(player)
for _, target in targets do Fighters.Remove(target); target:Destroy() end
root.CFrame = saved; root.Anchored = false; root.AssemblyLinearVelocity = Vector3.zero
folder:Destroy(); order("Follow")
workspace:SetAttribute("CloneFormationQAResult", game:GetService("HttpService"):JSONEncode({ ok = ok, checks = checks, error = if ok then nil else tostring(message) }))
assert(ok, tostring(message)); print("PASS clone formations: " .. #checks .. " checks")
