--!strict

local CombatService = require(script.Parent.Services.CombatService)
local combatOnly = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("CombatOnlyTest") == true
if not combatOnly then require(script.Parent.Services.MatchService).Start() end
CombatService.Start()
print("[Anime Battlegrounds] Server ready")
