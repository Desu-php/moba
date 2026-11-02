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
print("PASS AbilityInputRules: " .. count .. " checks; X dispatches one context action")
