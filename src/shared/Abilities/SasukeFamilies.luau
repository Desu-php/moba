--!strict
local D=require("./SasukeDefinitions")
local F={Order={"Q","E","R","F","C","T"},Definitions={} :: {[string]:any}}
local short:{[string]:string}={ChidoriSenbon="Сенбон",ChidoriNagashi="Нагаши",ChidoriKatana="Катана",ChidoriEiso="Эйсо",OnyxChidori="Оникс",AmaterasuChidori="Чёрное Чидори",SusanooChidori="Чидори Сусаноо",SasukeFireball="Гокакью",PhoenixFlowers="Хосенка",KirinPrepare="Подготовить",KirinBoost="Усилить",Aoda="Аода",AodaBind="Обвить цель",AodaGuardSelf="Защитить меня",Garuda="Гаруда",Mangekyo="Мангекё",SusanooRibs="Рёбра",CompleteSusanoo="Завершённое",PerfectSusanoo="Биджу форма",SasukeModeOff="Выход",SasukeGenjutsu="Гендзюцу",AmaterasuWall="Стена огня",EntonMagatama="Магатама",EntonPull="Притяжение",Extinguish="Потушить",Amenotejikara="Обмен мест",ChakraAbsorb="Чакра биджу",ChibakuTensei="Чибаку",ChibakuMove="Сдвинуть",ChibakuDrop="Обрушить",SusanooTriple="Три стрелы",IndraArrow="Стрела Индры"}
local function family(key:string,name:string,icon:string,hint:string,entries:{{string}})
 local list={};for _,e in entries do table.insert(list,{key=e[1],id=e[2],name=short[e[2]] or D.Spells[e[2]].name}) end
 F.Definitions[key]={key=key,name=name,icon=icon,hint=hint,entries=list}
end
family("Q","Молния","Chidori","Q формирует Чидори. ЛКМ расходует заряд при попадании. Z — иглы к точке прицела; B — Эйсо по выбранному врагу; X — отталкивающий Нагаши; V — Катана.",{{"Z","ChidoriSenbon"},{"X","ChidoriNagashi"},{"V","ChidoriKatana"},{"B","ChidoriEiso"},{"G","OnyxChidori"},{"H","AmaterasuChidori"},{"J","SusanooChidori"}})
family("E","Огонь","SasukeFireball","E → E — огненный выдох; Z — очередь Хосенки. Движение прерывает огонь. X — подготовить грозу, B — усилить, V — Кирин по выбранному врагу. ЛКМ подтверждает цель.",{{"E","SasukeFireball"},{"Z","PhoenixFlowers"},{"X","KirinPrepare"},{"V","Kirin"},{"B","KirinBoost"}})
family("R","Призывы","Aoda","R — призыв Аоды. X — удушение врага или защита союзника взрослой Аодой; C — защита себя. Z — Гаруда.",{{"R","Aoda"},{"X","AodaBind"},{"C","AodaGuardSelf"},{"Z","Garuda"}})
family("F","Додзюцу","Amaterasu","Чёрное пламя и гендзюцу. Для Аматерасу требуется Мангекё. Первые 4 с F → F направляет пламя. B при рёбрах — огненная защита; H в Сусаноо — магатамы. Z — оружие/стрела; при Риннегане Z в течение 1 с после F усиливает пламя в том же месте.",{{"F","Amaterasu"},{"Z","Enton"},{"X","SasukeGenjutsu"},{"V","Extinguish"},{"B","AmaterasuWall"},{"G","EntonPull"},{"H","EntonMagatama"}})
family("C","Режимы","Sharingan","C → C — Шаринган; Z — развить глаза. III ранг: Мангекё; IV: Вечный Мангекё; V: Риннеган. Рёбра и Сусаноо заменяют друг друга; H отключает режимы.",{{"C","Sharingan"},{"Z","Mangekyo"},{"X","SusanooRibs"},{"V","Susanoo"},{"B","CompleteSusanoo"},{"G","PerfectSusanoo"},{"H","SasukeModeOff"}})
family("T","Риннеган","Amenotejikara","Телепортация, гравитация и оружие Биджу Сусаноо. Для усиленной формы требуется поглощённая чакра хвостатого.",{{"T","Amenotejikara"},{"Z","ChakraAbsorb"},{"X","ChibakuTensei"},{"V","ChibakuMove"},{"B","ChibakuDrop"},{"G","SusanooTriple"},{"H","IndraArrow"}})
function F.resolve(open:string?,key:string):(string,any)
 local f=if open then F.Definitions[open] else nil
 if f then for _,e in f.entries do if e.key==key then return "Action",e end end end
 return if F.Definitions[key] then "Open" else "None",nil
end
function F.learning(key:string):string?
 local index=table.find({"One","Two","Three","Four"},key)
 return if index then D.LearningOrder[index] else nil
end
return F
