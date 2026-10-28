--!strict
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
local Towers = require(script.Parent.TowerService)
local Structures = require(script.Parent.StructureService)
local TowerConfig = require(Shared.Config.TowerConfig)
local MapConfig = require(Shared.Config.MapConfig)
local RoundConfig = require(Shared.Config.RoundConfig)
local Ability = require(script.Parent.AbilityService)
local Fighters = require(script.Parent.FighterStateService)
local Life = require(script.Parent.CombatLifeService)
local MatchService = {}
local state: Rules.State? = nil
local folder: Folder? = nil
local nextAI, nextSnapshot, nextDiagnostics = 0, 0, 0
local nextTower = 0
function MatchService.GetState(): Rules.State? return state end
function MatchService.ResetProgression()
	assert(not state or state.phase ~= "InProgress", "Reset progression only between matches")
	Progression.ResetMatch(); Rewards.Reset(); Shop.ResetSessions()
	require(script.Parent.AbilityService).Reset()
end
function MatchService.Publish()
	local current, replicated = state, folder
	if not current or not replicated then return end
	replicated:SetAttribute("Phase", current.phase); replicated:SetAttribute("StartedAt", current.startedAt)
	replicated:SetAttribute("RoundId", current.roundId); replicated:SetAttribute("IntermissionEnds", current.intermissionEnds)
	replicated:SetAttribute("FinishedAt", current.finishedAt); replicated:SetAttribute("Winner", current.winner or "")
	replicated:SetAttribute("Wave", current.wave); replicated:SetAttribute("ActiveNPCs", AI.GetCount())
	replicated:SetAttribute("PreparationEnds", current.preparationEnds); replicated:SetAttribute("MinimumPlayers", Mode.MinimumPlayers())
	for id, team in current.teams do
		local item = replicated:FindFirstChild(id)
		local base = Bases.Get(id)
		if item and base then
			item:SetAttribute("PlayerCount", team.count); item:SetAttribute("Capacity", Config.TeamCapacity)
			item:SetAttribute("Active", team.active); item:SetAttribute("Health", base.humanoid.Health)
			item:SetAttribute("MaxHealth", base.humanoid.MaxHealth)
			local remaining = Structures.Remaining(id)
			item:SetAttribute("TowersRemaining", remaining); item:SetAttribute("TowersTotal", #MapConfig.LaneOrder)
			item:SetAttribute("BaseProtected", remaining > 0); base.model:SetAttribute("ProtectedByTowers", remaining > 0)
		end
	end
end
function MatchService.ResetRound(expectedRound: number): boolean
	local current = state; if not current then return false end
	if not Rules.restart(current, workspace:GetServerTimeNow(), expectedRound) then return false end
	Damage.SetEnabled(false); Towers.CancelAll(); Ability.Reset(); AI.Reset(); Fighters.Reset(); Life.Reset()
	MatchService.ResetProgression()
	Bases.Reset(current.roundId); Towers.Reset(current.roundId); Teams.Reset(current.roundId)
	nextAI = 0; nextTower = 0; nextSnapshot = 0; nextDiagnostics = 0
	MatchService.Publish()
	print(string.format("[Match] Round %d ready", current.roundId))
	return true
end
local function eliminate(id: string, roundId: number)
	local current = state; if not current then return end
	if roundId ~= current.roundId then return end
	if not Rules.eliminate(current, id, workspace:GetServerTimeNow()) then return end
	Teams.Eliminate(id); AI.RemoveTeam(id)
	if current.phase == "Finished" then
		Damage.SetEnabled(false); AI.SetRunning(false); Towers.CancelAll(); Ability.Reset(); Fighters.Reset(); Teams.Finish()
		Rules.schedule(current, current.finishedAt, RoundConfig.IntermissionTime)
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
	Towers.Start(arena)
	Shop.Start(arena)
	local replicated = Instance.new("Folder"); replicated.Name = "SurvivalState"
	for _, definition in Config.Teams do
		local item = Instance.new("Folder"); item.Name = definition.Id
		item:SetAttribute("DisplayName", definition.DisplayName)
		item:SetAttribute("Color", definition.Color); item.Parent = replicated
	end
	local shots = Instance.new("RemoteEvent"); shots.Name = "MinionShot"; shots.Parent = replicated
	local towerEvents = Instance.new("RemoteEvent"); towerEvents.Name = "TowerEvent"; towerEvents.Parent = replicated
	Towers.Event.Event:Connect(function(kind: string, model: Model, origin: Vector3, destination: Vector3, teamId: string, lane: string, roundId: number)
		if roundId ~= initial.roundId then return end
		towerEvents:FireAllClients(kind, model, origin, destination, teamId, lane, roundId)
		if kind == "Destroyed" then MatchService.Publish() end
	end)
	AI.Shot.Event:Connect(function(origin: Vector3, target: Vector3, kind: string, id: string, model: Model, roundId: number)
		if roundId ~= initial.roundId then return end
		shots:FireAllClients(origin, target, kind, id, model, roundId)
	end)
	replicated.Parent = ReplicatedStorage; folder = replicated
	Bases.Destroyed.Event:Connect(eliminate)
	MatchService.Publish()
	RunService.Heartbeat:Connect(function()
		local current = state; if not current then return end
		local now = workspace:GetServerTimeNow()
		if Rules.intermission(current, now, RoundConfig.ResultDisplayTime) then MatchService.Publish() end
		if current.phase == "Intermission" and now >= current.intermissionEnds then MatchService.ResetRound(current.roundId) end
		Teams.Update(now)
		local ready = if Mode.IsSoloTest() then Teams.Count() >= 1 else Teams.Ready(Mode.MinimumPerTeam())
		local eligible = if ready then Teams.Count() else 0
		if Rules.advance(current, now, eligible, Mode.MinimumPlayers(), Config.PreparationTime, MinionConfig.FirstWaveDelay) then
			if current.phase == "InProgress" then Teams.LockRoster(); Damage.SetEnabled(true); AI.SetRunning(true) end
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
		if now >= nextTower then nextTower = now + TowerConfig.UpdateInterval; Towers.Update(now) end
		if MinionConfig.DebugPerformance and now >= nextDiagnostics then
			nextDiagnostics = now + MinionConfig.DiagnosticInterval
			print(string.format("[Minions] active=%d cap=%d updateMs=%.2f", AI.GetCount(), MinionConfig.MaxActiveNPCs, workspace:GetAttribute("SurvivalAIUpdateMs") :: number))
		end
	end)
end
return MatchService
