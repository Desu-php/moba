--!strict
-- Stable, paged groups. Locked techniques keep their slots; forms never reshuffle hotkeys.
local Deck={PageSize=6,DefaultGroup="Techniques"}
Deck.Groups={
 {id="Techniques",name="Атаки",abilities={"Odama","Rasenshuriken","ShadowSleep","KcmDash","RikudoHY","RikudoHZ","Rasengan","RasenshurikenThrow"}},
 {id="Modes",name="Режимы",abilities={"SageMode","KCM","KuramaForm","KcmCancel"}},
 {id="Support",name="Поддержка",abilities={"CloneCommand","GamakichiOil","GamakichiChop","MeditationToggle","MeditationRecall","KuramaConvert","ShadowClones","Gamakichi"}},
}
function Deck.group(id:string)
 for _,group in Deck.Groups do if group.id==id then return group end end
 return Deck.Groups[1]
end
function Deck.pages(id:string):number return math.max(1,math.ceil(#Deck.group(id).abilities/Deck.PageSize)) end
function Deck.page(id:string,page:number):{string}
 local list=Deck.group(id).abilities;local result={}
 local start=(math.clamp(math.floor(page),1,Deck.pages(id))-1)*Deck.PageSize
 for i=start+1,math.min(start+Deck.PageSize,#list) do table.insert(result,list[i]) end
 return result
end
function Deck.slot(key:string,modifier:boolean,control:boolean,text:boolean,menu:boolean):number?
 if not modifier or control or text or menu then return nil end
 return table.find({"One","Two","Three","Four","Five","Six"},key)
end
return table.freeze(Deck)
