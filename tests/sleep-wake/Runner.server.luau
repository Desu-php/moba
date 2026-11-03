--!strict
-- Isolated PlayMode fixture: real player, Instances/geometry/services; no input simulation.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Shared=game.ReplicatedStorage.Shared
local Teams=require(S.TeamService)
local Match=require(Shared.Game.MatchState)
local Fighters=require(S.FighterStateService)
local Sleep=require(S.NarutoSleepService)
local Damage=require(S.DamageService)
local Hitboxes=require(S.HitboxService)
local Combat=require(S.CombatService)
local Profile=require(Shared.Config.CombatConfig).Profiles.OrangeNinja
local count=0
local function check(label:string,value:boolean)assert(value,label);count+=1;print("[SleepWakeTests] PASS "..label)end
local done=false
task.delay(30,function()if not done then game:GetService("StudioTestService"):EndTest({ok=false,error="SleepWake timeout30s",count=count})end end)
local function body(name:string,team:string,at:Vector3):(Model,Humanoid,Part)
 local m=Instance.new("Model");m.Name=name
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Size=Vector3.new(2,3,2);root.Anchored=true;root.Position=at;root.Parent=m;m.PrimaryPart=root
 local h=Instance.new("Humanoid");h.RequiresNeck=false;h.BreakJointsOnDeath=false;h.MaxHealth=100;h.Health=100;h.Parent=m
 m:SetAttribute("TeamId",team);m:SetAttribute("EntityKind","Hero");m:SetAttribute("RoundId",1);m:SetAttribute("LifeId",1);m.Parent=workspace
 return m,h,root
