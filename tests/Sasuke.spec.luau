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
local Poses=require("../src/shared/Combat/SasukeAttackPoses")
local Combat=require("../src/shared/Config/CombatConfig")
local contact=Combat.Profiles.Sasuke.HitDelay/Combat.Profiles.Sasuke.AttackDuration
local thrust=Poses.sample("Chidori",contact,1,contact)
local impact=Poses.sample("Impact",0,1,contact)
assert(thrust.LeftShoulder[1]>1.5 and thrust.LeftElbow[1]<.1)
assert(impact.LeftShoulder[1]==thrust.LeftShoulder[1],"contact must not snap back to ordinary M1")
assert(Poses.sample("Impact",1,1,contact).LeftShoulder[1]<.5,"recover to guard")
assert(Poses.sample("Attack",contact,1,contact).RightWrist[1]<-1,"blade points through contact, not at the sky")
assert(Poses.sample("Attack",contact,1,contact).Waist[2]>0 and Poses.sample("Attack",contact,2,contact).Waist[2]<0,"alternate sword cuts")
for _,kind in {"Attack","Chidori","Impact"} do for step=1,3 do for frame=0,100 do
 local pose=Poses.sample(kind,frame/100,step,contact)
 for _,v in pose do for _,angle in v do assert(angle==angle and math.abs(angle)<math.pi,"finite anatomical joint angles") end end
 assert(math.abs(pose.LeftHip[1])<.3 and math.abs(pose.RightHip[1])<.3,"feet stay planted during attacks")
end end end
print("PASS Sasuke hero isolation, rank spending, charge/mode gates, cooldowns, families and R15 attack contact/recovery")
