--!strict
local G=require("../src/shared/Abilities/GamakichiState")
local Learning=require("../src/shared/Abilities/SkillLearning")
local count=0
local function check(name: string,ok: boolean) assert(ok,name); count+=1 end
for rank=1,10 do
 local cost,cd,duration,p=G.rank(rank); assert(p)
 check("source cost "..rank,cost==(if rank<=4 then 50 elseif rank<=8 then 150 else 300))
 check("source cooldown/lifetime "..rank,cd==(if rank<=5 then 60 else 150) and duration==5+5*rank)
 check("source profile "..rank,p.health==(if rank<=5 then 500 else 1500) and p.rawDamage==(if rank<=5 then 41 else 101) and p.adult==(rank>=6))
end
check("no rank11",G.rank(11)==nil)
check("reject invalid ranks",G.rank(0)==nil and G.rank(1.5)==nil and G.rank(0/0)==nil)
local a,b=G.new(),G.new()
local cast,reason,cost=G.request(a,10,1,4,50); assert(cast)
check("one cast and exact debit",reason=="Accepted" and cost==50 and cast.rank==4 and a.active==cast)
check("hero isolation",b.active==nil and b.cooldownAt==0)
check("cooldown committed once",a.cooldownAt==70 and not G.request(a,11,2,5,1000))
check("replay rejected",not G.request(a,80,2,5,1000))
check("failed request preserves summon",a.active==cast)
check("before expiry",G.live(a,cast,34.999))
check("expiry boundary",G.expire(a,35) and a.active==nil and not G.expire(a,35))
check("expiry retains cooldown",a.cooldownAt==70)
local denied=G.request(b,0,1,1,49)
check("mana denial no cooldown",not denied and b.active==nil and b.cooldownAt==0)
local fresh=G.request(a,70,3,6,150); assert(fresh)
check("next cast snapshots adult profile",fresh.profile.adult and fresh.profile.health==1500 and cast.profile.health==500)
G.cancel(a)
check("cancel invalidates old cast without refund",not G.live(a,fresh,71) and a.cooldownAt==220)
check("no stale cast resurrection",not G.live(a,cast,12))
local profile={Level=1,SkillPoints=30,Learned={} :: {[string]:number}}
for rank=1,10 do
 profile.Level=1+2*(rank-1)
 check("learn rank "..rank,Learning.learn(profile,"Gamakichi"))
 if rank<10 then check("skip2 gate "..rank,Learning.reason(profile,"Gamakichi")=="Level") end
end
check("rank cap without spend",Learning.reason(profile,"Gamakichi")=="MaxRank" and profile.SkillPoints==20)
check("forms remain unavailable",Learning.reason(profile,"SageMode")=="NotImplemented" and Learning.reason(profile,"KCM")=="NotImplemented")
print("PASS Gamakichi: "..count.." assertions")
