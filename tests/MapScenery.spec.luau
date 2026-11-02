--!strict
local Plan = require("../src/shared/Game/MapSceneryPlan")
local first, second = Plan.Build(), Plan.Build()
assert(#first == #second and #first <= Plan.PartBudget)
local names: { [string]: boolean } = {}
local tall, bridges, houses, roots = 0, 0, 0, 0
for index, piece in first do
	assert(not names[piece.name], "Duplicate scenery name: " .. piece.name)
	names[piece.name] = true
	for key, value in piece :: any do
		assert((second[index] :: any)[key] == value, "Non-deterministic scenery")
	end
	assert(piece.sx > 0 and piece.sy > 0 and piece.sz > 0)
	local yaw = math.rad(piece.yaw)
	local halfX = (math.abs(math.cos(yaw)) * piece.sx + math.abs(math.sin(yaw)) * piece.sz) / 2
	local halfZ = (math.abs(math.sin(yaw)) * piece.sx + math.abs(math.cos(yaw)) * piece.sz) / 2
	-- Any object taller than 4 studs must be completely outside playable ground.
	-- This also protects camp leash areas and the top-down camera near every lane.
	if piece.y + piece.sy / 2 > 4 then
		tall += 1
		assert(math.abs(piece.x) - halfX > 170 or math.abs(piece.z) - halfZ > 125,
			"Tall decor intrudes into playable area: " .. piece.name)
	end
	if string.sub(piece.name, 1, 10) == "BridgeDeck" then bridges += 1 end
	if string.sub(piece.name, 1, 12) == "VillageHouse" then houses += 1 end
	if string.sub(piece.name, 1, 9) == "EnemyRoot" then roots += 1 end
end
assert(tall > 150, "Forest and ridge silhouette missing")
assert(bridges == 3 and houses == 4 and roots == 7)
assert(names.AllianceGateLintel and names.EnemyGateRib and names.River and names.BackdropBedrock)
local bedrock = first[1]
assert(bedrock.name == "BackdropBedrock" and math.abs(bedrock.y + bedrock.sy / 2 - .95) < .001,
	"Backdrop must support scenery at the arena surface, never cover it")
assert(bedrock.sx / 2 >= 220 and bedrock.sz / 2 >= 200, "Backdrop must support the outer silhouettes")
-- No returned list is cached or shared: a caller cannot corrupt future generations.
first[1].x = 9999
assert(Plan.Build()[1].x == second[1].x)
print("[MapScenery] ALL PASS: deterministic layout, unique names, spatial clearance, landmarks, budget (" .. #second .. " parts)")
