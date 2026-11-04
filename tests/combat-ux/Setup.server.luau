-- Test-only one-player Studio fixture, mapped only by combat-ux.project.json.
-- The phase bypass below deliberately permits local QA; production remains 5v5.
-- Stop Play to discard this fixture's world and progression changes.
assert(game:GetService("RunService"):IsStudio(), "Studio QA only")
assert(workspace:GetAttribute("CombatUXTestFixture") == true, "Use combat-ux.project.json")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local S = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match = require(S.MatchService)
local Teams = require(S.TeamService)
local Progression = require(S.HeroProgressionService)
local Learning = require(RS.Shared.Abilities.SkillLearning)
local Naruto = require(S.NarutoAbilityService)
local Fighters = require(S.FighterStateService)
local Damage = require(S.DamageService)
local Minions = require(S.MinionAIService)
local startupDeadline = os.clock() + 30
while true do
 local candidate = Players:GetPlayers()[1]
 local body = if candidate then candidate.Character else nil
 if candidate and candidate:FindFirstChild("HeroState") and body and body:FindFirstChild("HumanoidRootPart")
  and body:FindFirstChildOfClass("Humanoid") and body:GetAttribute("HeroAppearanceVersion") ~= nil
  and body:GetAttribute("CombatDisabled") == false and Match.GetState() and Naruto.Get(candidate) then break end
 assert(os.clock() < startupDeadline, "Combat UX setup timed out waiting for player, character, match and HeroState")
 task.wait(.05)
end
local player = Players:GetPlayers()[1]
assert(player, "Start Play with a local player first")
local model = player.Character
assert(model and model:FindFirstChild("HumanoidRootPart"), "Wait for character spawn")
local humanoid = model:FindFirstChildOfClass("Humanoid")
local root = model:FindFirstChild("HumanoidRootPart")
assert(humanoid and root:IsA("BasePart"), "Character not ready")
local state = Match.GetState()
assert(state and state.phase ~= "Finished", "Start a fresh play session")
assert(Teams.IsParticipant(player), "Local player must be assigned to the existing roster")
state.phase = "InProgress"
state.startedAt = workspace:GetServerTimeNow()
state.nextWaveAt = state.startedAt + 36000
state.preparationEnds = 0
Teams.LockRoster()
Damage.SetEnabled(true)
Minions.SetRunning(false)
for npc in Minions.GetAll() do Minions.Remove(npc) end
require(S.JungleService).Stop()
require(RS.Shared.Config.TowerConfig).Range = 0
require(S.TowerService).CancelAll()
Match.Publish()
require(S.AbilityService).Reset()

-- The QA deck is far from the production arena and has deterministic flat ground.
local old = workspace:FindFirstChild("CombatUXQA")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "CombatUXQA"
folder.Parent = workspace
local function part(name, size, position, color)
 local p = Instance.new("Part")
 p.Name = name; p.Size = size; p.Position = position; p.Color = color
 p.Anchored = true; p.Parent = folder
 return p
end
part("Floor", Vector3.new(160,2,160), Vector3.new(0,999,0), Color3.fromRGB(73,88,72))
part("CameraAndPathWall", Vector3.new(2,12,16), Vector3.new(10,1006,-16), Color3.fromRGB(110,116,126))
for _, item in model:GetChildren() do if item:IsA("ForceField") then item:Destroy() end end
root.Anchored = false
model:SetAttribute("CombatDisabled", false)
model:PivotTo(CFrame.new(0,1000+humanoid.HipHeight+root.Size.Y/2,0))
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero
root:SetNetworkOwnershipAuto()
humanoid.Health = humanoid.MaxHealth

Progression.AddXP(player,100000)
local profile = Progression.Get(player)
assert(profile, "Progression unavailable")
for _, id in Learning.Order do
 while Learning.reason(profile,id) == nil do assert(Learning.learn(profile,id)) end
end
Progression.Publish(player)
local session = Naruto.Get(player)
assert(session, "Naruto session unavailable")
Naruto.Update(workspace:GetServerTimeNow())
session.pool.mana = session.pool.maximum
session.nextPublish = 0
Naruto.Update(workspace:GetServerTimeNow())

local enemyTeam = if player:GetAttribute("TeamId") == "Blue" then "Red" else "Blue"
local function dummy(name, position)
 local dummyModel = Instance.new("Model")
 dummyModel.Name = name
 local body = Instance.new("Part")
 body.Name = "HumanoidRootPart"; body.Size = Vector3.new(2,4,2)
 body.CFrame = CFrame.new(position); body.Anchored = true; body.CanCollide = false
 body.Color = Color3.fromRGB(202,76,66); body.Parent = dummyModel
 local hp = Instance.new("Humanoid")
 hp.RequiresNeck = false; hp.EvaluateStateMachine = false
 hp.MaxHealth = 100000; hp.Health = 100000; hp.DisplayName = name
 hp.Parent = dummyModel; dummyModel.PrimaryPart = body
 dummyModel:SetAttribute("TeamId",enemyTeam)
 dummyModel:SetAttribute("RoundId",state.roundId)
 dummyModel:SetAttribute("EntityKind","Minion")
 dummyModel:SetAttribute("MinionType","Melee")
 dummyModel.Parent = folder
 Fighters.GetOrCreate(dummyModel)
 return dummyModel
end
dummy("NearTarget",Vector3.new(0,1002,-4))
dummy("FarTarget",Vector3.new(0,1002,-24))
dummy("BehindWallTarget",Vector3.new(20,1002,-16))
workspace:SetAttribute("CombatUXQAReady",true)
return {
 player=player.Name, character=model:GetFullName(), roundId=state.roundId,
 level=profile.Level, mana=session.pool.mana, ranks=profile.Learned,
 note="Studio-only QA deck; KCM/Kurama charge still follows production resource rules; stop Play to discard.",
}
