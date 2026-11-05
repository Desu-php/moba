--!strict
-- Naruto Legend 1.7A FIX20.3 object records and JASS, audited in docs/SASUKE-SOURCE.md.
-- World distances below are Warcraft units; WorldUnits is the common Roblox conversion.
export type Spell={name:string,raw:string,line:string,rank:number,mana:number,cd:number,duration:number,range:number,radius:number,target:string,mode:number,description:string}
local D={}
D.Hero={UnitRawcode="Udea",Strength=15,StrengthGrowth=.9,Agility=16,AgilityGrowth=1.4,Intelligence=14,IntelligenceGrowth=1.2,BaseMana=300,BaseHealth=300,HealthPerStrength=20}
D.NativeInference={ManaPerIntelligence=15,RegenPerIntelligence=.05,BaseManaRegen=.01}
D.LearningOrder={"SasukeLightning","SasukeFire","SasukeSummon","SasukeEyes"}
D.Learning={
	SasukeLightning={name="Техники молнии",levels={4,7,10,13}},
	SasukeFire={name="Техники огня",levels={1,4,7,10,13}},
	SasukeSummon={name="Призыв Аоды",levels={2,4,6,8,10,12,14,16,18,20}},
	SasukeEyes={name="Шаринган",levels={1,7,13,19,25}},
} :: {[string]:{name:string,levels:{number}}}
D.Spells={} :: {[string]:Spell}
local function spell(id:string,name:string,raw:string,line:string,rank:number,mana:number,cd:number,duration:number,range:number,radius:number,target:string,mode:number,description:string)
	D.Spells[id]={name=name,raw=raw,line=line,rank=rank,mana=mana,cd=cd,duration=duration,range=range,radius=radius,target=target,mode=mode,description=description}
