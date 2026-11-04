--!strict
local Config=require("../src/shared/Config/AbilityConfig")
local Input=require("../src/shared/Abilities/AbilityInputRules")
local Learning=require("../src/shared/Abilities/SkillLearning")
local Heroes=require("../src/shared/Config/HeroConfig")
local aliases=Config.InputAliases :: {read [string]:string}
local existing:{[string]:string}={Q="Rasengan",E="KcmDash",Left="KuramaConvert",Right="MeditationToggle",J="MeditationRecall",T="ShadowSleep",Z="Odama"}
local count=0
local function check(ok:boolean,label:string) assert(ok,label);count+=1 end
for i,id in {"Rasengan","ShadowClones","Gamakichi","SageMode","KCM"} do check(Config.Order[i]==id,"five main lines preserved") end
for _,active in {false,true} do
 check(Input.resolve(aliases,"V",active)=="RikudoHY","V HY")
 check(Input.resolve(aliases,"B",active)=="RikudoHZ","B HZ")
 for key,id in existing do
  check(Input.resolve(aliases,key,active)==id,"existing key "..key)
 end
 check(Input.resolve(aliases,"X",active)==(if active then "KcmCancel" else "Rasenshuriken"),"context X preserved")
end
for _,id in {"RikudoHY","RikudoHZ"} do
 check(table.find(Config.Order,id)==nil,"additional deck rather than learned hero slot")
 check(table.find(Heroes.Heroes.OrangeNinja.Abilities,id)~=nil,"network allowlist includes confirmed variants")
 check(Config.Abilities[id].Cooldown==60,"source cooldown")
 for existingId,ability in Config.Abilities do
  if existingId~=id then check(ability.Key~=Config.Abilities[id].Key,"new key has no collision "..existingId) end
 end
 local profile:Learning.Profile={Level=30,SkillPoints=1,Learned={}}
 check(Learning.reason(profile,id)=="UnknownAbility","no purchasable extra line")
end
print("PASS Naruto ranged input: "..count.." assertions")
