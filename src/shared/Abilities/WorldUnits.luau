--!strict
-- Explicit Roblox prototype adaptation from the integration supplement, not map data.
local Scale = { StudsPerWarcraftUnit = 1 / 16, SourceStatus = "PrototypeAdaptation" }
function Scale.toStuds(warcraftUnits: number): number return warcraftUnits * Scale.StudsPerWarcraftUnit end
return table.freeze(Scale)
