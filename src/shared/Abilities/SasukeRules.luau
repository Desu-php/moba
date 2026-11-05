--!strict
local D=require("./SasukeDefinitions")
local R={}
export type State={rank:number,mode:number,held:boolean,readyAt:number,now:number,form:number,kirinAt:number,kirinUntil:number,spheres:number,beasts:number,garuda:boolean}
function R.reason(id:string,s:State):string?
 local d=D.Spells[id];if not d then return "UnknownAbility" end
 if s.rank<d.rank then return "Необходим ранг "..d.rank..": "..D.Learning[d.line].name end
 if id=="SasukeModeOff" then return nil end
 if s.garuda and id~="Garuda" then return "Сначала завершите полёт: R → Z" end
 if s.mode<d.mode then return if d.mode==3 then "Нужен активный Риннеган" elseif d.mode==2 then "Нужен активный Мангекё" else "Включите Шаринган" end
 if id=="Chidori" or id=="SusanooChidori" then if s.held then return "Чидори уже в руке — ЛКМ" end end
 if id=="ChidoriSenbon" or id=="ChidoriEiso" or id=="OnyxChidori" or id=="AmaterasuChidori" then
  if not s.held then return "Сначала Q — Чидори" end
  if s.now<s.readyAt then return "Чидори формируется" end
 end
 if id=="KirinBoost" and (s.kirinUntil<=s.now or s.now>=s.kirinAt) then return "Сначала подготовьте грозу" end
 if id=="Kirin" and (s.kirinUntil<=s.now or s.now<s.kirinAt) then return "Подготовьте Кирин и дождитесь грозы" end
 if id=="KirinPrepare" and s.kirinUntil>s.now then return "Гроза уже подготовлена" end
 if (id=="ChibakuMove" or id=="ChibakuDrop") and s.spheres==0 then return "Сначала создайте сферы" end
 if id=="PerfectSusanoo" and (s.form<3 or s.beasts<1) then return "Завершённое Сусаноо и чакра хвостатого" end
 if id=="EntonMagatama" and s.form<2 then return "Нужно активное Сусаноо" end
 if id=="SusanooChidori" and s.form<3 then return "Нужно завершённое Сусаноо" end
 if (id=="SusanooTriple" or id=="IndraArrow") and s.form<4 then return "Нужно Биджу Сусаноо" end
 return nil
end
function R.rankReason(level:number,points:number,rank:number,line:string):string?
 local d=D.Learning[line];if not d then return "UnknownAbility" end
 if rank>=#d.levels then return "MaxRank" end
 if level<d.levels[rank+1] then return "Level" end
 if points<1 then return "NoPoints" end
 return nil
end
return R
