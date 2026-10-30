assert(game:GetService("RunService"):IsStudio(), "Manual fixture is Studio-only")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match = require(services.MatchService)
repeat task.wait(.1) until Match.GetState() and Match.GetState().phase == "InProgress"
local state = Match.GetState(); state.startedAt = workspace:GetServerTimeNow()+10000; state.nextWaveAt = workspace:GetServerTimeNow()+10000
require(RS.Shared.Config.TowerConfig).Range = 0
require(services.TowerService).CancelAll()
local AI = require(services.MinionAIService); AI.SetRunning(false); for model in AI.GetAll() do AI.Remove(model) end
for index,p in Players:GetPlayers() do
 repeat task.wait(.1) until p.Character and p.Character:GetAttribute("HeroAppearanceVersion")
 require(services.HeroProgressionService).AddXP(p,450)
 local c=p.Character; c:PivotTo(CFrame.new((index-1)*12,36,0)); c.HumanoidRootPart:SetNetworkOwner(p)
 local t=Instance.new("Model"); t.Name="ManualEnemy"..p.Name
 local r=Instance.new("Part"); r.Name="HumanoidRootPart"; r.Size=Vector3.new(4,5,3); r.Anchored=true; r.Color=Color3.new(1,.2,.2); r.CFrame=CFrame.new((index-1)*12,36,-5); r.Parent=t
 local h=Instance.new("Humanoid"); h.MaxHealth=10000; h.Health=10000; h.Parent=t; t.PrimaryPart=r
 t:SetAttribute("TeamId",if p:GetAttribute("TeamId")=="Blue" then "Red" else "Blue"); t:SetAttribute("EntityKind","Minion"); t:SetAttribute("RoundId",state.roundId); t.Parent=workspace
 require(services.FighterStateService).GetOrCreate(t)
end
print("[ManualUI] Ready: press Q/1, walk with W, use2 for clones and F/HUD command")
