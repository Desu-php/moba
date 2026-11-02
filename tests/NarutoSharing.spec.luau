--!strict
local S=require("../src/shared/Abilities/NarutoSharingState")
local n=0
local function check(name: string,ok: boolean) assert(ok,name); n+=1 end
local policy={mana=17,range=700} -- Explicit TEST policy. Not native admission evidence.
local function target(id: string,hero: boolean?): S.Target
 return {id=id,life=1,epoch=1,alive=true,ally=true,hero=hero~=false,structure=false,illusion=false,rawtype="ordinary",
 excludedIdentity=false,susanoo=false,distance=0}
end
local function count(events: {S.Event},kind: string): number local result=0; for _,e in events do if e.kind==kind then result+=1 end end; return result end
local function grants(s: S.State): number local result=0; for _ in s.grants do result+=1 end; return result end
local s=S.new("owner",1,1,0); local self=target("owner"); local hero=target("hero"); local creep=target("creep",false)
local ok,why,cost,out=S.request(s,0,true,1000,0,{self,hero,creep},nil)
check("nativeadmission unknown defaultdisabled",not ok and why=="NativeAdmissionUnknown" and cost==0 and #out==0 and grants(s)==0 and s.cooldownAt==0)
check("unknown is not zero nativecost",S.Policy.Admission=="DefaultDisabledUnknownCostRange")
check("no cast without KCM",select(2,S.request(s,0,false,1000,0,{hero},policy))=="Form")
check("callerpolicy range",select(2,S.request(s,0,true,1000,701,{hero},policy))=="Range")
check("callerpolicy mana",select(2,S.request(s,0,true,16,0,{hero},policy))=="Mana")
ok,why,cost,out=S.request(s,0,true,1000,700,{self,hero,creep},policy)
check("explicittestpolicy recognized",ok and why=="PolicyAccepted" and cost==17)
check("nonhero included selfexcluded",grants(s)==2 and s.grants.owner==nil)
check("self heal+rawspecificcleanse",count(out,"SelfHeal")==1 and count(out,"RemoveAmaterasuRawWithin25")==1)
local grantHero=s.grants.hero; local grantCreep=s.grants.creep
for _,e in out do
 if e.target=="hero" then check("hero owned15stats",e.grant==grantHero.id and e.strength==15 and e.agility==15) end
 if e.target=="creep" then check("nonhero rawabilities noherostats",e.grant==grantCreep.id and e.strength==0 and e.agility==0) end
end
check("self lock61 expiry100",s.selfLockUntil==61 and s.expiresAt==100)
check("sourceCD1",select(2,S.request(s,.999,true,1000,0,{hero},policy))=="Cooldown")
local current={hero=hero,creep=creep}
out=S.update(s,1,true,current); check("callback1 self350",count(out,"SelfHeal")==1 and out[1].amount==350)
ok,why,cost,out=S.request(s,1,true,1000,0,{self,hero,creep},policy)
check("duplicatecast no duplicatedstatgrant",ok and #out==0 and s.grants.hero.id==grantHero.id and s.expiresAt==101)
out=S.update(s,2,true,current); check("callback2 self350",count(out,"SelfHeal")==1)
out=S.update(s,3,true,current); check("no fourth selfheal",count(out,"SelfHeal")==0)
local paid; paid,out=S.pay(s,3,8,1000); check("4per2recipients",paid==8 and #out==0)
paid=S.pay(s,3,8,1000); check("samephase no duplicate bill",paid==0)
paid,out=S.pay(s,4,1000,1000); check("threshold skips all bills",paid==0 and grants(s)==2)
paid,out=S.pay(s,5,7,1000); check("insufficient revokes all owned inclA0FT",paid==0 and grants(s)==0 and #out==2 and out[1].kind=="RemoveA0FT_A092_Asp5")
for _,e in out do
 if e.target=="hero" then check("hero stats removedonce",e.strength==-15 and e.agility==-15 and e.grant==grantHero.id) end
 if e.target=="creep" then check("nonhero no bogus subtract15",e.strength==0 and e.agility==0) end
end
check("repeatclear idempotent",#S.clear(s)==0)
for _,field in {"structure","illusion","excludedIdentity","susanoo"} do
 local t=target("bad"); (t :: any)[field]=true; check("filter excludes "..field,not S.eligible(t))
end
for _,raw in {"Hpb2","Huth"} do local t=target("bad"); t.rawtype=raw; check("rawtype exclude "..raw,not S.eligible(t)) end
local t=target("bad"); t.alive=false; check("dead exclusion",not S.eligible(t)); t=target("bad"); t.ally=false; check("enemy exclusion",not S.eligible(t))
t=target("bad"); t.distance=200; check("radius200 inclusive",S.eligible(t)); t.distance=200.001; check("radius200 over",not S.eligible(t))
t=target("bad"); t.life=0/0; check("invalid recipient identity",not S.eligible(t))
s=S.new("owner",1,1,0); S.request(s,0,true,1000,0,{self,hero},policy)
S.update(s,60,true,{hero=hero}); ok,why,cost,out=S.request(s,60,true,1000,0,{self},policy)
check("selfstilllocked at60",ok and count(out,"SelfHeal")==0)
ok,why,cost,out=S.request(s,61,true,1000,0,{self},policy)
check("selfunlocked atcallback61",ok and count(out,"SelfHeal")==1 and s.selfLockUntil==122)
s=S.new("owner",1,1,0); S.request(s,0,true,1000,0,{hero},policy)
out=S.update(s,99.999,true,{hero=hero}); check("group100 not early",#out==0 and grants(s)==1)
out=S.update(s,100,true,{hero=hero}); check("single owner expiry100",#out==1 and grants(s)==0)
s=S.new("owner",1,1,0); S.request(s,0,true,1000,0,{hero},policy)
check("newcasts disabled afterKCMexit",select(2,S.request(s,1,false,1000,0,{hero},policy))=="Form")
check("existing grants survive KCMexit",#S.update(s,1,true,{hero=hero})==0 and grants(s)==1)
hero.life=2; out=S.update(s,2,true,{hero=hero}); check("recipientrespawn removesoldgrant",#out==1 and grants(s)==0)
S.request(s,3,true,1000,0,{hero},policy); hero.alive=false; out=S.update(s,4,true,{hero=hero})
check("recipientdeath cleanup",#out==1 and grants(s)==0); hero.alive=true
s=S.new("owner",1,1,0); S.request(s,0,true,1000,0,{self,hero},policy); out=S.update(s,.5,false,{hero=hero})
check("ownerdeath closes andcleansonce",s.closed and grants(s)==0 and #out==1 and #S.update(s,1,false,{hero=hero})==0)
check("no stale selfheal afterdeath",s.selfAt==nil and #S.update(s,2,true,{hero=hero})==0)
check("closed session cannot recreategrants",select(2,S.request(s,3,true,1000,0,{hero},policy))=="Closed")
s=S.new("owner",1,1,0); local second=S.new("other",1,1,0)
S.request(s,0,true,1000,0,{hero},policy); S.request(second,0,true,1000,0,{hero},policy)
check("twoowners grantids separate",s.grants.hero.id~=second.grants.hero.id)
local accepted; accepted,out=S.cancel(s,0); check("cancel clearsownonly",accepted and grants(s)==0 and grants(second)==1)
check("downcommand2s guard",not S.cancel(s,1)); check("downcommandreenables2",S.cancel(s,2))
s=S.new("owner",1,1,0); S.request(s,0,true,1000,0,{hero},policy)
check("staledispel cannot remove newlifegrant",#S.revoke(s,"hero",1,1)==0 and grants(s)==1)
out=S.revoke(s,"hero",hero.life,1); check("explicitdispel removes exactlyownedgrant",#out==1 and grants(s)==0 and #S.revoke(s,"hero",hero.life,1)==0)
check("native effect identities retain rawunknowns",S.Native.A0FT_isr2==.35 and S.Native.A092_Slo1==.1 and S.Native.Asp5=="RawAbilityIdentityNoInventedResistance")
print("ALL PASS: "..n.." sharing admission/grant/timer/filter/ownership checks; no sharing runtime enabled")