end
spell("Chidori","Чидори","A01D","SasukeLightning",1,90,60,15,0,0,"Self",0,"Молния в руке. Подготовка 0,8 с. Первый успешный удар ЛКМ расходует заряд: 120 + ловкость + 10 × уровень, паралич 3 с. Сенбон и Эйсо тоже расходуют заряд.")
spell("ChidoriSenbon","Чидори Сенбон","ACbf","SasukeLightning",1,75,40,0,800,100,"Point",0,"Восемь электрических игл, каждая наносит 15 + 0,5 × ловкость. Требует и расходует готовое Чидори. КД 40 с по данным карты; её описание ошибочно указывает 60.")
spell("ChidoriNagashi","Чидори Нагаши","A049","SasukeLightning",2,75,30,4,0,400,"Self",0,"Разряд вокруг тела: ловкость урона в секунду, +100 защиты и 40% сопротивления техникам. Скрипт карты удерживает зону 4 с, хотя описание указывает 3. Радиус эффекта совпадает с зоной урона.")
spell("ChidoriKatana","Чидори Катана","A00C","SasukeLightning",3,70,60,20,0,0,"Self",0,"Заряжает меч на 20 с: +60% урона обычных атак, 14% шанс парализовать на 1 с. Усиливает удар после Аменотеджикары с 50 + ловкость до 200 + ловкость.")
spell("ChidoriEiso","Чидори Эйсо","A033","SasukeLightning",4,240,60,2,600,80,"Point",0,"Копьё молнии: 380 + 3 × ловкость, удержание 2 с. Требует и расходует готовое Чидори.")
spell("OnyxChidori","Ониксовое Чидори","A01D","SasukeEyes",5,60,0,0,0,0,"Self",3,"Усиливает готовое Чидори дополнительной ловкостью урона. Требуется Риннеган; доплата 60 чакры.")
spell("AmaterasuChidori","Чидори-Аматерасу","A01D","SasukeEyes",5,200,0,0,0,0,"Self",3,"Покрывает готовое Чидори чёрным пламенем. Следующий контакт пробивает противника и поджигает его. Требуется Риннеган; доплата 200 чакры.")
spell("SasukeFireball","Гокакью но Дзюцу","A08K","SasukeFire",1,50,35,3,1000,500,"Point",0,"Огненный шар: 35 × ранг + ловкость при попадании, затем (16 × ранг + ловкость) в секунду в течение 3 с. Стоимость 50/60/70/80/90 чакры.")
spell("PhoenixFlowers","Хосенка но Дзюцу","A08K","SasukeFire",1,50,35,0,1000,100,"Point",0,"Двадцать огненных снарядов. Каждый: 30 + 10 × ранг + 0,2 × ловкость; вблизи — 40% урона огненного шара. Общая перезарядка с Гокакью.")
spell("KirinPrepare","Подготовить Кирин","A08K","SasukeFire",5,90,100,4.5,0,0,"Self",0,"Огонь поднимается в небо. Через 4,5 с Кирин доступен на 15 с. Базовый урон: 100 + 30 × уровень + 3 × сила. Дополнительный огонь усиливает разряд.")
spell("KirinBoost","Усилить грозу","A0BF","SasukeFire",5,90,.5,0,0,0,"Self",0,"Во время подготовки Кирина запускает дополнительный огонь: +100 + сила к будущему разряду, до двух усилений.")
spell("Kirin","Кирин","A01B","SasukeFire",5,0,100,1.5,1200,550,"Point",0,"Удар небесной молнии в область радиусом 550. Доступен после подготовки; расходует подготовленную грозу. Видимая область совпадает с радиусом урона.")
spell("Aoda","Призвать Аоду","A03N","SasukeSummon",1,50,60,10,600,0,"Point",0,"Змея самостоятельно атакует ближайших врагов и доступные вышки. Ранги 1–5: 500 HP, 41 урона; 6–10: 1500 HP, 101 урона. Ядовитый укус применяется автоматически (КД 25/20 с), взрослая Аода также душит противника на 4 с (КД 30 с). Время 10 + 5 × (ранг − 1) с; КД 60/150 с.")
spell("Garuda","Призвать Гаруду","A0L3","SasukeSummon",1,0,30,0,0,0,"Self",0,"Низкий полёт на ястребе над рельефом: +30% скорости, расход 1,7% максимальной чакры в секунду. Атаки и техники запрещены; повторное применение завершает полёт.")
spell("Sharingan","Шаринган","A08G","SasukeEyes",1,20,.5,0,0,0,"Self",0,"Расход 10 чакры/с. Шанс 15 + 3 × ранг процентов выполнить контрудар на 1,5 × ловкость. На втором ранге открывается гендзюцу; третий открывает Мангекё.")
spell("Mangekyo","Мангекё / Риннеган","A02F","SasukeEyes",3,0,1,0,0,0,"Self",1,"Развитие включённого Шарингана: III ранг — Мангекё, IV — Вечный Мангекё, V — Риннеган. Дополнительный расход 2 чакры/с. Повторное применение возвращает обычный Шаринган.")
spell("SusanooRibs","Рёбра Сусаноо","A00Q","SasukeEyes",4,10,2,0,0,0,"Self",2,"Защита рёбрами: блок 40% удара до порога 60 + уровень, при пробитии — снижение на 25%. Расход 20% входящего урона и 4 чакры/с. +0,2 × ловкость к атаке.")
spell("Susanoo","Сусаноо","A02G","SasukeEyes",4,200,100,30,0,0,"Self",2,"Дух Сусаноо на 30 с: блок 90% удара до порога 60 + уровень, при пробитии — снижение на 30%. Расход 20% входящего урона. +0,5 × ловкость к атаке.")
spell("CompleteSusanoo","Завершённое Сусаноо","A045","SasukeEyes",4,300,300,30,0,0,"Self",2,"Подготовка 3 с; дополнительно расходует 25% максимальной чакры. На 30 с: +600 HP, +90 защиты, +300 к атаке; дальность 250. Открывает оружие Сусаноо.")
spell("PerfectSusanoo","Биджу Сусаноо","A0HF","SasukeEyes",5,0,300,30,0,0,"Self",3,"Усиление завершённого Сусаноо после поглощения чакры хотя бы одного хвостатого. Продлевает форму, открывает тройные стрелы и Стрелу Индры. Бонус HP: 200 + 200 × число хвостатых, до 2000.")
spell("SasukeModeOff","Завершить режимы","","SasukeEyes",1,0,0,0,0,0,"Self",0,"Убирает Сусаноо, отключает додзюцу и прекращает постоянный расход чакры.")
spell("Amaterasu","Аматерасу","A0H4","SasukeEyes",3,175,100,10,1000,200,"Point",2,"Чёрное пламя на 10 с: суммарно 800 + 5 × ловкость. Требуется Мангекё. Пламя наносит урон только внутри видимой области.")
spell("AmaterasuWall","Стена Аматерасу","A0H4","SasukeEyes",4,175,100,10,0,400,"Self",2,"Кольцо чёрного пламени вокруг Саске на 10 с. Общая перезарядка с Аматерасу.")
spell("Enton","Энтон: Кагутсучи","A0GU","SasukeEyes",4,120,80,10,1000,200,"Point",2,"Направляет чёрное пламя во врагов. В Сусаноо выпускает стрелу: дополнительно 300 + 3 × ловкость и оглушение 1 с.")
spell("EntonPull","Энтон: Хоноиказучи","A0GU","SasukeEyes",5,120,80,2,500,500,"Self",3,"Притягивает врагов и пронзает шипами: 350 + 3 × ловкость, удержание 2 с. Общая перезарядка с Энтоном.")
spell("Extinguish","Потушить Аматерасу","A0GV","SasukeEyes",3,50,2,0,600,400,"Point",2,"Гасит чёрное пламя в выбранной области радиусом 400, в том числе на союзниках.")
spell("SasukeGenjutsu","Гендзюцу Шарингана","A06I","SasukeEyes",2,90,60,3,250,0,"Enemy",1,"Усыпляет на 3 с, при Мангекё — на 4 с. Атака будит цель; удар врага дополнительно наносит 50 урона. При Риннегане дальность увеличивается до 500.")
spell("Amenotejikara","Аменотеджикара","A0F9","SasukeEyes",5,80,30,4,1100,0,"Any",3,"На землю — телепортация и окно усиленного удара 1 с. На врага — выбор на 4 с: повторно укажите врага, чтобы поменяться местами, или землю, чтобы перенести его. Повторный выбор не расходует чакру.")
spell("ChakraAbsorb","Поглотить чакру","","SasukeEyes",5,0,0,0,500,0,"Enemy",3,"Поглощает чакру поверженного хвостатого для Биджу Сусаноо. Требуется цель с доступной чакрой хвостатого; один источник нельзя поглотить повторно.")
spell("ChibakuTensei","Чибаку Тенсей","A0HG","SasukeEyes",5,500,300,30,1400,500,"Point",3,"Создаёт девять гравитационных сфер на 30 с. Можно переместить или обрушить. Падение через 0,9 с: 400 + 3 × ловкость в области каждой сферы.")
spell("ChibakuMove","Переместить сферы","A0HH","SasukeEyes",5,25,5,0,2000,0,"Point",3,"Перемещает действующие сферы Чибаку Тенсей к выбранной области со скоростью 500.")
spell("ChibakuDrop","Обрушить сферы","A0HI","SasukeEyes",5,0,20,.9,0,500,"Self",3,"Обрушивает действующие сферы через 0,9 с. Красные области показывают точные зоны попадания.")
spell("SusanooChidori","Чидори Сусаноо","A0HK","SasukeEyes",4,210,100,15,0,0,"Self",2,"Готовит Чидори в руке завершённого Сусаноо: 400 + 2 × ловкость и паралич 3 с при первом успешном ударе.")
spell("SusanooTriple","Тройная стрела","A0HL","SasukeEyes",5,300,100,1.5,1850,700,"Point",3,"Три стрелы Биджу Сусаноо: 600 + 3 × ловкость. Урон пересекающихся взрывов не складывается. Один раз за форму.")
spell("IndraArrow","Стрела Индры","A0HP","SasukeEyes",5,800,150,1.5,2500,2000,"Point",3,"Стрела Биджу Сусаноо: 700 + 4 × ловкость, при семи поглощённых хвостатых — 800 + 5 × ловкость. Один раз за форму.")
function D.rank(learned:{[string]:number},id:string):number
	local s=D.Spells[id];return if s then learned[s.line] or 0 else 0
end
function D.cooldownKey(id:string):string
	return if id=="PhoenixFlowers" then "SasukeFireball" elseif id=="AmaterasuWall" then "Amaterasu" elseif id=="EntonPull" then "Enton" else id
end
function D.cost(id:string,rank:number):number
	if id=="SasukeFireball" or id=="PhoenixFlowers" then return 40+10*rank end
	if id=="Aoda" then return if rank>=9 then 300 elseif rank>=5 then 150 else 50 end
	return D.Spells[id].mana
end
function D.cooldown(id:string,rank:number):number return if id=="Aoda" and rank>=6 then 150 else D.Spells[id].cd end
function D.chidoriDamage(level:number,agility:number,variant:string):number
	return if variant=="SusanooChidori" then 400+2*agility else 120+10*level+agility*(if variant=="OnyxChidori" then 2 else 1)
end
return table.freeze(D)
