--!strict
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.GameModeConfig)
local GameModeService = {}
function GameModeService.MinimumPerTeam(): number
	if game:GetService("RunService"):IsStudio() then
		return math.clamp(Config.StudioMinimumPerTeam, 1, Config.TeamCapacity)
	end
	return Config.TeamCapacity
end
function GameModeService.MinimumPlayers(): number
	if Config.DebugSoloMode and game:GetService("RunService"):IsStudio() then return 1 end
	return #Config.Teams * GameModeService.MinimumPerTeam()
end
function GameModeService.IsSoloTest(): boolean
	return Config.DebugSoloMode and game:GetService("RunService"):IsStudio()
end
function GameModeService.TeamIds(): { string }
	local ids = {}; for _, team in Config.Teams do table.insert(ids, team.Id) end; return ids
end
return GameModeService
