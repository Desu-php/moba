--!strict
local Rules = require("../src/shared/Combat/CombatCameraRules")
local Config = require("../src/shared/Config/CameraConfig")
local count = 0
local function check(value: boolean) assert(value); count += 1 end
check(Rules.setting(nil, 11, 4, 24) == 11)
check(Rules.setting(0 / 0, 11, 4, 24) == 11)
check(Rules.setting(math.huge, 11, 4, 24) == 11)
check(Rules.setting(-math.huge, 11, 4, 24) == 11)
check(Rules.setting(-500, 11, 4, 24) == 4)
check(Rules.setting(500, 11, 4, 24) == 24)
check(Rules.setting(15, 11, 4, 24) == 15)
check(Rules.alpha(0, 1 / 60) == 1)
check(Rules.alpha(25, 0) == 0)
-- Follow response is frame-rate independent for a fixed endpoint.
local remaining30 = (1 - Rules.alpha(Config.Smoothing, 1 / 30)) ^ 30
local remaining144 = (1 - Rules.alpha(Config.Smoothing, 1 / 144)) ^ 144
check(math.abs(remaining30 - remaining144) < 1e-10)
for _, input in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
	local x, z = Rules.move(input[1], input[2])
	check(math.abs(x * x + z * z - 1) < 1e-10)
end
local x, z = Rules.move(0, 0); check(x == 0 and z == 0)
x, z = Rules.move(0, -1); check(x == 0 and z == -1)
check(Rules.captured(true, false, false, false, false, false))
check(not Rules.captured(false, false, false, false, false, false))
for blocked = 1, 5 do
	check(not Rules.captured(true, blocked == 1, blocked == 2, blocked == 3, blocked == 4, blocked == 5))
end
print("PASS CombatCamera: " .. count .. " checks; finite settings, normalized movement and UI capture")
