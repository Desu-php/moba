--!strict
assert(game:GetService("RunService"):IsStudio())
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local services=game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match=require(services.MatchService)
local Progression=require(services.HeroProgressionService)
local Learning=require(RS.Shared.Abilities.SkillLearning)
local Ability=require(services.AbilityService)
local Naruto=require(services.NarutoAbilityService)
local Gama=require(services.GamakichiService)
local Oil=require(services.OilStatusService)
local Fighters=require(services.FighterStateService)
local Damage=require(services.DamageService)
local count=0
local function check(name: string,ok: boolean,_reason: string?) assert(ok,name); count+=1; print("[GamakichiSpellsTests] PASS: "..name) end
local function waitFor(fn: () -> boolean,seconds: number,name: string)
 local limit=os.clock()+seconds; repeat if fn() then return end; task.wait(.02) until os.clock()>=limit; error("Timeout: "..name)
end
local models:{Model}={}
local ok,err=xpcall(function()
 waitFor(function() return #Players:GetPlayers()==2 and Match.GetState()~=nil end,90,"two clients")
 local state=Match.GetState(); assert(state); state.phase="Preparing"; state.preparationEnds=0
 waitFor(function() return state.phase=="InProgress" end,15,"match start")
 state.startedAt=workspace:GetServerTimeNow()+10000; state.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(services.JungleService).Stop(); require(RS.Shared.Config.TowerConfig).Range=0; require(services.TowerService).CancelAll()
 local a,b=table.unpack(Players:GetPlayers())
 waitFor(function() return a.Character~=nil and b.Character~=nil and Naruto.Get(a)~=nil and Naruto.Get(b)~=nil end,20,"heroes")
 local actor=a.Character :: Model; local other=b.Character :: Model
 actor:PivotTo(CFrame.new(0,36,0)); other:PivotTo(CFrame.new(12,36,-12))
 Progression.AddXP(a,100000)
 local pa,pb=Progression.Get(a),Progression.Get(b); assert(pa and pb)
 for _=1,6 do assert(Learning.learn(pa,"Gamakichi")) end
 assert(Learning.learn(pb,"Gamakichi")); Progression.Publish(a); Progression.Publish(b)
 check("adult summon admitted",Ability.HandleRequest(a,1,actor,"Gamakichi",state.roundId))
 check("early summon admitted",Ability.HandleRequest(b,1,other,"Gamakichi",state.roundId))
 local r,early=Gama.Get(a),Gama.Get(b); assert(r and early)
 local function dummy(name: string,team: string,position: Vector3): (Model,Humanoid)
  local m=Instance.new("Model"); m.Name=name; local p=Instance.new("Part"); p.Name="HumanoidRootPart"; p.Anchored=true; p.Size=Vector3.new(2,4,2); p.Position=position; p.Parent=m
  local h=Instance.new("Humanoid"); h.MaxHealth=10000; h.Health=10000; h.Parent=m; m.PrimaryPart=p
  m:SetAttribute("TeamId",team); m:SetAttribute("RoundId",state.roundId); m:SetAttribute("EntityKind","Minion"); m:SetAttribute("MinionType","Melee"); m.Parent=workspace
  Fighters.GetOrCreate(m); table.insert(models,m); return m,h
 end
 local target,hp=dummy("OilEnemy",tostring(other:GetAttribute("TeamId")),Vector3.new(8,36,-12))
 local ally,allyHP=dummy("OilAlly",tostring(actor:GetAttribute("TeamId")),Vector3.new(7,36,-12))
 local immune=dummy("OilForceField",tostring(other:GetAttribute("TeamId")),Vector3.new(9,36,-12)); Instance.new("ForceField").Parent=immune
 local session=Naruto.Get(a); assert(session)
 local far=dummy("OutOfRange",tostring(other:GetAttribute("TeamId")),Vector3.new(100,36,-12))
 local bad,why=Ability.HandleRequest(a,2,actor,"GamakichiOil",ally,state.roundId)
 check("allied target rejected",not bad and why=="Target" and r.spells.oilReady==0)
 bad,why=Ability.HandleRequest(a,3,actor,"GamakichiOil",far,state.roundId)
 check("oil range enforced",not bad and why=="Target" and r.spells.oilReady==0)
 bad,why=Ability.HandleRequest(a,4,actor,"GamakichiChop",Vector3.new(0/0,36,0),state.roundId)
 check("nonfinite channel point rejected",not bad and why=="Target" and r.spells.chopReady==0)
 task.wait(.5)
 local wall=Instance.new("Part"); wall.Name="SpellWall"; wall.Anchored=true; wall.Size=Vector3.new(8,8,1); wall.Position=Vector3.new(8,36,-6); wall.Parent=workspace
 bad,why=Ability.HandleRequest(a,5,actor,"GamakichiOil",target,state.roundId)
 check("solid wall blocks cast",not bad and why=="Target" and r.spells.oilReady==0); wall:Destroy()
 task.wait(.5)
 local mana=session.pool.mana; local toadMana=r.model:GetAttribute("Mana")
 check("oil through real boundary",Ability.HandleRequest(a,6,actor,"GamakichiOil",target,state.roundId))
 waitFor(function() return target:GetAttribute("OilUntil")~=nil end,2,"oil arrival")
 check("zero native costs preserve pools",session.pool.mana>=mana and r.model:GetAttribute("Mana")==toadMana)
 check("oil affects enemy and nearby hero",Oil.Movement(target,workspace:GetServerTimeNow())==.6 and Oil.Movement(other,workspace:GetServerTimeNow())==.6)
 check("oil does not affect allies/ForceField",ally:GetAttribute("OilUntil")==nil and immune:GetAttribute("OilUntil")==nil)
 check("oil movement40percent",math.abs((other:FindFirstChildOfClass("Humanoid") :: Humanoid).WalkSpeed-9.6)<.01)
 Fighters.SetWalkSpeed(other,20)
 check("base-stat update under oil not double slow",math.abs((other:FindFirstChildOfClass("Humanoid") :: Humanoid).WalkSpeed-12)<.01)
 local before=allyHP.Health; check("spell damage never rolls oil miss",Damage.Apply(other,allyHP,20)==20 and allyHP.Health==before-20)
 task.wait(.5)
 local rejected,reason=Ability.HandleRequest(a,7,actor,"GamakichiOil",target,state.roundId)
 check("oil independent cooldown",not rejected and reason=="Cooldown")
 local oldReady=r.spells.chopReady
 check("stale epoch denied",not Ability.HandleRequest(a,8,actor,"GamakichiChop",Vector3.new(8,36,-12),state.roundId-1) and r.spells.chopReady==oldReady)
 check("early toad cannot channel",not Ability.HandleRequest(b,2,other,"GamakichiChop",Vector3.new(12,36,-10),state.roundId))
 Oil.Update(workspace:GetServerTimeNow()+7)
 check("expiry restores latest base speed",(other:FindFirstChildOfClass("Humanoid") :: Humanoid).WalkSpeed==20 and target:GetAttribute("OilUntil")==nil)
 local kills=pa.TotalMinionKills
 local killTarget,killHP=dummy("ChannelKill",tostring(other:GetAttribute("TeamId")),Vector3.new(8,36,-13)); killHP.Health=120
 local beforeChannel=hp.Health; local beforeAlly=allyHP.Health
 task.wait(.5)
 check("adult channel admitted",Ability.HandleRequest(a,9,actor,"GamakichiChop",Vector3.new(8,36,-12),state.roundId))
 task.wait(.25); check("no damage during preparation",hp.Health==beforeChannel and r.spells.channel~=nil)
 waitFor(function() return r.model:GetAttribute("ChannelWave")==4 end,5,"four runtime waves")
 check("four waves120 no passive damage",hp.Health==beforeChannel-480 and r.spells.channel==nil)
 check("channel excludes ally and shield",allyHP.Health==beforeAlly and (immune:FindFirstChildOfClass("Humanoid") :: Humanoid).Health==10000)
 waitFor(function() return pa.TotalMinionKills==kills+1 end,1,"channel owner credit")
 check("channel owner credited once",pa.TotalMinionKills==kills+1 and (killTarget:FindFirstChildOfClass("Humanoid") :: Humanoid).Health==0)
 local after=hp.Health; task.wait(.2); check("channel ends permanently",hp.Health==after)
 -- Explicit test-only deadline advances: pure tests cover cooldown/time boundaries.
 r.spells.chopReady=workspace:GetServerTimeNow(); task.wait(.5)
 check("new channel for interruption",Ability.HandleRequest(a,10,actor,"GamakichiChop",Vector3.new(8,36,-12),state.roundId))
 local fighter=Fighters.Get(r.model); assert(fighter); Fighters.StunSpell(fighter,1)
 waitFor(function() return r.spells.channel==nil end,1,"stun cancel")
 check("stun cancels future waves retains cooldown",r.spells.chopReady>workspace:GetServerTimeNow() and hp.Health==after)
 task.wait(1.1)
 r.spells.oilReady=workspace:GetServerTimeNow()
 Oil.Apply(target,tostring(a.UserId)..":"..tostring(r.cast.id),workspace:GetServerTimeNow())
 check("new oil before owner death",Ability.HandleRequest(a,11,actor,"GamakichiOil",target,state.roundId))
 local late=r.spells.flight; assert(late);
 (actor:FindFirstChildOfClass("Humanoid") :: Humanoid).Health=0
 waitFor(function() return Gama.Get(a)==nil end,1,"owner death cleanup")
 check("no stale projectile grant",r.spells.flight==nil and target:GetAttribute("OilUntil")==nil)
 local sourceKey=tostring(b.UserId)..":"..tostring(early.cast.id)
 Oil.Apply(target,sourceKey,workspace:GetServerTimeNow())
 early.cast.expiresAt=workspace:GetServerTimeNow()
 waitFor(function() return Gama.Get(b)==nil and target:GetAttribute("OilUntil")==nil end,1,"summon expiry oil cleanup")
 check("summon expiry clears owned slow",target:GetAttribute("OilUntil")==nil)
 local otherSession=Naruto.Get(b); assert(otherSession); otherSession.gama.cooldownAt=workspace:GetServerTimeNow()
 check("new summon for terminal test",Ability.HandleRequest(b,3,other,"Gamakichi",state.roundId))
 local terminal=Gama.Get(b); assert(terminal)
 Oil.Apply(target,tostring(b.UserId)..":"..tostring(terminal.cast.id),workspace:GetServerTimeNow())
 state.phase="Finished"
 waitFor(function() return Gama.Get(b)==nil and target:GetAttribute("OilUntil")==nil end,1,"terminal cleanup")
 check("terminal clears all owned statuses",Gama.Get(b)==nil and Oil.Movement(target,workspace:GetServerTimeNow())==1)
 for _,model in models do Fighters.Remove(model); model:Destroy() end
 print("[GamakichiSpellsTests] ALL PASS: "..count.." checks")
 return "passed"
end,function(message) return debug.traceback(tostring(message),2) end)
if not ok then warn("[GamakichiSpellsTests] FAILED after "..count..": "..tostring(err)) end
