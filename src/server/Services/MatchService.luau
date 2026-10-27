--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameModeConfig)
local MinionConfig = require(Shared.Config.MinionConfig)
local Rules = require(Shared.Game.MatchState)
local Mode = require(script.Parent.GameModeService)
local Builder = require(script.Parent.MapBuilder)
local Teams = require(script.Parent.TeamService)
local Bases = require(script.Parent.BaseService)
local Damage = require(script.Parent.DamageService)
local AI = require(script.Parent.MinionAIService)
local Spawner = require(script.Parent.MinionSpawnerService)
local Progression = require(script.Parent.HeroProgressionService)
local Stats = require(script.Parent.CharacterStatsService)
local Rewards = require(script.Parent.RewardService)
local Shop = require(script.Parent.ItemShopService)
local MatchService = {}
local state: Rules.State? = nil
local folder: Folder? = nil
local nextAI, nextSnapshot, nextDiagnostics = 0, 0, 0
function MatchService.GetState(): Rules.State? return state end
function MatchService.ResetProgression()
	assert(not state or state.phase ~= "InProgress", "Reset progression only between matches")
	Progression.ResetMatch(); Rewards.Reset(); Shop.ResetSessions()
end
function MatchService.Publish()
	local current, replicated = state, folder
	if not current or not replicated then return end
	replicated:SetAttribute("Phase", current.phase); replicated:SetAttribute("StartedAt", current.startedAt)
	replicated:SetAttribute("FinishedAt", current.finishedAt); replicated:SetAttribute("Winner", current.winner or "")
	replicated:SetAttribute("Wave", current.wave); replicated:SetAttribute("ActiveNPCs", AI.GetCount())
	replicated:SetAttribute("PreparationEnds", current.preparationEnds); replicated:SetAttribute("MinimumPlayers", Mode.MinimumPlayers())
	for id, team in current.teams do
		local item = replicated:FindFirstChild(id)
		local base = Bases.Get(id)
		if item and base then
			item:SetAttribute("Active", team.active); item:SetAttribute("Health", base.humanoid.Health)
			item:SetAttribute("MaxHealth", base.humanoid.MaxHealth)
		end
	end
end
local function eliminate(id: string)
	local current = state; if not current then return end
	if not Rules.eliminate(current, id, workspace:GetServerTimeNow()) then return end
	Teams.Eliminate(id); AI.RemoveTeam(id)
	if current.phase == "Finished" then
		Damage.SetEnabled(false); AI.SetRunning(false); Teams.Finish()
		print("[Match] Winner: " .. (current.winner or "Draw"))
	end
	MatchService.Publish()
end
function MatchService.Start()
	if state then return end
	Damage.SetEnabled(false)
	local arena = Builder.Build()
	local effects = workspace:FindFirstChild("Effects")
	assert(not effects or effects:IsA("Folder"), "Workspace.Effects must be a Folder")
	if not effects then local created = Instance.new("Folder"); created.Name = "Effects"; created.Parent = workspace end
	local initial = Rules.new(Mode.TeamIds()); state = initial
	Progression.Start(); Stats.Start(); Rewards.Start()
	Teams.Start(initial, arena); Bases.Start(arena); Spawner.Start(arena)
	Shop.Start(arena)
	local replicated = Instance.new("Folder"); replicated.Name = "SurvivalState"
	for _, definition in Config.Teams do
		local item = Instance.new("Folder"); item.Name = definition.Id
		item:SetAttribute("Color", definition.Color); item.Parent = replicated
	end
	local shots = Instance.new("RemoteEvent"); shots.Name = "MinionShot"; shots.Parent = replicated
	AI.Shot.Event:Connect(function(origin: Vector3, target: Vector3, kind: string, id: string, model: Model)
		shots:FireAllClients(origin, target, kind, id, model)
	end)
	replicated.Parent = ReplicatedStorage; folder = replicated
	Bases.Destroyed.Event:Connect(eliminate)
	MatchService.Publish()
	RunService.Heartbeat:Connect(function()
		local current = state; if not current then return end
		local now = workspace:GetServerTimeNow()
		Teams.Update(now)
		if Rules.advance(current, now, #Players:GetPlayers(), Mode.MinimumPlayers(), Config.PreparationTime, MinionConfig.FirstWaveDelay) then
			if current.phase == "InProgress" then Damage.SetEnabled(true); AI.SetRunning(true) end
			MatchService.Publish()
		end
		if Rules.waveDue(current, now, MinionConfig.WaveInterval) then Spawner.Wave(current.wave); MatchService.Publish() end
		if now >= nextAI then
			nextAI = now + MinionConfig.UpdateInterval
			local before = os.clock(); AI.Update(now)
			workspace:SetAttribute("SurvivalAIUpdateMs", (os.clock() - before) * 1000)
		end
		if now >= nextSnapshot then nextSnapshot = now + Config.SnapshotInterval; MatchService.Publish() end
		Rewards.Update(now)
		if MinionConfig.DebugPerformance and now >= nextDiagnostics then
			nextDiagnostics = now + MinionConfig.DiagnosticInterval
			print(string.format("[Minions] active=%d cap=%d updateMs=%.2f", AI.GetCount(), MinionConfig.MaxActiveNPCs, workspace:GetAttribute("SurvivalAIUpdateMs") :: number))
		end
	end)
end
return MatchService
