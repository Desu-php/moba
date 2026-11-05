--!strict
local Plan = require(script.Parent.Parent.Game.MapSceneryPlan)
local function vectors(source: { [string]: { {number} } }): { [string]: {Vector3} }
	local result: { [string]: {Vector3} }={}
	for name, points in source do
		local route={}
		for _,p in points do table.insert(route,Vector3.new(p[1],4,p[2])) end
		result[name]=route
	end
	return result
end
return table.freeze({
	Generated=true,Version=2,Origin=Vector3.new(0,32,0),
	GroundSize=Vector3.new(Plan.Width,2,Plan.Depth),LaneWidth=Plan.LaneWidth,
	Teams={
		Blue={Base=Vector3.new(-360,4,0),Hero=Vector3.new(-377,1.5,14),Reverse=false},
		Red={Base=Vector3.new(360,4,0),Hero=Vector3.new(377,1.5,-14),Reverse=true},
	},
	LaneOrder={"Top","Mid","Bottom"},Routes=vectors(Plan.Routes),Paths=vectors(Plan.Paths),
	Obstacles={} :: {Vector3},
})
