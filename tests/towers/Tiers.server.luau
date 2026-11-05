--!nocheck
-- Single-player Studio integration for generated tiered lanes.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Shared=game.ReplicatedStorage.Shared
local Config=require(Shared.Config.TowerConfig)
local Match=require(S.MatchService)
local Towers=require(S.TowerService)
local Structures=require(S.StructureService)
local Damage=require(S.DamageService)
local Fighters=require(S.FighterStateService)
local AI=require(S.MinionAIService)
local Economy=require(S.EconomyService)
local results={}
local function check(name,ok)
 assert(ok,name);table.insert(results,name);workspace:SetAttribute("TowerTiersResults",game.HttpService:JSONEncode(results))
end
local function waitFor(fn,seconds,name)
 local deadline=os.clock()+seconds
 repeat if fn() then return end;task.wait(.03) until os.clock()>deadline
 error("Timeout: "..name)
end
local ok,err=xpcall(function()
 waitFor(function() return #game.Players:GetPlayers()==1 and Match.GetState() and Match.GetState().phase=="InProgress" end,30,"solo match")
 local p=game.Players:GetPlayers()[1];local state=Match.GetState();local c=p.Character;assert(c)
 require(S.JungleService).Stop();AI.Reset();state.nextWaveAt=workspace:GetServerTimeNow()+10000
 local map=workspace.Map;local factory=require(S.TowerFactory)
 factory.Build(map);factory.Build(map)
 check("18 towers after repeated factory builds",#map.Towers:GetChildren()==18)
 check("nine towers per team",Structures.Remaining("Blue")==9 and Structures.Remaining("Red")==9)
 check("replicated totals reflect nine towers",game.ReplicatedStorage.SurvivalState.Blue:GetAttribute("TowersTotal")==9
  and game.ReplicatedStorage.SurvivalState.Red:GetAttribute("TowersRemaining")==9)
 for _,team in {"Blue","Red"} do for _,lane in {"Top","Mid","Bottom"} do
  local previousHP,previousDamage,previousInterval=0,0,math.huge
  for level=1,3 do
   local m=map.Towers[team.."_"..lane..(if level==1 then "" else "_T"..level)]
   local hp=m.Humanoid;local damage=m:GetAttribute("AttackDamage");local interval=m:GetAttribute("AttackInterval")
   check(team.." "..lane.." tier "..level.." stronger",hp.MaxHealth>previousHP and damage>previousDamage and interval<previousInterval)
   previousHP,previousDamage,previousInterval=hp.MaxHealth,damage,interval
   check(team.." "..lane.." tier "..level.." distinct silhouette",m:FindFirstChild("RankBand"..level)~=nil and m:GetAttribute("TowerTier")==level)
  end
 end end
 local enemyTeam=if c:GetAttribute("TeamId")=="Blue" then "Red" else "Blue"
 local target=Instance.new("Model");target.Name="TierShotTarget"
 target:SetAttribute("EntityKind","Minion");target:SetAttribute("TeamId",c:GetAttribute("TeamId"));target:SetAttribute("RoundId",state.roundId)
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.CanCollide=false;root.Size=Vector3.new(2,2,1);root.Parent=target
 local hp=Instance.new("Humanoid");hp.RequiresNeck=false;hp.MaxHealth=10000;hp.Health=10000;hp.Parent=target;target.PrimaryPart=root;target.Parent=workspace
 Fighters.GetOrCreate(target)
 for level=1,3 do
  local m=map.Towers[enemyTeam.."_Mid"..(if level==1 then "" else "_T"..level)]
  local shots={}
  local connection=Damage.Applied.Event:Connect(function(attacker,victim,amount)
   if attacker==m and victim==target then
    -- Compare authoritative preparation starts, not delivery jitter between Heartbeats.
    table.insert(shots,{at=Towers.GetAll()[m].logic.contactAt-Config.Windup,damage=amount})
   end
  end)
  root.Position=m.HumanoidRootPart.Position+Vector3.new(0,0,-12)
  waitFor(function() return #shots>=2 end,5,"two tier shots")
  connection:Disconnect()
  local expected=Config.Damage*Config.Tiers[level].DamageMultiplier
  check("tier "..level.." applies real damage",shots[1].damage==expected and shots[2].damage==expected)
  check("tier "..level.." respects its interval",shots[2].at-shots[1].at>=Config.AttackInterval*Config.Tiers[level].IntervalMultiplier-.02)
 end
 Fighters.Remove(target);target:Destroy()
 Config.Range=0;Towers.CancelAll()
 -- A physical lane minion must progress through all three tower positions.
 for level=1,3 do map.Towers[enemyTeam.."_Mid"..(if level==1 then "" else "_T"..level)].Humanoid.Health=8 end
 local unit=require(S.MinionSpawnerService).Spawn(tostring(c:GetAttribute("TeamId")),"Mid","Melee",1);assert(unit)
 local npc=AI.GetAll()[unit];local sign=if enemyTeam=="Red" then 1 else -1
 npc.root.CFrame=CFrame.new(map.Towers[enemyTeam.."_Mid"].HumanoidRootPart.Position+Vector3.new(-sign*12,0,0));npc.humanoid.MaxHealth=10000;npc.humanoid.Health=10000
 npc.waypoint=4;npc.spawnedAt=0;npc.nextAttack=0
 AI.SetRunning(true)
 waitFor(function() return map.Towers[enemyTeam.."_Mid_T3"].Humanoid.Health<=0 end,35,"minion clears three tiers")
 check("lane minion advances through all three towers",map.Towers[enemyTeam.."_Mid"].Humanoid.Health<=0 and map.Towers[enemyTeam.."_Mid_T2"].Humanoid.Health<=0)
 AI.Reset()
 local base=require(S.BaseService).Get(enemyTeam)
 check("other lanes still protect the base",Structures.Remaining(enemyTeam)==6 and Damage.Apply(c,base.humanoid,10)==0)
 local gold=Economy.GetGold(p);local destroyed=0
 for level=1,3 do for model,record in Structures.GetAll() do
  if record.teamId==enemyTeam and record.kind=="Tower" and model:GetAttribute("TowerTier")==level and Structures.Alive(record) then
   check("living tower can receive lethal damage",Damage.Apply(c,record.humanoid,10000)>0);destroyed+=1
   check("ruins no longer block",not record.root.CanCollide)
  end
 end end
 check("six remaining towers pay bounty once",Economy.GetGold(p)==gold+destroyed*Config.TeamGold and destroyed==6)
 check("ninth tower opens the base",Structures.Remaining(enemyTeam)==0 and Damage.Apply(c,base.humanoid,10)==10)
 Towers.Reset(state.roundId+1)
 check("reset restores all eighteen towers",Structures.Remaining("Blue")==9 and Structures.Remaining("Red")==9)
 for _,t in Towers.GetAll() do
  local level=t.structure.model:GetAttribute("TowerTier")
  check("reset preserves tier "..level.." health",t.structure.humanoid.Health==Config.Health*Config.Tiers[level].HealthMultiplier)
 end
 Config.Range=28
 workspace:SetAttribute("TowerTiersStatus","PASS")
end,debug.traceback)
if not ok then workspace:SetAttribute("TowerTiersStatus","FAIL");workspace:SetAttribute("TowerTiersError",err);warn(err) end
