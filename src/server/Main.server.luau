--!strict

local CombatService = require(script.Parent.Services.CombatService)
local combatOnly = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("CombatOnlyTest") == true
if not combatOnly then
	require(script.Parent.Services.HeroService).Start()
	require(script.Parent.Services.MatchService).Start()
end
CombatService.Start()
if not combatOnly then require(script.Parent.Services.AbilityService).Start() end
print("[Anime Battlegrounds] Server ready")
