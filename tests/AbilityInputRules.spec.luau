--!strict
local Rules=require("../src/shared/Abilities/AbilityInputRules")
local Config=require("../src/shared/Config/AbilityConfig")
for _,active in {false,true} do
 assert(Rules.resolve(Config.InputAliases :: {read [string]:string},"X",active)=="Rasenshuriken","KCM cannot steal X from Rasengan")
 assert(Rules.resolve(Config.InputAliases :: {read [string]:string},"Z",active)=="Odama")
 for _,key in {"E","F","C","T","Left","Right","Tab","Six"} do assert(Rules.resolve(Config.InputAliases :: {read [string]:string},key,active)==nil,"no legacy standalone cast") end
end
print("PASS direct Rasengan aliases and retired bindings")
