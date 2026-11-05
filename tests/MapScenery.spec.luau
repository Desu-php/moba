--!strict
local Plan=require("../src/shared/Game/MapSceneryPlan")
local Towers=require("../src/shared/Config/TowerConfig")
local first,second=Plan.Build(),Plan.Build()
assert(#first==#second and #first<=Plan.PartBudget)
local names: {[string]:boolean}={}
local solid,bridges=0,0
for index,piece in first do
	assert(not names[piece.name],"Duplicate scenery name: "..piece.name);names[piece.name]=true
	for key,value in piece :: any do assert((second[index] :: any)[key]==value,"Non-deterministic scenery") end
	assert(piece.sx>0 and piece.sy>0 and piece.sz>0)
	if piece.solid then
		solid+=1
		local radius=math.sqrt(piece.sx^2+piece.sz^2)/2
		for _,route in Plan.Routes do assert(Plan.Distance(piece.x,piece.z,route)>Plan.LaneWidth/2+radius+3,"Blocked lane: "..piece.name) end
		for _,route in Plan.Paths do assert(Plan.Distance(piece.x,piece.z,route)>9+radius+3,"Blocked jungle path: "..piece.name) end
		for _,camp in Plan.Camps do assert((piece.x-camp[1])^2+(piece.z-camp[2])^2>(30+radius)^2,"Blocked camp leash") end
	end
	if string.sub(piece.name,1,10)=="BridgeDeck" then bridges+=1 end
end
assert(solid>20 and bridges==3)
assert(names.AllianceGateLintel and names.EnemyGateRib and names.DivineTreeTrunk and names.CraterFloor0)
assert(Plan.Width*Plan.Depth/(340*250)>5,"Map must have meaningful room for rotations")
for _,route in Plan.Routes do
	local length=0
	for i=1,#route-1 do length+=math.sqrt((route[i+1][1]-route[i][1])^2+(route[i+1][2]-route[i][2])^2) end
	assert(length>660 and #route>=11,"Expanded winding route missing")
end
local positions=Towers.Positions :: {[string]:{[string]:{{number}}}}
for team,lanes in positions do for lane,chain in lanes do
	for tier,p in chain do
		assert(Plan.Distance(p[1],p[3],Plan.Routes[lane])<=24,"Tower cannot acquire lane wave")
		assert(Plan.Distance(p[1],p[3],Plan.Routes[lane])>10,"Tower blocks formation")
		if tier>1 then
			local previous=chain[tier-1];local d=math.sqrt((p[1]-previous[1])^2+(p[3]-previous[3])^2)
			assert(d>=74 and d-2*Towers.Range>=18,"Overlapping tower zones: "..team..lane)
		end
		for _,piece in first do if piece.solid then
			assert(math.sqrt((p[1]-piece.x)^2+(p[3]-piece.z)^2)>9,"Jungle blocks tower combat slots")
		end end
	end
end end
first[1].x=9999;assert(Plan.Build()[1].x==second[1].x)
print("[MapScenery] ALL PASS: winding lanes, tower spacing, camp/path clearance, landmarks, determinism; "..#second.." parts")
