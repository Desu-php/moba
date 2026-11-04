--!strict
local Deck=require("../src/shared/Abilities/AbilityDeck")
local Config=require("../src/shared/Config/AbilityConfig")
local Descriptions=require("../src/client/Controllers/AbilityDescriptions")
local count=0
local function check(ok:boolean,message:string) assert(ok,message);count+=1 end
local found:{[string]:boolean}={}
for _,group in Deck.Groups do
 local rebuilt={}
 for page=1,Deck.pages(group.id) do
  local ids=Deck.page(group.id,page)
  check(#ids>0 and #ids<=6,"page bounded")
  for _,id in ids do
   check(Config.Abilities[id]~=nil and (Config.PrototypeEnabled :: {[string]:boolean})[id]==true,"only implemented ability")
   check(not found[id],"stable single catalog entry for "..id);found[id]=true
   check(typeof((Descriptions :: {[string]:string})[id])=="string","description for "..id)
   table.insert(rebuilt,id)
  end
 end
 for i,id in group.abilities do check(rebuilt[i]==id,"paging preserves order") end
 check(Deck.page(group.id,0)[1]==group.abilities[1],"clamp low page")
 check(Deck.page(group.id,100)[1]==Deck.page(group.id,Deck.pages(group.id))[1],"clamp high page")
end
for id,enabled in Config.PrototypeEnabled do if enabled then check(found[id]==true,"discoverable: "..id) end end
check(Config.Order[6]=="KuramaForm","full Kurama permanently visible")
check(#Config.Order==6,"fixed primary row")
for _,key in {"F","G","H"} do check(Config.InputAliases[key]~=nil,"preserved legacy summon shortcut") end
for i,key in {"One","Two","Three","Four","Five","Six"} do
 check(Deck.slot(key,true,false,false,false)==i,"modifier routes to exactly one slot")
 check(Deck.slot(key,false,false,false,false)==nil,"normal primary keys untouched")
 check(Deck.slot(key,true,true,false,false)==nil,"control learning not stolen")
 check(Deck.slot(key,true,false,true,false)==nil,"text input untouched")
 check(Deck.slot(key,true,false,false,true)==nil,"menu input untouched")
end
check(Deck.slot("Seven",true,false,false,false)==nil,"missing slot not cast")
check(Deck.slot("Q",true,false,false,false)==nil,"legacy alias not stolen")
print("Ability deck PASS: "..count.." checks")