end
local ok,err=xpcall(function()
 local state=Match.new({"Blue","Red"});Teams.Start(state,require(S.MapBuilder).Build());state.phase="InProgress"
 -- Let Studio create the connected Player normally; never request WritePlayer capability.
 local players=game:GetService("Players")
 local player=players:GetPlayers()[1] or players.PlayerAdded:Wait()
 task.wait(.1);check("fixture player is an authoritative participant",Teams.IsParticipant(player) and player:GetAttribute("TeamId")=="Blue")
 local actor,_,root=body("WakeActor","Blue",Vector3.new(0,36,0));player.Character=actor
 task.wait(.1);actor:PivotTo(CFrame.new(0,36,0));root.Anchored=false;root:SetNetworkOwner(nil)
 local ally,health,allyRoot=body("SleepingAlly","Blue",Vector3.new(0,36,-3))
 local _enemy,enemyHealth=body("EnemyBehindAlly","Red",Vector3.new(0,36,-4.5))
 local caster=body("SleepCaster","Red",Vector3.new(30,36,0))
 local fighter=Fighters.GetOrCreate(actor);local victim=Fighters.GetOrCreate(ally);assert(fighter and victim)
 fighter.profile=Profile
 Combat.Start()
 local offensive,damageEvents=0,0
 local attackConnection=Combat.AttackStarted.Event:Connect(function(f)if f.character==actor then offensive+=1 end end)
 local damageConnection=Damage.Applied.Event:Connect(function(a)if a==actor then damageEvents+=1 end end)
 check("real hostile Sleep applies",Sleep.Apply(caster,ally,workspace:GetServerTimeNow()))
 check("active ally can be woken",Sleep.CanWakeAlly(actor,ally))
 check("friendly damage remains denied",not Damage.CanDamage(actor,ally) and Damage.Apply(actor,health,50)==0)
 local default=Hitboxes.GetTargets(actor,root,Profile)
 check("ordinary hitbox callers stay enemy-only",#default==1 and default[1]==enemyHealth)
 local picked=Hitboxes.GetTargets(actor,root,Profile,function(m)return Sleep.CanWakeAlly(actor,m)end)
 check("nearest sleeping ally is one admitted interaction",#picked==1 and picked[1]==health)
 local wall=Instance.new("Part");wall.Anchored=true;wall.Size=Vector3.new(8,8,.5);wall.Position=Vector3.new(0,36,-1.5);wall.Parent=workspace
 check("wake cannot pass a solid wall",#Hitboxes.GetTargets(actor,root,Profile,function(m)return Sleep.CanWakeAlly(actor,m)end)==0);wall:Destroy()
 allyRoot.CFrame=CFrame.new(0,36,3)
 check("wake cannot target behind attacker",Hitboxes.GetTargets(actor,root,Profile,function(m)return Sleep.CanWakeAlly(actor,m)end)[1]~=health)
 allyRoot.CFrame=CFrame.new(0,36,-7)
 check("wake retains melee range",Hitboxes.GetTargets(actor,root,Profile,function(m)return Sleep.CanWakeAlly(actor,m)end)[1]~=health)
 allyRoot.CFrame=CFrame.new(0,36,-3)
 Fighters.StunSpell(victim,1)
 actor:SetAttribute("RasenganHeld",true)
 local before,enemyBefore=health.Health,enemyHealth.Health
 check("missing epoch rejected",Combat.HandleRequest(player,1,actor)=="Rejected" and victim.sleep~=nil)
 check("stale epoch rejected",Combat.HandleRequest(player,1,actor,0)=="Rejected" and victim.sleep~=nil)
 check("client cannot inject a wake target",Combat.HandleRequest(player,1,actor,ally,state.roundId)=="Rejected" and victim.sleep~=nil)
 check("real basic request admitted",Combat.HandleRequest(player,1,actor,state.roundId)=="Started")
 check("wake happens once at attack-start",victim.sleep==nil and fighter.wakeOnlyAttackId==fighter.logic.attackSerial)
 check("wake preserves overlapping rigid stun",victim.logic.mode=="Stunned" and health.WalkSpeed==0)
 check("no offensive attack-start or friendly damage",offensive==0 and damageEvents==0 and health.Health==before)
 check("held spell marker remains",actor:GetAttribute("RasenganHeld")==true)
 task.wait(.3)
 check("wake swing never retargets enemy at impact",enemyHealth.Health==enemyBefore and health.Health==before and damageEvents==0)
 task.wait(.3)
 check("next ordinary attack is admitted",Combat.HandleRequest(player,2,actor,state.roundId)=="Started")
 task.wait(.25)
 check(string.format("next attack damages enemy only (HP %.2f/%.2f ally%.2f damage%d offensive%d root%s look%s)",enemyHealth.Health,enemyBefore,health.Health,damageEvents,offensive,tostring(root.Position),tostring(root.CFrame.LookVector)),enemyHealth.Health<enemyBefore and health.Health==before and damageEvents==1 and offensive==1)
 check("new attack clears old wake intent",fighter.wakeOnlyAttackId==nil)
 check("awake allies are not admitted",not Sleep.CanWakeAlly(actor,ally))
 check("self wake is denied",not Sleep.CanWakeAlly(actor,actor))
 Fighters.Sleep(victim,workspace:GetServerTimeNow())
 local field=Instance.new("ForceField");field.Parent=ally
 check("protected ally denied",not Sleep.CanWakeAlly(actor,ally));field:Destroy()
 Teams.RegisterNeutral(ally);check("neutral cannot impersonate an ally",not Sleep.CanWakeAlly(actor,ally));Teams.RemoveNeutral(ally)
 ally:SetAttribute("EntityKind","Tower");check("structures denied",not Sleep.CanWakeAlly(actor,ally));ally:SetAttribute("EntityKind","Hero")
 ally:SetAttribute("RoundId",0);check("old epoch target denied",not Sleep.CanWakeAlly(actor,ally));ally:SetAttribute("RoundId",1)
 actor:SetAttribute("RoundId",0);check("old epoch attacker denied",not Sleep.CanWakeAlly(actor,ally));actor:SetAttribute("RoundId",1)
 assert(victim.sleep);victim.sleep.untilAt=workspace:GetServerTimeNow()-1
 check("expired status cannot admit wake",not Sleep.CanWakeAlly(actor,ally))
 Fighters.Sleep(victim,workspace:GetServerTimeNow());state.phase="Finished"
 check("terminal cannot wake or damage",not Sleep.TryWakeAlly(actor,ally) and Damage.Apply(actor,health,50)==0)
 state.phase="InProgress";health.Health=0
 check("dead targets denied",not Sleep.CanWakeAlly(actor,ally))
 attackConnection:Disconnect();damageConnection:Disconnect();Sleep.Reset();Fighters.Reset();player:Destroy()
 print("[SleepWakeTests] ALL PASS "..count)
 return "passed"
end,function(e)return debug.traceback(tostring(e),2)end)
done=true;if not ok then warn("[SleepWakeTests] FAIL "..tostring(err))end
game:GetService("StudioTestService"):EndTest({suite="SleepWakeServer",ok=ok,count=count,error=if ok then nil else err})
