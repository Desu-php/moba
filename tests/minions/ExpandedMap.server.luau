--!nocheck
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Shared=game.ReplicatedStorage.Shared
local Match=require(S.MatchService)
local AI=require(S.MinionAIService)
local Spawn=require(S.MinionSpawnerService)
local Plan=require(Shared.Game.MapSceneryPlan)
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds
	repeat if fn() then return end;task.wait(.1) until os.clock()>deadline
	error("Timed out waiting for match")
end
local ok,err=xpcall(function()
	waitFor(function() return Match.GetState() and Match.GetState().phase=="InProgress" end,30)
	Match.GetState().nextWaveAt=workspace:GetServerTimeNow()+10000
	local jungle=require(S.JungleService);jungle.Stop()
	for _,camp in jungle.GetAll() do
		if camp.model then camp.model:Destroy() end
		camp.logic.mode="Dead";camp.logic.respawnAt=workspace:GetServerTimeNow()+10000
	end
	AI.Reset();require(Shared.Config.TowerConfig).Range=0;require(S.TowerService).CancelAll()
	local units={};local met={};local maxDeviation=0;local maxHeight=0
	for _,team in {"Blue","Red"} do for _,lane in {"Top","Mid","Bottom"} do
		for slot=1,3 do
			local model=Spawn.Spawn(team,lane,if slot==3 then "Ranged" else "Melee",slot);assert(model)
			local n=AI.GetAll()[model];n.humanoid.MaxHealth=100000;n.humanoid.Health=100000
			table.insert(units,n)
		end
	end end
	AI.SetRunning(true)
	local started=os.clock()
	repeat
		task.wait(.15)
		for _,n in units do
			assert(n.model.Parent and n.humanoid.Health>0,"Lost healthy unit on long route")
			local p=n.root.Position
			maxDeviation=math.max(maxDeviation,Plan.Distance(p.X,p.Z,Plan.Routes[n.lane]))
			maxHeight=math.max(maxHeight,p.Y)
			assert(n.recoveries<=1,"Repeated recovery on winding lane")
			if n.target and n.target:GetAttribute("EntityKind")=="Minion" and math.abs(p.X)<30 then met[n.teamId..n.lane]=true end
		end
		local count=0;for _ in met do count+=1 end
		workspace:SetAttribute("ExpandedMapMetrics",game.HttpService:JSONEncode({groupsAtRiver=count,maxDeviation=maxDeviation,maxHeight=maxHeight,elapsed=os.clock()-started,units=#units}))
		if count==6 then break end
	until os.clock()-started>80
	local count=0;for _ in met do count+=1 end
	assert(count==6,"Not all six groups reached river combat")
	assert(maxDeviation<23,"Wave cut across jungle")
	assert(maxHeight<39,"Wave climbed scenery")
	workspace:SetAttribute("ExpandedMapStatus","PASS")
end,debug.traceback)
if not ok then workspace:SetAttribute("ExpandedMapStatus","FAIL");workspace:SetAttribute("ExpandedMapError",err);warn(err) end
