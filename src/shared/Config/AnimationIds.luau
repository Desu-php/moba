--!strict

-- Publish your OWN R15 animations and replace empty strings with rbxassetid://ID.
-- Empty entries are intentional: combat timings do not depend on asset loading.
local defaultSet: { [string]: string } = { Punch1 = "", Punch2 = "", Punch3 = "", HeavyPunch = "" }
local sets: { [string]: { read [string]: string } } = { Default = table.freeze(defaultSet) }
return table.freeze(sets)
