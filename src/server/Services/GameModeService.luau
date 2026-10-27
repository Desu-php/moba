--!strict
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.GameModeConfig)
local GameModeService = {}
function GameModeService.MinimumPlayers(): number
	if Config.DebugSoloMode and game:GetService("RunService"):IsStudio() then return 1 end
	return math.max(#Config.Teams, Config.MinimumPlayers)
end
function GameModeService.TeamIds(): { string }
	local ids = {}; for _, team in Config.Teams do table.insert(ids, team.Id) end; return ids
end
return GameModeService
