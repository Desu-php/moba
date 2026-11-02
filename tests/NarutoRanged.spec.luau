--!strict
local R=require("../src/shared/Abilities/NarutoRangedState")
local Knife=require("../src/shared/Abilities/ChakraKnifeInstancePolicy")
local checks=0
local function check(ok: boolean,name: string) assert(ok,name);checks+=1 end
local function near(a: number,b: number): boolean return math.abs(a-b)<1e-8 end
local function grant(id: string,owner: string?): R.Grant
 return {ownerId=owner or "A",round=1,life=1,abilityId=id,expiresAt=20,
  form="Ewrd",kcmRank=3,heroLevel=27,hagoromo=true}
end
local function state(owner: string?): R.State return R.new(owner or "A",1,1,0) end
local origin={x=0,z=0};local destination={x=90,z=0}
local function selectEvents(events: {R.Event},kind: string): {R.Event}
 local selected: {R.Event}={};for _,e in events do if e.kind==kind then table.insert(selected,e) end end;return selected
end
local function str16(_at: number): number return 16 end
local a,b=state(),state("B")
local c,reason,debit=R.request(a,0,1,"A0HY",1800,origin,destination,grant("A0HY"),true);assert(c,reason)
check(debit==1800 and a.cooldowns.A0HY==60,"known1800/CD60 transaction")
check(c.scale==120 and c.radius==636 and c.pulseCounter==0,"HY isolated initial counter and visual scale")
check(next(b.casts)==nil and next(b.cooldowns)==nil,"owner isolation")
check(select(2,R.request(a,0,1,"A0HY",1800,origin,destination,grant("A0HY"),true))=="Replay","duplicate debit denied")
check(select(2,R.request(a,0,2,"A0HY",1800,origin,destination,grant("A0HY"),true))=="Cooldown","same ability cooldown")
local pre=R.update(a,1.3,str16)
check(#selectEvents(pre,"Released")==1 and #selectEvents(pre,"Travel")==0,"release precedes first periodic tick")
local travel=R.update(a,1.33,str16)
check(#selectEvents(travel,"Travel")==1 and #selectEvents(travel,"DamagePulse")==0,"no flight collision damage")
check(c.center.x==30 and c.phase=="Travelling","fixed heading30per03")
local arrival=R.update(a,1.36,str16)
check(c.phase=="Exploding" and c.center.x==60 and #selectEvents(arrival,"Arrived")==1,"<=30 arrival still advances visuals")
check(#selectEvents(arrival,"DamagePulse")==0 and c.pulseCounter==1,"HY arrival runs state2 but normally no pulse")
check(selectEvents(arrival,"ClearDestructibles")[1].radius==500,"source arrival clearing radius")
local first=R.update(a,1.39,str16)
local firstPulse=selectEvents(first,"DamagePulse");check(#firstPulse==1,"seven visuals one damage query")
check(firstPulse[1].radius==640 and firstPulse[1].damage==19 and firstPulse[1].displacement==2,"HY first pulse radius/integer damage/pull")
check(firstPulse[1].visualCount==7,"HY visual count is metadata")
firstPulse[1].center.x=999;check(c.center.x==60,"event center cannot mutate cast")
local rest=R.update(a,10,function(at: number): number return if at<2 then 16 else 100 end)
local pulses=selectEvents(rest,"DamagePulse")
check(#pulses==57 and c.pulses==58 and c.phase=="Completed","exact58 independent pulses")
check(pulses[#pulses].radius==868 and c.scale==178,"HY final source radius/scale")
check(pulses[1].damage==19 and pulses[#pulses].damage==25,"HY reads current strength per pulse")
check(near(pulses[2].at-pulses[1].at,.06),"HY alternating03ticks")
check(#selectEvents(rest,"Motion")==0,"HY only pulse pull")
check(#selectEvents(rest,"CasterUnpaused")==1 and #selectEvents(rest,"HelpersRemoved")==0,"HY unpause independent no HZ helpers")
check(#selectEvents(rest,"Completed")==1 and not R.current(a,c),"single completion cleans cast")
local again=R.update(a,11,str16);check(#again==0,"completed callback cannot repeat")
-- Dynamic query consumers reevaluate inclusion; overlapping visuals never multiply hits.
local all: {R.Event}={firstPulse[1]};for _,e in pulses do table.insert(all,e) end
local hits=0;local total=0
for i,e in all do if i>10 and i<=40 then hits+=1;total+=e.damage or 0 end end
check(hits==30 and total>0,"late entry and leaving select actual pulse subset")
local z=state();local hz=R.request(z,0,1,"A0HZ",1800,origin,destination,grant("A0HZ"),true);assert(hz)
check(hz.scale==200 and hz.pulseCounter==16 and hz.motionStep==5,"HZ source initialization")
local events=R.update(z,10,str16)
local zp=selectEvents(events,"DamagePulse");local motion=selectEvents(events,"Motion")
check(#zp==7 and #motion==70,"HZ seven damage pulses and70separate movement ticks")
local ticks={1,18,35,52,69,86,103};local radii={640,708,776,844,912,980,1048}
for i,p in zp do
 check(p.explosionTick==ticks[i] and p.radius==radii[i],"HZ exact pulse tick/radius "..i)
 check(near(p.damage or 0,964/7) and p.displacement==8,"HZ real quotient/current strength "..i)
end
check(zp[1].damage~=math.floor(zp[1].damage or 0),"HZ does not use integer prepared SurikDamage")
local steps={4,3,2,1,-13,-12,-11,-10,-9,-8}
for i,step in steps do check(motion[i].displacement==step,"signed450motion "..i) end
check(motion[11].explosionTick==18 and motion[11].displacement==-7,"motion sequence persists across gated gaps")
check(motion[17].displacement==-1 and motion[18].displacement==13 and motion[19].displacement==12,"oscillator skips zero and switches back inward")
check(hz.explosionTick==116 and hz.radius==1100 and hz.scale==432,"HZ final tick grows without final damage pulse")
check(hz.center.x==90 and zp[1].center.x==90,"HZ AoE is target point, not visual arrival point")
check(#selectEvents(events,"Cripple")==0 and #selectEvents(events,"SelfDamage")==0,"no invented cripple or stale selfdamage")
check(#selectEvents(events,"HelpersRemoved")==1 and selectEvents(events,"HelpersRemoved")[1].at==2.5,"HZ helpers clean at2.5")
for _,e in events do if e.kind=="Motion" then check(e.filter=="NonAllyNonStructure" and e.damage==nil,"extra motion no damage") end end
check(R.eligible("EnemyNonStructure",false,false,false)==false,"HZ damage excludes nonenemy neutral")
check(R.eligible("NonAllyNonStructure",false,false,false),"HZ extra motion includes nonallied neutral")
check(not R.eligible("NonAllyNonStructure",false,true,true),"structure excluded")
local admitted,why=R.eligible("NonAllyNonStructureNullGroups",false,true,false)
check(not admitted and why=="NullGroupPolicyUnresolved","HY null-group native boundary explicit")
check(R.eligible("NonAllyNonStructureNullGroups",false,true,false,false),"explicit null-membership policy admits")
check(not R.eligible("NonAllyNonStructureNullGroups",false,true,false,true),"explicit excluded membership denies")
local s=state();local g=grant("A0HY")
g.hagoromo=false;check(select(2,R.request(s,0,1,"A0HY",1800,origin,destination,g,true))=="Grant","Hagoromo required")
g.hagoromo=true;g.ownerId="B";check(R.request(s,0,2,"A0HY",1800,origin,destination,g,true)==nil,"foreign grant rejected")
g.ownerId="A";g.expiresAt=0;check(R.request(s,0,3,"A0HY",1800,origin,destination,g,true)==nil,"expired grant rejected")
g.expiresAt=20;g.form="Hpal";check(R.request(s,0,4,"A0HY",1800,origin,destination,g,true)==nil,"no base-form grant")
g.form="Ewrd";g.kcmRank=2;check(R.request(s,0,5,"A0HY",1800,origin,destination,g,true)==nil,"no rank2 grant")
g.kcmRank=3;g.heroLevel=26;check(R.request(s,0,6,"A0HY",1800,origin,destination,g,true)==nil,"rank3 minimum27")
g.heroLevel=27;check(select(2,R.request(s,0,7,"A0HY",1799,origin,destination,g,true))=="Mana","no free cast")
check(select(2,R.request(s,0,8,"A0HY",1800,origin,{x=2001,z=0},g,true))=="Range","range2000")
check(R.request(s,0,9,"A0IA",1800,origin,destination,g,true)==nil,"unresolved IA not admitted")
for i,bad in {0/0,math.huge,-math.huge} do
 check(R.request(s,bad,10+i,"A0HY",1800,origin,destination,g,true)==nil,"malformed clock")
 check(R.request(s,0,20+i,"A0HY",1800,origin,{x=bad,z=0},g,true)==nil,"malformed point")
end
check(next(s.casts)==nil and next(s.cooldowns)==nil,"denials never debit/cooldown")
local pair=state();local p1=R.request(pair,0,1,"A0HY",3600,origin,destination,grant("A0HY"),true);assert(p1)
local p2=R.request(pair,0,2,"A0HZ",1800,origin,destination,grant("A0HZ"),true);assert(p2)
local combined=R.update(pair,10,str16)
check(p1.radius==868 and p2.radius==1100 and p1.pulses==58 and p2.pulses==7,"same owner casts do not share439/440/counters")
for i=2,#combined do check(combined[i].at>=combined[i-1].at,"cross-cast commands chronological") end
local life=state();local old=R.request(life,0,1,"A0HY",1800,origin,destination,grant("A0HY"),true);assert(old)
local cancelled=R.newLife(life,1,2)
check(#cancelled==1 and not R.current(life,old) and life.cooldowns.A0HY==60,"death invalidates casts retains cooldown")
check(not R.cancel(life,old),"late cancellation inert")
R.reset(life,2,3);check(next(life.cooldowns)==nil and life.serial==1 and life.lastRequest==1,"round reset clears cooldown keeps identities")
R.close(life);check(R.request(life,1,2,"A0HY",1800,origin,destination,g,true)==nil,"closed state cannot reopen")
local badStats=state();local badCast=R.request(badStats,0,1,"A0HZ",1800,origin,destination,grant("A0HZ"),true);assert(badCast)
local badEvents=R.update(badStats,10,function(): number return 0/0 end)
check(#selectEvents(badEvents,"DamagePulse")==0 and #selectEvents(badEvents,"Cancelled")==1,"invalid authoritative strength cancels safely")
local overflow=state();assert((R.request(overflow,0,1,"A0HZ",1800,origin,destination,grant("A0HZ"),true)))
local overflowEvents=R.update(overflow,10,function(): number return 1e308 end)
check(#selectEvents(overflowEvents,"DamagePulse")==0 and #selectEvents(overflowEvents,"Cancelled")==1,"overflow cannot emit infinite damage")
local ta,tb=state(),state("B")
local ca=R.request(ta,0,1,"A0HY",1800,origin,destination,grant("A0HY"),true);assert(ca)
local cb=R.request(tb,0,1,"A0HZ",1800,origin,{x=0,z=-90},grant("A0HZ","B"),true);assert(cb)
local ea=R.update(ta,10,str16);local eb=R.update(tb,10,function(): number return 100 end)
check(selectEvents(ea,"DamagePulse")[1].damage==19 and near(selectEvents(eb,"DamagePulse")[1].damage or 0,1300/7),"concurrent owners use own current STR")
check(ca.center.x==60 and cb.center.z==-90 and ca.pulses==58 and cb.pulses==7,"concurrent owners keep own geometry/counters")
local interrupt=state();local interrupted=R.request(interrupt,0,1,"A0HY",1800,origin,destination,grant("A0HY"),true);assert(interrupted)
R.update(interrupt,1.36,str16);check(interrupted.pulseCounter==1 and R.cancel(interrupt,interrupted),"cancel HY between alternating ticks")
local laterGrant=grant("A0HY");laterGrant.expiresAt=100
local restarted=R.request(interrupt,60,2,"A0HY",1800,origin,destination,laterGrant,true);assert(restarted)
check(restarted.pulseCounter==0,"new HY starts0 instead of stale shared285")
local restartedEvents=R.update(interrupt,70,str16)
check(#selectEvents(restartedEvents,"DamagePulse")==58,"interrupted prior HY cannot change pulse count")
local epoch=state();local epochGrant=grant("A0HZ");epochGrant.life=0
check(R.request(epoch,0,1,"A0HZ",1800,origin,destination,epochGrant,true)==nil,"stale-life grant rejected")
epochGrant.life=1;epochGrant.round=0
check(R.request(epoch,0,2,"A0HZ",1800,origin,destination,epochGrant,true)==nil,"stale-round grant rejected")
local boundary=state();local edge=R.request(boundary,0,1,"A0HZ",1800,origin,{x=2000,z=0},grant("A0HZ"),true);assert(edge)
R.update(boundary,10,str16);check(edge.pulses==7 and edge.travelled==1980,"range edge uses point arrival threshold rather than swept collision")
check(select(2,R.update(boundary,9,str16))=="Clock","update rollback denied")
check(select(2,R.request(boundary,9,2,"A0HY",1800,origin,destination,grant("A0HY"),true))=="Malformed","request rollback denied")
local geometry=state();local mutableOrigin={x=0,z=0};local mutableTarget={x=90,z=0}
local locked=R.request(geometry,0,1,"A0HY",1800,mutableOrigin,mutableTarget,grant("A0HY"),true);assert(locked)
mutableOrigin.x=1000;mutableTarget.x=2000
R.update(geometry,10,str16);check(locked.center.x==60,"point mutation cannot steer an admitted projectile")
local identity={id="match-A:main",eligible=true}
local attempt=Knife.begin(0,identity);assert(attempt);identity.id="match-B:main"
check(not Knife.resolve(attempt,.009,{id="match-A:main",eligible=true}),"knife waits.01")
check(Knife.resolve(attempt,.01,{id="match-A:main",eligible=true}),"caster identity snapshotted before delay")
check(select(2,Knife.resolve(attempt,.02,{id="match-A:main",eligible=true}))=="Replay","knife resolves once")
attempt=Knife.begin(0,{id="match-A:main",eligible=true});assert(attempt)
check(select(2,Knife.resolve(attempt,.01,{id="match-A:duel-2",eligible=true}))=="CrossInstance","target crosses instance during delay")
attempt=Knife.begin(0,nil);assert(attempt)
check(not Knife.resolve(attempt,.01,nil),"both outside all eligible instances fail")
attempt=Knife.begin(0,{id="same",eligible=false});assert(attempt)
check(not Knife.resolve(attempt,.01,{id="same",eligible=false}),"matching invalid labels cannot admit")
local leaving=state(); local paid=R.request(leaving,0,1,"A0HY",1800,origin,destination,grant("A0HY"),true); assert(paid)
local stored=R.balance(leaving)
local rejoined=R.new("A",1,2,5,stored)
check(rejoined.cooldowns.A0HY==60 and rejoined.serial==paid.id,"reconnect retains deadline and cast serial")
check(next(rejoined.casts)==nil,"reconnect cannot revive old casts")
local freshGrant=grant("A0HY");freshGrant.life=2;freshGrant.expiresAt=100
check(select(2,R.request(rejoined,5,1,"A0HY",1800,origin,destination,freshGrant,true))=="Cooldown","reconnect cannot bypass paid cooldown")
local nextCast=R.request(rejoined,60,2,"A0HY",1800,origin,destination,freshGrant,true);assert(nextCast)
check(nextCast.id>paid.id,"reconnect VFX identity cannot recycle paid cast id")
check(leaving.cooldowns.A0HY==60 and stored.cooldowns.A0HY==60 and rejoined.cooldowns.A0HY==120,"restored cooldown maps are independent")
check(next(R.new("A",2,1,61).cooldowns)==nil,"new round starts fresh cooldown map")
print("PASS NarutoRanged: "..checks.." assertions")
