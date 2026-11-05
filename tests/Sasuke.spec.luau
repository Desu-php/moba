--!strict
local D=require("../src/shared/Abilities/SasukeDefinitions")
local R=require("../src/shared/Abilities/SasukeRules")
local F=require("../src/shared/Abilities/SasukeFamilies")
local L=require("../src/shared/Abilities/SkillLearning")
local H=require("../src/shared/Config/HeroConfig")
local p={Level=30,SkillPoints=30,Learned={} :: {[string]:number}}
assert(not L.learn(p,"Rasengan","Sasuke"));assert(not L.learn(p,"SasukeLightning","OrangeNinja"))
for _,id in L.order("Sasuke") do while L.reason(p,id,"Sasuke")==nil do assert(L.learn(p,id,"Sasuke")) end end
assert(p.Learned.SasukeLightning==4 and p.Learned.SasukeEyes==5 and p.Learned.SasukeSummon==10 and p.SkillPoints==6)
local s:R.State={rank=5,mode=3,held=false,readyAt=1,now=2,form=0,kirinAt=0,kirinUntil=0,spheres=0,beasts=0,garuda=false}
assert(R.reason("ChidoriSenbon",s)~=nil);s.held=true;s.now=0;assert(R.reason("ChidoriSenbon",s)~=nil)
s.now=2;assert(R.reason("ChidoriSenbon",s)==nil)
assert(R.reason("Chidori",s)~=nil);assert(R.reason("Kirin",s)~=nil)
s.kirinAt=3;s.kirinUntil=18;assert(R.reason("KirinBoost",s)==nil);assert(R.reason("Kirin",s)~=nil)
s.now=4;assert(R.reason("Kirin",s)==nil);assert(R.reason("KirinBoost",s)~=nil)
s.now=19;assert(R.reason("Kirin",s)~=nil)
assert(R.reason("PerfectSusanoo",s)~=nil);s.form=3;s.beasts=1;assert(R.reason("PerfectSusanoo",s)==nil)
s.garuda=true;assert(R.reason("ChidoriNagashi",s)~=nil);assert(R.reason("Garuda",s)==nil);assert(R.reason("SasukeModeOff",s)==nil)
s.garuda=false;s.mode=1;assert(R.reason("Amaterasu",s)~=nil);assert(R.reason("SasukeGenjutsu",s)==nil)
assert(D.chidoriDamage(30,56,"Chidori")==476);assert(D.chidoriDamage(30,56,"OnyxChidori")==532)
assert(D.Spells.ChidoriSenbon.cd==40 and D.Spells.SusanooChidori.cd==100)
assert(D.cooldown("Aoda",5)==60 and D.cooldown("Aoda",6)==150)
assert(D.cost("Aoda",4)==50 and D.cost("Aoda",5)==150 and D.cost("Aoda",9)==300)
assert(D.cooldownKey("PhoenixFlowers")=="SasukeFireball")
for key,family in F.Definitions do
 local keys={};for _,e in family.entries do
  assert(not keys[e.key],"duplicate family binding");keys[e.key]=true
  local kind,entry=F.resolve(key,e.key);assert(kind=="Action" and entry.id==e.id)
  assert(D.Spells[e.id] and table.find(H.Heroes.Sasuke.Abilities,e.id));assert(not table.find(H.Heroes.OrangeNinja.Abilities,e.id))
 end
end
print("PASS Sasuke hero isolation, rank spending, charge/mode/flight/sky gates, shared cooldowns and family reachability")
