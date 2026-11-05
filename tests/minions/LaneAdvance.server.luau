--!nocheck
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Shared=game.ReplicatedStorage.Shared
local Match=require(S.MatchService)
local AI=require(S.MinionAIService)
local Spawn=require(S.MinionSpawnerService)
local Damage=require(S.DamageService)
local results={}
local metrics={}
local function check(name,ok)
 assert(ok,name);table.insert(results,name);workspace:SetAttribute("LaneAdvanceResults",game.HttpService:JSONEncode(results))
end
local function waitFor(fn,seconds,name)
 local deadline=os.clock()+seconds
 repeat if fn() then return end;task.wait(.05) until os.clock()>deadline
 error("Timeout: "..name)
end
local ok,err=xpcall(function()
 waitFor(function() return #game.Players:GetPlayers()==1 and Match.GetState() and Match.GetState().phase=="InProgress" end,30,"match")
 local state=Match.GetState();state.nextWaveAt=workspace:GetServerTimeNow()+10000
 local jungle=require(S.JungleService);jungle.Stop()
 -- Remove neutral attackers only in this fixture: a live forest guardian near
 -- the middle lane correctly takes combat priority over distant structures.
 for _,camp in jungle.GetAll() do
  if camp.model then camp.model:Destroy() end
  camp.logic.mode="Dead";camp.logic.respawnAt=workspace:GetServerTimeNow()+10000
 end
 AI.Reset();require(Shared.Config.TowerConfig).Range=0;require(S.TowerService).CancelAll()
 local function tower(team,lane,level) return workspace.Map.Towers[team.."_"..lane..(if level==1 then "" else "_T"..level)] end
 -- Opposing packs are tested sequentially: live enemy units legitimately take
 -- combat priority over a tower and must not invalidate the no-enemies scenario.
 for _,team in {"Blue","Red"} do
 local groups={}
 for _,lane in {"Top","Mid","Bottom"} do
  local enemy=if team=="Blue" then "Red" else "Blue"
  local sign=if team=="Blue" then 1 else -1
  local first=tower(enemy,lane,1)
  local group={name=team..lane,units={},enemy=enemy,lane=lane,first=first}
  for level=1,3 do local h=tower(enemy,lane,level).Humanoid;h.MaxHealth=100000;h.Health=100000 end
  for index=1,9 do
   local m=Spawn.Spawn(team,lane,if index%3==0 then "Ranged" else "Melee",index);assert(m)
   local n=AI.GetAll()[m]
   n.root.CFrame=CFrame.new(first.HumanoidRootPart.Position+Vector3.new(-sign*(9+math.floor((index-1)/3)*4.5),0,((index-1)%3-1)*4.5))
   n.humanoid.MaxHealth=10000;n.humanoid.Health=10000;n.spawnedAt=0;n.waypoint=3;n.nextAttack=0
   table.insert(group.units,n)
  end
  table.insert(groups,group)
 end
 AI.SetRunning(true)
 waitFor(function()
  for _,g in groups do if g.first.Humanoid.Health>=100000 then return false end end
  return true
 end,10,"all six lane groups attack first tower")
 task.wait(3)
 for stage=1,2 do
  for _,g in groups do
   local current=tower(g.enemy,g.lane,stage)
   assert(Damage.Apply(g.units[1].model,current.Humanoid,1000000)>0)
  end
  task.wait(.6)
  for _,g in groups do
   local nextTower=tower(g.enemy,g.lane,stage+1)
   local assigned=0
   for _,n in g.units do if n.target==nextTower then assigned+=1 end end
   metrics[g.name.." stage "..stage.." assigned"]=assigned
  end
  workspace:SetAttribute("LaneAdvanceMetrics",game.HttpService:JSONEncode(metrics))
  for _,g in groups do check(g.name.." immediately selects tier "..(stage+1),metrics[g.name.." stage "..stage.." assigned"]==#g.units) end
  local deadline=os.clock()+18
  repeat
   task.wait(.1)
   local all=true
   for _,g in groups do
    local nextTower=tower(g.enemy,g.lane,stage+1)
    for _,n in g.units do
     if not n.model.Parent or n.humanoid.Health<=0 then error("Lost healthy minion "..g.name) end
     if ((n.root.Position-nextTower.HumanoidRootPart.Position)*Vector3.new(1,0,1)).Magnitude>25 then all=false end
    end
    if nextTower.Humanoid.Health>=100000 then all=false end
   end
   if all then break end
  until os.clock()>deadline
  for _,g in groups do
   local nextTower=tower(g.enemy,g.lane,stage+1);local arrived=0
   for _,n in g.units do if ((n.root.Position-nextTower.HumanoidRootPart.Position)*Vector3.new(1,0,1)).Magnitude<=25 then arrived+=1 end end
   metrics[g.name.." stage "..stage.." arrived"]=arrived
   workspace:SetAttribute("LaneAdvanceMetrics",game.HttpService:JSONEncode(metrics))
   check(g.name.." entire group advances to tier "..(stage+1),arrived==#g.units)
   check(g.name.." next tier takes real damage",nextTower.Humanoid.Health<100000)
  end
 end
 AI.Reset()
 end
 local blocker=Spawn.Spawn("Blue","Mid","Melee",1);local b=AI.GetAll()[blocker]
 b.root.CFrame=CFrame.new(0,36,0);b.root.Anchored=true;blocker:SetAttribute("CombatDisabled",true)
 local followers={}
 for index=1,6 do
  local m=Spawn.Spawn("Blue","Mid","Melee",index);local n=AI.GetAll()[m]
  n.root.CFrame=CFrame.new(-index*4.5,36,0);m:SetAttribute("LaneOffset",0);n.waypoint=4;n.spawnedAt=0
  table.insert(followers,n)
 end
 AI.SetRunning(true)
 waitFor(function()
  for _,n in followers do if not n.model.Parent or n.root.Position.X<6 then return false end end
  return true
 end,14,"six followers bypass stationary allied leader")
 check("all six followers pass stationary ally",true)
 check("waiting allies are not despawned",AI.GetCount()==7)
 AI.Reset()
 workspace:SetAttribute("LaneAdvanceStatus","PASS")
end,debug.traceback)
if not ok then workspace:SetAttribute("LaneAdvanceStatus","FAIL");workspace:SetAttribute("LaneAdvanceError",err);warn(err) end
