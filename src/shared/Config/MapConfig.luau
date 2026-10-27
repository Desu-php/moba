--!strict
-- Coordinates are relative to Origin; routes run from Blue toward Red.
return table.freeze({
	Generated = true, Version = 1, Origin = Vector3.new(0, 32, 0),
	GroundSize = Vector3.new(340, 2, 250), LaneWidth = 24,
	Teams = {
		Blue = { Base = Vector3.new(-140, 4, 0), Hero = Vector3.new(-155, 1.5, 14), Reverse = false },
		Red = { Base = Vector3.new(140, 4, 0), Hero = Vector3.new(155, 1.5, -14), Reverse = true },
	},
	LaneOrder = { "Top", "Mid", "Bottom" },
	Routes = {
		Top = { Vector3.new(-124, 4, -12), Vector3.new(-106, 4, -84), Vector3.new(0, 4, -84), Vector3.new(106, 4, -84), Vector3.new(124, 4, -12) },
		Mid = { Vector3.new(-122, 4, 0), Vector3.new(-64, 4, 0), Vector3.new(0, 4, 0), Vector3.new(64, 4, 0), Vector3.new(122, 4, 0) },
		Bottom = { Vector3.new(-124, 4, 12), Vector3.new(-106, 4, 84), Vector3.new(0, 4, 84), Vector3.new(106, 4, 84), Vector3.new(124, 4, 12) },
	},
	Obstacles = { Vector3.new(-60, 5, -43), Vector3.new(60, 5, -43), Vector3.new(-60, 5, 43), Vector3.new(60, 5, 43) },
})
