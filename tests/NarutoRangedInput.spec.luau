--!strict
local Config=require("../src/shared/Config/AbilityConfig")
local Learning=require("../src/shared/Abilities/SkillLearning")
local Heroes=require("../src/shared/Config/HeroConfig")
local Families=require("../src/shared/Abilities/AbilityFamilies")
local count=0
local function check(ok:boolean,label:string) assert(ok,label);count+=1 end
for key,id in ({Z="RikudoHY",X="RikudoHZ"} :: {[string]:string}) do
 local kind,entry=Families.resolve("F",key)
 check(kind=="Action" and entry~=nil and entry.id==id,"Rikudo techniques use F family")
 check(Families.resolve(nil,key)=="None","no standalone Rikudo cast")
end
for _,id in {"RikudoHY","RikudoHZ"} do
 check(table.find(Config.Order,id)==nil,"additional deck rather than learned hero slot")
 check(table.find(Heroes.Heroes.OrangeNinja.Abilities,id)~=nil,"network allowlist includes confirmed variants")
 check(Config.Abilities[id].Cooldown==60,"source cooldown")
 local profile:Learning.Profile={Level=30,SkillPoints=1,Learned={}}
 check(Learning.reason(profile,id)=="UnknownAbility","no purchasable extra line")
end
print("PASS Naruto ranged input: "..count.." assertions")
