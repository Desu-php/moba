--!strict
-- Stable family/choice positions. Opening a family is local navigation, never a cast.
export type Entry={key:string,id:string,name:string,command:string?}
export type Family={key:string,name:string,icon:string,hint:string,entries:{Entry}}
local Families={}
Families.Order={"Q","E","R","F","C","T"}
local definitions: {[string]:Family}={
 Q={key="Q",name="Расенган",icon="Rasengan",hint="Q формирует Расенган. Z / X — усилить. Готовый заряд заменяет первое попадание ЛКМ.",entries={
  {key="Z",id="Odama",name="Одама"},{key="X",id="Rasenshuriken",name="Расенсюрикен"}}},
 E={key="E",name="Клоны",icon="ShadowClones",hint="E → E — призвать. Команды атаки, следования и ожидания относятся ко всем боевым призывам.",entries={
  {key="E",id="ShadowClones",name="Призвать"},
  {key="X",id="CloneCommand",name="Атаковать"},{key="V",id="CloneCommand",name="За мной",command="Follow"},
  {key="B",id="CloneCommand",name="Стоять",command="Hold"}}},
 R={key="R",name="Гамакичи",icon="Gamakichi",hint="R → R — призвать. Z — масло, X — удары мечом взрослого Гамакичи. Затем прицел и ЛКМ.",entries={
  {key="R",id="Gamakichi",name="Призвать"},{key="Z",id="GamakichiOil",name="Масло"},{key="X",id="GamakichiChop",name="Удары мечом"}}},
 F={key="F",name="Техники формы",icon="KcmDash",hint="F → F — рывок KCM. Z / X — техники Рикудо. Выбор цели подтверждается ЛКМ.",entries={
  {key="F",id="KcmDash",name="Рывок"},{key="Z",id="RikudoHY",name="Биджудама RS"},{key="X",id="RikudoHZ",name="Биджу RS"}}},
 C={key="C",name="Режимы",icon="KuramaForm",hint="C → C — мудрец; Z — изученный KCM / Рикудо; X — полная Курама; V — выйти из KCM. Режимы сохраняют отдельные таймеры.",entries={
  {key="C",id="SageMode",name="Мудрец"},{key="Z",id="KCM",name="KCM"},{key="X",id="KuramaForm",name="Курама"},{key="V",id="KcmCancel",name="Выход KCM"}}},
 T={key="T",name="Чакра",icon="MeditationToggle",hint="T → T — подготовка с медитирующими клонами. Z — вернуть их энергию. X — обменять чакру Курамы на ману.",entries={
  {key="T",id="MeditationCast",name="Медитация"},{key="Z",id="MeditationRecall",name="Вернуть чакру"},{key="X",id="KuramaConvert",name="Обмен чакры"}}},
}
Families.Definitions=definitions
function Families.resolve(open:string?,key:string): (string,Entry?)
 local family=if open then Families.Definitions[open] else nil
 if family then for _,entry in family.entries do if entry.key==key then return "Action",entry end end end
 if Families.Definitions[key] then return "Open",nil end
 return "None",nil
end
function Families.learning(key:string):string?
 local index=table.find({"One","Two","Three","Four","Five"},key)
 return if index then ({"Rasengan","ShadowClones","Gamakichi","SageMode","KCM"})[index] else nil
end
return table.freeze(Families)
