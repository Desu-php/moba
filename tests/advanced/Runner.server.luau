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
local Fighters=require(services.FighterStateService)
local Damage=require(services.DamageService)
local Summons=require(services.NarutoSummonService)
local count=0
local function check(name: string,ok: boolean) assert(ok,name);count+=1;print("[AdvancedTests] PASS "..name) end
local function waitFor(fn: ()->boolean,seconds: number)
 local deadline=os.clock()+seconds;repeat if fn() then return end;task.wait(.02) until os.clock()>=deadline;error("Timeout")
end
local ok,err=xpcall(function()
 waitFor(function() return #Players:GetPlayers()==2 and Match.GetState()~=nil end,90)
 local match=Match.GetState();assert(match);match.phase="Preparing";match.preparationEnds=0
 waitFor(function() return match.phase=="InProgress" end,15)
 match.startedAt=workspace:GetServerTimeNow()+10000;match.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(services.JungleService).Stop();require(RS.Shared.Config.TowerConfig).Range=0;require(services.TowerService).CancelAll()
 local a,b=table.unpack(Players:GetPlayers())
 waitFor(function() return a.Character~=nil and b.Character~=nil and Naruto.Get(a)~=nil and Naruto.Get(b)~=nil end,20)
 local actor,enemy=a.Character :: Model,b.Character :: Model
 actor:PivotTo(CFrame.new(0,36,0));enemy:PivotTo(CFrame.new(10,36,0))
 for _,model in {actor,enemy} do local ff=model:FindFirstChildOfClass("ForceField");if ff then ff:Destroy() end end
 Progression.AddXP(a,100000);local p=Progression.Get(a);assert(p)
 for _=1,3 do assert(Learning.learn(p,"Rasengan")) end
 for _=1,4 do assert(Learning.learn(p,"ShadowClones")) end
 Progression.Publish(a);task.wait(.2)
 local sa=Naruto.Get(a);assert(sa);sa.pool.mana=sa.pool.maximum
 check("ordinary Q admitted",Ability.HandleRequest(a,1,actor,"Rasengan",match.roundId))
 check("Odama selected in first window",Ability.HandleRequest(a,2,actor,"Odama",match.roundId))
 task.wait(.4)
 check("RS selected in second window",Ability.HandleRequest(a,3,actor,"Rasenshuriken",match.roundId))
 local cast=sa.q.active;assert(cast)
 check("three debits and inherited Q cooldown",sa.pool.mana<sa.pool.maximum-499 and sa.q.cooldownAt>workspace:GetServerTimeNow()+58)
 check("RS state and timings",cast.variant=="Rasenshuriken" and cast.stun==4.5 and cast.impactDelay==.5)
 local before=sa.pool.mana
 check("replay denied without extra debit",not Ability.HandleRequest(a,3,actor,"Rasenshuriken",match.roundId) and sa.pool.mana-before<1)
 task.wait(2)
 local target=Fighters.GetOrCreate(enemy);assert(target)
 sa.pool.mana=sa.pool.maximum
 check("noncanonical sleep rejected",not Ability.HandleRequest(a,4,actor,"ShadowSleep",enemy,match.roundId))
 check("targeted clone request cannot bypass removal",not Naruto.TryCast(a,"ShadowClones",100,workspace:GetServerTimeNow(),enemy))
 check("rejected sleep has no effect",target.sleep==nil)
 -- Only fixture-owned deadlines are advanced; production cooldowns are unchanged.
 sa.clones.cooldownAt=0;sa.pool.mana=sa.pool.maximum
 check("mass IV request",Ability.HandleRequest(a,5,actor,"ShadowClones",match.roundId))
 waitFor(function() return actor:GetAttribute("NativeCloneCount")==30 end,3)
 check("exact30 full-HP battle clones",Summons.GetCount()==30)
 for model,r in Summons.GetAll() do
  check("source modifiers retained",r.humanoid.MaxHealth==(actor:FindFirstChildOfClass("Humanoid") :: Humanoid).MaxHealth and model:GetAttribute("OutgoingDamageMultiplier")==.3 and model:GetAttribute("IncomingDamageMultiplier")==20)
 end
 Naruto.Reset();check("reset removes every summon",Summons.GetCount()==0)
 check("reset clears selection cooldowns",sa.variants.choice==nil and next(sa.variants.cooldowns)==nil)
 print("[AdvancedTests] ALL PASS "..count); return true
end,function(message) return debug.traceback(tostring(message),2) end)
if not ok then warn("[AdvancedTests] FAILED "..tostring(err)) end
