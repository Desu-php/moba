--!strict

local CombatController = require(script.Parent.Controllers.CombatController)
local InputController = require(script.Parent.Controllers.InputController)

require(script.Parent.Controllers.CameraController).Start()
CombatController.Start()
InputController.Start()
if not (game:GetService("RunService"):IsStudio() and workspace:GetAttribute("CombatOnlyTest") == true) then
	require(script.Parent.Controllers.HeroAppearanceTransition).Start()
	task.spawn(function() require(script.Parent.Controllers.DeveloperConsoleController).Start() end)
	task.spawn(function() require(script.Parent.Controllers.HeroSelectionController).Start() end)
 task.spawn(function() require(script.Parent.Controllers.SasukeVFXController).Start() end)
 require(script.Parent.Controllers.SurvivalHUDController).Start()
	require(script.Parent.Controllers.HeroHUDController).Start()
	require(script.Parent.Controllers.AbilityHUDController).Start()
	require(script.Parent.Controllers.TowerVFXController).Start()
	require(script.Parent.Controllers.MinionMotionController).Start()
 require(script.Parent.Controllers.GamakichiVisualController).Start()
end
print("[Anime Battlegrounds] Client ready; left mouse button attacks")
