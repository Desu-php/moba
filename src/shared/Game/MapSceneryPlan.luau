--!strict
-- Pure, deterministic presentation plan. Coordinates are relative to MapConfig.Origin.
-- Tall silhouettes stay outside the playable rectangle; the interior stays low.
local Plan = { Version = 1, PartBudget = 900 }
export type Piece = {
	name: string, x: number, y: number, z: number,
	sx: number, sy: number, sz: number, yaw: number,
	palette: string, shape: string, material: string,
}
function Plan.Build(): { Piece }
	local pieces: { Piece } = {}
	local function add(name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number,
		palette: string, shape: string?, yaw: number?, material: string?)
		table.insert(pieces, { name = name, x = x, y = y, z = z, sx = sx, sy = sy, sz = sz,
			palette = palette, shape = shape or "Block", yaw = yaw or 0, material = material or "Slate" })
	end
	local function tree(id: string, x: number, z: number, index: number)
		local h = 22 + (index % 4) * 3
		local enemy = x > 20
		add(id .. "Trunk", x, 1 + h / 2, z, 3.6, h, 3.6, if enemy then "Ash" else "Bark", nil, nil, "Wood")
		add(id .. "Crown", x, h + 2, z, 19, 13, 18, if enemy then "DarkLeaf" else "Leaf", "Ball", index * 17, "Grass")
		add(id .. "CrownTip", x + 3, h + 8, z + 1, 12, 9, 12, if enemy then "DarkLeaf" else "LightLeaf", "Ball", nil, "Grass")
		if enemy then
			add(id .. "Root", x - 3, 3, z, 10, 3, 4, "Ash", nil, 25, "Wood")
		end
	end
	-- Two staggered forest belts beyond the playable ground; no canopy over lanes.
	for side = -1, 1, 2 do
		for i = 0, 16 do
			local x = -176 + i * 22
			tree("Forest" .. side .. "_" .. i, x, side * (146 + (i % 2) * 9), i)
		end
		for i = 0, 8 do tree("Edge" .. side .. "_" .. i, side * 202, -112 + i * 28, i + 1) end
		for i = 0, 10 do
			local height = 18 + (i % 3) * 7
			add("Ridge" .. side .. "_" .. i, -180 + i * 36, height / 2 - 2, side * 180,
				42, height, 27, if i > 5 then "DarkRock" else "Rock", nil, (i % 3 - 1) * 12, "Rock")
			add("RidgeCap" .. side .. "_" .. i, -180 + i * 36, height - 3, side * 180,
				34, 4, 23, if i > 5 then "Ash" else "Moss", nil, (i % 3 - 1) * 12, "Grass")
		end
	end
	-- Alliance settlement: plaster houses, tiled overhangs, timber gate and banners.
	for i = 0, 3 do
		local z = -81 + i * 54
		add("VillageHouse" .. i, -191, 6, z, 18, 10, 20, "Plaster")
		add("VillageRoof" .. i, -191, 12, z, 23, 3, 25, "Roof", nil, nil, "Slate")
		add("VillageRoofTier" .. i, -191, 14, z, 17, 2, 19, "Roof")
		add("VillageDoor" .. i, -181.8, 4.2, z, 0.3, 6, 4, "Bark", nil, nil, "Wood")
		for window = -1, 1, 2 do
			add("VillageWindow" .. i .. "_" .. window, -181.7, 7, z + window * 6, 0.3, 3, 3, "Paper")
		end
	end
	for side = -1, 1, 2 do
		add("AllianceGatePost" .. side, -178, 8, side * 20, 4, 14, 4, "Bark", nil, nil, "Wood")
		add("AllianceBanner" .. side, -175.7, 11, side * 20, 0.4, 7, 3, "Alliance", nil, nil, "Fabric")
		add("AllianceBannerPlate" .. side, -175.4, 12.5, side * 20, 0.3, 1.3, 2.4, "Paper")
	end
	add("AllianceGateLintel", -178, 16, 0, 6, 3, 46, "Roof", nil, nil, "Wood")
	-- Enemy side: stone enclosure and pale, crooked root ribs, with red seals.
	for i = 0, 6 do
		local z = -90 + i * 30
		add("EnemyWall" .. i, 191, 5, z, 14, 8 + i % 3, 24, "DarkRock", nil, (i % 2) * 8, "Rock")
		add("EnemyRoot" .. i, 179 + i % 2 * 3, 10, z, 4, 18, 5, "Bone", nil, (i % 3 - 1) * 16, "Wood")
		add("EnemySeal" .. i, 176.8 + i % 2 * 3, 10, z, 0.4, 4, 2, "Enemy", nil, nil, "Fabric")
	end
	add("EnemyGateRib", 182, 21, 0, 8, 5, 50, "Ash", nil, nil, "Wood")
	-- A shallow visual stream overlays the existing solid floor, never Terrain water.
	add("River", 0, 1.035, 0, 11, 0.05, 246, "Water", nil, nil, "Glass")
	for _, z in { -84, 0, 84 } do
		add("BridgeDeck" .. z, 0, 1.28, z, 28, 0.08, 25, "Bark", nil, nil, "WoodPlanks")
		for side = -1, 1, 2 do
			add("BridgeEdge" .. z .. "_" .. side, 0, 1.7, z + side * 13.7, 28, 0.7, 0.8, "Rock")
		end
		for i = -5, 5 do
			add("BridgeBoard" .. z .. "_" .. i, i * 2.4, 1.34, z, 0.12, 0.04, 24.8, "Ash", nil, nil, "Wood")
		end
	end
	-- Low moss around existing rocks; no tall decoration in camp leash areas.
	for _, x in { -60, 60 } do
		for _, z in { -43, 43 } do
			add("RockMoss" .. x .. "_" .. z, x, 1.3, z, 18, 0.4, 15, "Moss", "Ball", nil, "Grass")
		end
	end
	assert(#pieces <= Plan.PartBudget, "Map scenery exceeds part budget")
	return pieces
end
return table.freeze(Plan)
