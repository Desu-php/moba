--!strict
local Rules = require("../src/shared/Abilities/AbilityInputRules")
local Config = require("../src/shared/Config/AbilityConfig")
local aliases = Config.InputAliases :: { read [string]: string }
local count = 0
local function check(key: string, active: boolean, expected: string?)
	assert(Rules.resolve(aliases, key, active) == expected, key .. " routing")
	count += 1
end
check("X", true, "KcmCancel")
check("X", false, "Rasenshuriken")
for _, active in { false, true } do
	check("Z", active, "Odama")
	check("T", active, "ShadowSleep")
	check("Right", active, "MeditationToggle")
	check("J", active, "MeditationRecall")
	check("E", active, "KcmDash")
	check("Left", active, "KuramaConvert")
	check("Six", active, "KuramaForm")
	check("V", active, "RikudoHY")
	check("B", active, "RikudoHZ")
	check("Unknown", active, nil)
end
for _, id in aliases do
	assert((Config.Abilities :: { [string]: Config.Ability })[id], "Alias points to missing ability")
	count += 1
end
assert(#Config.Order >= 5 and Config.Order[1] == "Rasengan" and Config.Order[5] == "KCM")
for _, key in { "Right", "Left" } do
	assert(Rules.ownsArrow(key, false, false, false, false)); count += 1
	for blocked = 1, 4 do
		assert(not Rules.ownsArrow(key, blocked == 1, blocked == 2, blocked == 3, blocked == 4)); count += 1
	end
end
assert(not Rules.ownsArrow("X", false, false, false, false)); count += 1
print("PASS AbilityInputRules: " .. count .. " checks; X dispatches one context action")
