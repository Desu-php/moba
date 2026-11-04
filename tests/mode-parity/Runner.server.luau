--!strict
-- Opt-in Studio solo fixture, excluded from release projects. Restart Play afterward.
-- Sage expiry is accelerated explicitly; preparation and the full Kurama duration are real.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Dev=require(S.DeveloperCommandService)
local Naruto=require(S.NarutoAbilityService)
local Kcm=require(S.NarutoKcmService)
local Kurama=require(S.NarutoKuramaService)
local Stats=require(S.CharacterStatsService)
local Progression=require(S.HeroProgressionService)
local Ability=require(S.AbilityService)
local Match=require(S.MatchService)
local checks={}
local function check(ok:boolean,name:string)
 assert(ok,name); table.insert(checks,name)
 workspace:SetAttribute("ModeParityStage",name)
end
local function waitFor(fn:()->boolean,seconds:number,label:string)
 local deadline=os.clock()+seconds
 repeat if fn() then return end; task.wait(.05) until os.clock()>=deadline
 error("timeout: "..label)
end
local function run()
 waitFor(function() local m=Match.GetState();return m~=nil and m.phase=="InProgress" and #game.Players:GetPlayers()==1 end,30,"solo match")
 local p=game.Players:GetPlayers()[1];local c=p.Character;assert(c)
 local session=Naruto.Get(p);local profile=Progression.Get(p);assert(session and profile)
 local match=Match.GetState();assert(match)
 match.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(S.JungleService).Stop()
 local floor=Instance.new("Part");floor.Name="ModeParityFloor";floor.Anchored=true
 floor.Size=Vector3.new(120,2,120);floor.CFrame=CFrame.new(600,30,600);floor.Parent=workspace
 c:PivotTo(CFrame.new(600,35,600));task.wait(.7)
 for _,command in {"level 30","learnall","refresh"} do check(Dev.Execute(p,command),command) end
 local baseAttack=Stats.Get(p).AttackDamageBonus;local baseDefense=Stats.Get(p).Defense;local baseHealth=Stats.Get(p).MaxHealth
 local serial=0
 local function cast(id:string,target:any?):(boolean,string)
  task.wait(.13);serial+=1
  if target~=nil then return Ability.HandleRequest(p,serial,c,id,target,match.roundId) end
  return Ability.HandleRequest(p,serial,c,id,match.roundId)
 end
 local function expireSage()
  local sage=session.sage.active;assert(sage)
  sage.expiresAt=workspace:GetServerTimeNow()+.05
  waitFor(function() return session.sage.active==nil end,1,"Sage expiry")
  task.wait(.15)
 end
 local function finishQ()
  local q=session.q.active;assert(q);q.expiresAt=workspace:GetServerTimeNow()+.05
  waitFor(function() return session.q.active==nil end,1,"Q expiry")
 end
 local function cancelKcm()
  check(cast("KcmCancel"),"cancel KCM accepted")
  waitFor(function() return c:GetAttribute("KcmActive")==false end,2,"KCM exit")
 end
 local function sage()
  Dev.Execute(p,"refresh")
  check(cast("SageMode"),"Sage preparation accepted")
  waitFor(function() return c:GetAttribute("SagePhase")=="Active" end,5,"Sage III preparation")
  waitFor(function() return session.selfControlUntil<=workspace:GetServerTimeNow() end,1,"Sage control")
  check(session.sageTechniquesReady and c:GetAttribute("SageTechniquesReady")==true,"Sage enables technique readiness")
 end
 check(Dev.Execute(p,"rikudo"),"enter real Rikudo")
 check(Kcm.IsRikudo(p) and session.sageTechniquesReady,"Rikudo enables independent readiness")
 local mana=session.pool.mana;local ready=session.sage.cooldownAt
 check(not cast("SageMode"),"Rikudo denies new Sage via network")
 check(session.sage.active==nil and session.sage.cooldownAt==ready and session.pool.mana>=mana,"denied Sage has no resource or cooldown debit")
 c:SetAttribute("RikudoActive",false)
 check(not Naruto.TryCast(p,"SageMode",200,workspace:GetServerTimeNow(),nil),"authoritative active rank ignores forged display flag")
 c:SetAttribute("RikudoActive",true);cancelKcm()
 check(not session.sageTechniquesReady,"Rikudo exit clears readiness")
 for rank=1,2 do
  profile.Learned.KCM=rank;Progression.Publish(p);Dev.Execute(p,"refresh")
  check(cast("KCM"),"KCM "..rank.." entry")
  sage()
  local active=session.sage.active;assert(active);local expiry=active.expiresAt
  check(Stats.Get(p).AttackDamageBonus==baseAttack+50+(if rank==1 then 25 else 50),"KCM "..rank.." and Sage add attack")
  check(Stats.Get(p).Defense==baseDefense+15+(if rank==1 then 5 else 10),"KCM "..rank.." and Sage add armor")
  check(Stats.Get(p).MaxHealth==baseHealth+300,"Sage health remains one owned layer")
  if rank==1 then
   cancelKcm()
   check(session.sage.active==active and active.expiresAt==expiry,"KCM exit preserves same Sage cast and deadline")
   check(Stats.Get(p).AttackDamageBonus==baseAttack+50 and not session.sageTechniquesReady,"KCM exit removes only KCM stats and clears readiness")
   profile.Learned.Rasengan=2;Progression.Publish(p)
   check(cast("Rasengan"),"Q after KCM exit")
   local q=session.q.active;assert(q)
   check(q.sagePrepared==false,"remaining Sage stats alone do not grant Sage Rasengan bonus")
   check(cast("Odama"),"rank II Odama works with remaining Sage stats")
   finishQ();expireSage()
  else
   check(Dev.Execute(p,"rikudo"),"upgrade to Rikudo with surviving Sage")
   check(session.sage.active==active and active.expiresAt==expiry and session.sageTechniquesReady,"Rikudo preserves Sage deadline and sets readiness")
   check(Stats.Get(p).AttackDamageBonus==baseAttack+150,"Rikudo replaces KCM II layer without stacking both")
   expireSage()
   check(Kcm.IsRikudo(p) and session.sageTechniquesReady and Stats.Get(p).AttackDamageBonus==baseAttack+100,"Sage expiry removes its stats but retains Rikudo readiness")
   cancelKcm()
  end
 end
 check(Stats.Get(p).AttackDamageBonus==baseAttack and Stats.Get(p).Defense==baseDefense and Stats.Get(p).MaxHealth==baseHealth,"all owned bonuses cleanly removed")
 profile.Learned.KCM=2;profile.Learned.Rasengan=3;Progression.Publish(p)
 sage()
 local chakra=c:GetAttribute("KuramaChakra") :: number
 check(not cast("KCM"),"Sage-first blocks KCM entry")
 check((c:GetAttribute("KuramaChakra") :: number)>=chakra,"blocked KCM does not debit chakra")
 check(cast("Rasengan"),"ordinary Sage Q")
 local q=session.q.active;assert(q)
 check(q.sagePrepared==true,"Q captures Sage-specific damage branch")
 expireSage()
 check(session.q.active==q and q.sagePrepared==true,"Sage expiry preserves already prepared Rasengan bonus")
 finishQ()
 check(Dev.Execute(p,"rikudo"),"refill separate chakra for Kurama fixture");cancelKcm()
 profile.Learned.KCM=2;Progression.Publish(p)
 sage()
 local active=session.sage.active;assert(active);local expiry=active.expiresAt
 check(cast("KuramaForm"),"Sage-first permits full Kurama")
 check(Kurama.IsActive(p) and Stats.Get(p).AttackDamageBonus==baseAttack+140,"full Kurama and Sage add bonuses")
 check(not cast("KCM"),"full Kurama excludes KCM")
 session.pool.mana=session.pool.maximum
 local before=session.pool.mana
 check(cast("ShadowClones"),"Kurama clone cast")
 local burst=session.clones.burst;assert(burst)
 check(session.pool.mana>=before-201,"Kurama clones have only base mana debit")
 waitFor(function() return session.clones.burst==nil end,2,"Kurama clone burst")
 waitFor(function() return c:GetAttribute("NativeCloneCount")==4 end,1,"replicated clone count")
 check(c:GetAttribute("NativeCloneCount")==4,"full Kurama creates exactly four real clones")
 workspace:SetAttribute("ModeParityStage","waiting for natural Kurama release")
 waitFor(function() return not Kurama.IsLocked(p) end,32,"natural Kurama release")
 check(session.sage.active==active and active.expiresAt==expiry and session.sageTechniquesReady,"Kurama release preserves Sage timer and readiness")
 check(Stats.Get(p).AttackDamageBonus==baseAttack+50,"Kurama release removes only its own bonus")
 waitFor(function() return c:GetAttribute("KcmAllowed")==true end,1,"restored KCM admission")
 Dev.Execute(p,"refresh")
 check(cast("KCM"),"Kurama release restores KCM despite remaining Sage")
 check(Stats.Get(p).AttackDamageBonus==baseAttack+100,"restored KCM composes with remaining Sage")
 c:FindFirstChildOfClass("Humanoid").Health=0
 waitFor(function() return not session.sageTechniquesReady and session.sage.active==nil and not Kcm.IsRikudo(p) end,2,"death cleanup")
 check(true,"death clears independent states")
end
local ok,err=pcall(run)
workspace:SetAttribute("ModeParityQA",game:GetService("HttpService"):JSONEncode({ok=ok,checks=checks,error=if ok then nil else tostring(err)}))
assert(ok,tostring(err));print("PASS map mode parity: "..#checks.." checks")
