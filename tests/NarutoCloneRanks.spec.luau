--!strict
local Policy=require("../src/shared/Abilities/NarutoRankPolicy")
local Learning=require("../src/shared/Abilities/SkillLearning")
local Definitions=require("../src/shared/Abilities/NarutoDefinitions")
local Clone=require("../src/shared/Abilities/CloneState")
local W=Clone.configure(Definitions.Clones)
local count=0
local function check(name: string,ok: boolean) assert(ok,name); count+=1 end
local p: Learning.Profile={Level=1,SkillPoints=10,Learned={}}
local a,b=Clone.new("A",1,1),Clone.new("B",1,1)
local previous: Clone.Clone?=nil
for rank=1,3 do
 local required=1+4*(rank-1)
 if rank>1 then
  p.Level=required-1; local points=p.SkillPoints
  check("no premature learning "..rank,not Learning.learn(p,"ShadowClones") and p.SkillPoints==points)
 end
 p.Level=required
 check("sequential learning "..rank,Learning.learn(p,"ShadowClones") and p.Learned.ShadowClones==rank and p.SkillPoints==10-rank)
 local plan=Policy.ordinaryClonePlan(p.Learned.ShadowClones,"OrdinarySelf"); assert(plan)
 local now=(rank-1)*60
 local burst,why=W.begin(a,now,rank,plan.count,plan.cooldown); assert(burst,why)
 check("rank snapshot count/CD "..rank,burst.remaining==rank+2 and a.cooldownAt==now+50-4*(rank-1))
 local spawned=0; local first: Clone.Clone?=nil
 while a.burst do
  local clone=W.spawnOne(a,burst,now+1+spawned*.02,true,true); assert(clone)
  first=first or clone; spawned+=1
  check("payload and full baseHP multipliers "..rank,clone.hasPayload and clone.outgoingMultiplier==.3 and clone.incomingMultiplier==20)
  check("twenty seconds from spawn "..rank,math.abs(clone.expiresAt-(now+1+(spawned-1)*.02)-20)<1e-8)
 end
 assert(first)
 check("complete bounded burst "..rank,spawned==rank+2 and W.spawnOne(a,burst,now+2,true,true)==nil)
 if previous then check("learning does not retrofit old clone",previous.outgoingMultiplier==.3 and previous.id<first.id) end
 previous=first
 check("other owner remains isolated "..rank,b.burst==nil and b.cooldownAt==0 and next(b.clones)==nil)
 local duplicate,reason=W.begin(a,now+2,rank,plan.count,plan.cooldown)
 check("replay cannot start second burst "..rank,not duplicate and reason=="Replay")
 if rank>1 then check("advanced point closed "..rank,Policy.ordinaryClonePlan(rank,"OrdinaryPoint")==nil) end
 check("enemy branch remains closed "..rank,Policy.ordinaryClonePlan(rank,"EnemySleep")==nil)
end
local points=p.SkillPoints; p.Level=30
check("IV cannot spend a point",not Learning.learn(p,"ShadowClones") and p.SkillPoints==points and p.Learned.ShadowClones==3)
p.Learned.Rasengan=1
check("Q II cannot spend on metadata alone",not Learning.learn(p,"Rasengan") and p.SkillPoints==points)
local old=previous; assert(old)
Clone.newLife(a,2)
check("death invalidates old payload",not old.hasPayload and Clone.takePayload(a,old,130,"Enemy",true,false)==nil)
check("cooldown retained across life",a.cooldownAt==162)
Clone.reset(a,2,3)
check("reset clears every burst and clone",a.burst==nil and next(a.clones)==nil and a.cooldownAt==0 and a.round==2)
check("first level remains explicitly provisional",Learning.NativePolicy.CloneFirstLevel==1 and Learning.NativePolicy.CloneFirstLevelStatus=="CallerSelectedNativeBoundary")
print("PASS Naruto clone rank integration: "..count.." assertions")
