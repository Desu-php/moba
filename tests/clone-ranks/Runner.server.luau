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
local Summons=require(services.NarutoSummonService)
local count=0
local function check(name: string,ok: boolean) assert(ok,name); count+=1; print("[CloneRankTests] PASS: "..name) end
local function waitFor(fn: ()->boolean,seconds: number,name: string)
 local deadline=os.clock()+seconds; repeat if fn() then return end; task.wait(.02) until os.clock()>=deadline; error("Timeout: "..name)
end
local ok,err=xpcall(function()
 waitFor(function() return #Players:GetPlayers()==2 and Match.GetState()~=nil end,90,"clients")
 local match=Match.GetState(); assert(match); match.phase="Preparing"; match.preparationEnds=0
 waitFor(function() return match.phase=="InProgress" end,15,"match")
 match.startedAt=workspace:GetServerTimeNow()+10000; match.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(services.JungleService).Stop(); require(RS.Shared.Config.TowerConfig).Range=0; require(services.TowerService).CancelAll()
 local a,b=table.unpack(Players:GetPlayers())
 waitFor(function() return a.Character~=nil and b.Character~=nil and Naruto.Get(a)~=nil and Naruto.Get(b)~=nil end,20,"heroes")
 local actor,other=a.Character :: Model,b.Character :: Model
 actor:PivotTo(CFrame.new(0,36,0)); other:PivotTo(CFrame.new(25,36,-10))
 Progression.AddXP(a,100000); Progression.AddXP(b,100000)
 local pa,pb=Progression.Get(a),Progression.Get(b); assert(pa and pb)
 for _=1,2 do assert(Learning.learn(pa,"ShadowClones")) end
 for _=1,3 do assert(Learning.learn(pb,"ShadowClones")) end
 Progression.Publish(a); Progression.Publish(b); task.wait(.2)
 local sa,sb=Naruto.Get(a),Naruto.Get(b); assert(sa and sb)
 sa.pool.mana=1000; sb.pool.mana=1000
 local accepted,reason=Ability.HandleRequest(a,1,actor,"ShadowClones",Vector3.zero,match.roundId)
 check("rankII advanced point denied",not accepted and reason=="AdvancedPointPolicyUnknown" and sa.pool.mana>=1000 and sa.clones.cooldownAt==0)
 accepted=Ability.HandleRequest(a,2,actor,"ShadowClones",other,match.roundId)
  check("enemy Sleep is wakeable status",accepted and sa.clones.cooldownAt>0 and other:GetAttribute("SleepUntil")~=nil)
 local Fighters=require(services.FighterStateService);local victim=Fighters.Get(other);assert(victim);Fighters.WakeSleep(victim)
 sa.clones.cooldownAt=0 -- Fixture only: continue testing ordinary rank counts.
 task.wait(.5)
 local mana=sa.pool.mana
 check("rankII self through real boundary",Ability.HandleRequest(a,3,actor,"ShadowClones",match.roundId))
 check("exact200 debit rankII",math.abs(sa.pool.mana-(mana-200))<.1)
 check("rankIII self through real boundary",Ability.HandleRequest(b,1,other,"ShadowClones",match.roundId))
 check("cooldowns46and42",math.abs(sa.clones.cooldownAt-workspace:GetServerTimeNow()-46)<.1 and math.abs(sb.clones.cooldownAt-workspace:GetServerTimeNow()-42)<.1)
 waitFor(function() return actor:GetAttribute("NativeCloneCount")==4 and other:GetAttribute("NativeCloneCount")==5 end,2,"bursts")
 check("two owners produce4and5",actor:GetAttribute("NativeCloneCount")==4 and other:GetAttribute("NativeCloneCount")==5)
 local ownedA,ownedB=0,0
 local captured: Model?=nil
 for model,record in Summons.GetAll() do
  if record.owner==a or record.owner==b then
   if record.owner==a then ownedA+=1; captured=captured or model else ownedB+=1 end
   check("clone owns20second lifetime",record.clone.expiresAt>workspace:GetServerTimeNow()+19)
   check("original outgoing incoming",model:GetAttribute("OutgoingDamageMultiplier")==.3 and model:GetAttribute("IncomingDamageMultiplier")==20)
  end
 end
 check("no shared owner storage",ownedA==4 and ownedB==5)
 local points=pa.SkillPoints
 check("learnIII without retrofit",Learning.learn(pa,"ShadowClones") and pa.SkillPoints==points-1 and actor:GetAttribute("NativeCloneCount")==4)
 Progression.Publish(a)
 local manaBefore=sa.pool.mana
 task.wait(.5)
 accepted=Ability.HandleRequest(a,4,actor,"ShadowClones",match.roundId)
 check("learning retains committed cooldown",not accepted and sa.pool.mana>=manaBefore and sa.pool.mana-manaBefore<2)
 -- Deadline was pure-tested; advance it only inside this test fixture.
 sa.clones.cooldownAt=workspace:GetServerTimeNow(); task.wait(.5)
 check("new cast uses learnedIII",Ability.HandleRequest(a,5,actor,"ShadowClones",match.roundId))
 waitFor(function() return actor:GetAttribute("NativeCloneCount")==9 end,2,"new rank burst")
 check("old4 plus new5 remain distinct",captured~=nil and captured.Parent~=nil and actor:GetAttribute("NativeCloneCount")==9)
 accepted=Ability.HandleRequest(a,6,actor,"ShadowClones",match.roundId-1)
 check("stale round cannot summon",not accepted)
 local root=actor:FindFirstChild("HumanoidRootPart"); local hp=actor:FindFirstChildOfClass("Humanoid"); assert(root and root:IsA("BasePart") and hp); root:SetNetworkOwner(nil); hp.Health=0
 waitFor(function() return sa.clones.burst==nil end,1,"death burst cleanup")
 local safe=true; for _,clone in sa.clones.clones do if clone.hasPayload then safe=false end end
 check("death invalidates empowered payloads",safe)
 match.phase="Finished"; Naruto.Reset()
 check("terminal removes every owned entity",Summons.GetCount()==0 and next(sa.clones.clones)==nil and next(sb.clones.clones)==nil)
 print("[CloneRankTests] ALL PASS: "..count.." checks"); return "passed"
end,function(message) return debug.traceback(tostring(message),2) end)
if not ok then warn("[CloneRankTests] FAILED after "..count..": "..tostring(err)) end
