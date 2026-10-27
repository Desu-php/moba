--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.MinionConfig)
local MapConfig = require(Shared.Config.MapConfig)
local Mode = require(Shared.Config.GameModeConfig)
local AI = require(script.Parent.MinionAIService)
local Factory = require(script.Parent.MinionFactory)
local Teams = require(script.Parent.TeamService)
local Builder = require(script.Parent.MapBuilder)
local Spawner = {}
local map: Folder? = nil
local container: Folder? = nil
function Spawner.Start(arena: Folder)
	map = arena
	local existing = workspace:FindFirstChild("NPCs")
	assert(not existing or existing:IsA("Folder"), "Workspace.NPCs must be a Folder")
	local root = (existing or Instance.new("Folder")) :: Folder; root.Name = "NPCs"; root.Parent = workspace
	local owned = root:FindFirstChild("SurvivalMinions")
	assert(not owned, "SurvivalMinions container already exists")
	container = Instance.new("Folder"); (container :: Folder).Name = "SurvivalMinions"; (container :: Folder).Parent = root
end
function Spawner.Spawn(teamId: string, lane: string, kind: string, slot: number): Model?
	local arena, parent = map, container
	if not arena or not parent or not Teams.IsActive(teamId) or AI.GetCount() >= Config.MaxActiveNPCs then return nil end
	local state = Teams.GetState(); if not state or state.phase ~= "InProgress" then return nil end
	local types: { [string]: Config.Stats } = Config.Types
	local stats = types[kind]; assert(stats, "Unknown minion type")
	local settings = MapConfig.Teams :: { [string]: { Base: Vector3, Hero: Vector3, Reverse: boolean } }
	local layout = settings[teamId]; assert(layout, "Missing route direction")
	local route = Builder.Route(arena, lane, layout.Reverse)
	local points = arena:FindFirstChild("SpawnPoints"); assert(points)
	local teamPoints = points:FindFirstChild(teamId); assert(teamPoints)
	local marker = teamPoints:FindFirstChild(lane)
	assert(marker and marker:IsA("BasePart"), "Minion spawn missing")
	local color = Color3.new(1, 1, 1)
	for _, definition in Mode.Teams do if definition.Id == teamId then color = definition.Color end end
	local position = marker.Position + Vector3.new(0, 0, (slot - 2) * Config.SpawnSpacing)
	local model = Factory.Create(kind, teamId, color, position, stats); model.Parent = parent
	AI.Register(model, teamId, kind, lane, route, stats)
	return model
end
function Spawner.Wave(number: number)
	local ids = Teams.GetActiveTeams()
	-- Rotate team ordering when the shared cap leaves only a partial wave.
	for slot, kind in Config.WaveComposition do
		for _, lane in MapConfig.LaneOrder do
			for offset = 1, #ids do
				local index = ((offset + number - 2) % #ids) + 1
				Spawner.Spawn(ids[index], lane, kind, slot)
			end
		end
	end
end
return Spawner
