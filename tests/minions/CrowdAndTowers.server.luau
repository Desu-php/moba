--!nocheck
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Shared=game.ReplicatedStorage.Shared
local Match=require(S.MatchService)
local AI=require(S.MinionAIService)
local Spawn=require(S.MinionSpawnerService)
local Structures=require(S.StructureService)
local Damage=require(S.DamageService)
local Towers=require(S.TowerService)
local results={}
local function check(name,ok)
 assert(ok,name);table.insert(results,name);workspace:SetAttribute("CrowdTowerResults",game.HttpService:JSONEncode(results))
end
local function waitFor(fn,seconds,name)
 local deadline=os.clock()+seconds
 repeat if fn() then return end;task.wait(.03) until os.clock()>deadline
 error("Timeout: "..name)
end
local ok,err=xpcall(function()
 waitFor(function() return #game.Players:GetPlayers()==1 and Match.GetState() and Match.GetState().phase=="InProgress" end,30,"match")
 local state=Match.GetState();state.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(S.JungleService).Stop();AI.Reset();require(Shared.Config.TowerConfig).Range=0;Towers.CancelAll()
 local map=workspace.Map
 local function tower(team,lane,level) return map.Towers[team.."_"..lane..(if level==1 then "" else "_T"..level)] end
 for _,team in {"Blue","Red"} do
  local attacker=Spawn.Spawn(if team=="Blue" then "Red" else "Blue","Mid","Melee",1)
  for _,lane in {"Top","Mid","Bottom"} do
   local first,second,third=tower(team,lane,1),tower(team,lane,2),tower(team,lane,3)
   local hp2,hp3=second.Humanoid.Health,third.Humanoid.Health
   check(team..lane.." outer available",Structures.CanReceive(first))
   check(team..lane.." inner damage blocked",Damage.Apply(attacker,second.Humanoid,10000)==0 and second.Humanoid.Health==hp2)
   check(team..lane.." final attack blocked",Damage.ApplyAttack(attacker,third.Humanoid,10000)==0 and third.Humanoid.Health==hp3)
   check(team..lane.." protection visible",second:GetAttribute("ProtectedByPreviousTower")==true and second.ProtectionShield.Enabled)
   assert(Damage.Apply(attacker,first.Humanoid,10000)>0)
   check(team..lane.." first unlocks only second",Structures.CanReceive(second) and not Structures.CanReceive(third))
   check(team..lane.." second shield removed immediately",second:GetAttribute("ProtectedByPreviousTower")==false and not second.ProtectionShield.Enabled)
   if lane=="Top" then check(team.." other lane remains locked",not Structures.CanReceive(tower(team,"Mid",2))) end
   assert(Damage.Apply(attacker,second.Humanoid,10000)>0)
   check(team..lane.." second unlocks third",Structures.CanReceive(third) and third:GetAttribute("ProtectedByPreviousTower")==false)
   assert(Damage.Apply(attacker,third.Humanoid,10000)>0)
  end
  AI.Remove(attacker)
 end
 check("all chains clear independently",Structures.Remaining("Blue")==0 and Structures.Remaining("Red")==0)
 AI.Reset()
 local group={}
 for _,team in {"Blue","Red"} do for index=1,9 do
  local kind=if index%3==0 then "Ranged" else "Melee"
  local m=Spawn.Spawn(team,"Mid",kind,index);local n=AI.GetAll()[m];table.insert(group,n)
  local side=if team=="Blue" then -1 else 1
  n.root.CFrame=CFrame.new(side*(24+math.floor((index-1)/3)*5),36,((index-1)%3-1)*5)
  n.humanoid.MaxHealth=400;n.humanoid.Health=400;n.spawnedAt=0;n.waypoint=3;n.nextAttack=0
 end end
 check("minions physically collide",game.PhysicsService:CollisionGroupsAreCollidable("SurvivalMinions","SurvivalMinions"))
 local hitCount=0
 local connection=Damage.Applied.Event:Connect(function(a,v) if a:GetAttribute("EntityKind")=="Minion" and v:GetAttribute("EntityKind")=="Minion" then hitCount+=1 end end)
 AI.SetRunning(true)
 local closest=math.huge;local maxHeight=0;local moved=false;local recovered=0
 local untilAt=os.clock()+20
 repeat
  task.wait(.1)
  for i,a in group do
   if not a.model.Parent or a.humanoid.Health<=0 then continue end
   maxHeight=math.max(maxHeight,a.root.Position.Y)
   if math.abs(a.root.Position.X)<12 then moved=true end
   recovered=math.max(recovered,a.recoveries)
   for j=i+1,#group do
    local b=group[j]
    if b.model.Parent and b.humanoid.Health>0 and math.abs(a.root.Position.Y-b.root.Position.Y)<4 then
     closest=math.min(closest,((a.root.Position-b.root.Position)*Vector3.new(1,0,1)).Magnitude)
    end
   end
  end
 until os.clock()>untilAt
 connection:Disconnect()
 workspace:SetAttribute("CrowdMetrics",game.HttpService:JSONEncode({closest=closest,maxHeight=maxHeight,hits=hitCount,recoveries=recovered}))
 check("opposing waves advance into combat",moved and hitCount>10)
 check("18 fighting minions keep body clearance",closest>=3)
 check("minions never climb onto peers",maxHeight<38)
 check("crowd does not trigger stuck recovery",recovered==0)
 AI.Reset()
 -- Multiple allied waves share a turning lane without converging to one point.
 for index=1,9 do Spawn.Spawn("Blue","Top",if index%3==0 then "Ranged" else "Melee",index) end
 AI.SetRunning(true);task.wait(12)
 local progressed=0
 for _,n in AI.GetAll() do if n.root.Position.Z < -50 then progressed+=1 end end
 check("allied column advances around lane turn",progressed>=6)
 AI.Reset();Towers.Reset(state.roundId+1)
 check("reset restores chain shields",not Structures.CanReceive(tower("Red","Mid",2)) and tower("Red","Mid",2).ProtectionShield.Enabled)
 workspace:SetAttribute("CrowdTowerStatus","PASS")
end,debug.traceback)
if not ok then workspace:SetAttribute("CrowdTowerStatus","FAIL");workspace:SetAttribute("CrowdTowerError",err);warn(err) end
