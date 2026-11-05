--!strict
local Families=require("../src/shared/Abilities/AbilityFamilies")
local Config=require("../src/shared/Config/AbilityConfig")
local Heroes=require("../src/shared/Config/HeroConfig")
local Descriptions=require("../src/client/Controllers/AbilityDescriptions") :: {[string]:string}
assert(table.concat(Families.Order,",")=="Q,E,R,F,C,T")
local count=0
for _,key in Families.Order do
 local kind,entry=Families.resolve(nil,key);assert(kind=="Open" and entry==nil,"prefix never casts a branch")
 local seen={}
 for _,option in Families.Definitions[key].entries do
  assert(not seen[option.key],"ambiguous choice");seen[option.key]=true
  local action,resolved=Families.resolve(key,option.key);assert(action=="Action" and resolved==option)
  assert(Config.Abilities[option.id] and Descriptions[option.id],"complete tooltip")
  assert(table.find(Heroes.Heroes.OrangeNinja.Abilities,option.id),"server allowlist")
  count+=1
 end
end
local function route(family:string,key:string,id:string)
 local _,entry=Families.resolve(family,key);assert(entry and entry.id==id)
end
route("Q","X","Rasenshuriken");route("Q","Z","Odama")
route("C","X","KuramaForm");route("F","X","RikudoHZ");route("E","X","CloneCommand")
route("E","E","ShadowClones");route("C","C","SageMode");route("T","T","MeditationCast")
assert(Families.resolve(nil,"X")=="None","X alone cannot exit KCM")
assert(Families.resolve("Q","E")=="Open","another prefix replaces the family")
for _,key in {"W","A","S","D","Tab","LeftShift","One","Six"} do assert(Families.resolve("E",key)=="None") end
assert(Families.learning("Four")=="SageMode" and Families.learning("Five")=="KCM")
print("PASS family navigation: "..count.." described, whitelisted choices")

assert(not table.find(Heroes.Heroes.OrangeNinja.Abilities,"ShadowSleep"),"sleep removed from Naruto allowlist")
assert(Config.PrototypeEnabled.ShadowSleep==false)
assert(Families.resolve("E","Z")=="None")
