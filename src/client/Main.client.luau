--!strict

local CombatController = require(script.Parent.Controllers.CombatController)
local InputController = require(script.Parent.Controllers.InputController)

CombatController.Start()
InputController.Start()
if not (game:GetService("RunService"):IsStudio() and workspace:GetAttribute("CombatOnlyTest") == true) then
	require(script.Parent.Controllers.SurvivalHUDController).Start()
	require(script.Parent.Controllers.HeroHUDController).Start()
	require(script.Parent.Controllers.AbilityHUDController).Start()
	require(script.Parent.Controllers.TowerVFXController).Start()
end
print("[Anime Battlegrounds] Client ready; left mouse button attacks")
