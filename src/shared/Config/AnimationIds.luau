--!strict

-- Publish your OWN R15 animations and replace empty strings with rbxassetid://ID.
-- Empty entries are intentional: combat timings do not depend on asset loading.
local defaultSet: { [string]: string } = { Punch1 = "", Punch2 = "", Punch3 = "", HeavyPunch = "" }
local sets: { [string]: { read [string]: string } } = { Default = table.freeze(defaultSet) }
local ninjaSet: { [string]: string } = { Idle = "", Run = "", Punch1 = "", Punch2 = "", Punch3 = "", HeavyPunch = "",
	ShadowClones = "", RasenganPrepare = "", RasenganStrike = "", RasenganHelper = "", Stun = "" }
sets.OrangeNinja = table.freeze(ninjaSet)
return table.freeze(sets)
