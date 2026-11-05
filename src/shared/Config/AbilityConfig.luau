--!strict
export type Ability = { Name: string, Key: string, KeyLabel: string, Cooldown: number, Windup: number, Duration: number }
local abilities: { [string]: Ability } = {
 MeditationCast={Name="Медитация с клонами",Key="Unknown",KeyLabel="T → T",Cooldown=150,Windup=0,Duration=51},
 RasenshurikenThrow={Name="Бросок Расенсюрикена",Key="Unknown",KeyLabel="ЛКМ",Cooldown=0,Windup=.35,Duration=3.5},
 RikudoHY={Name="Cho Bijudama RS",Key="V",KeyLabel="F → Z",Cooldown=60,Windup=1.5,Duration=8},
 RikudoHZ={Name="Cho Bijuu RS",Key="B",KeyLabel="F → X",Cooldown=60,Windup=1.5,Duration=8},
 MeditationToggle={Name="Медитация",Key="Right",KeyLabel="Архив",Cooldown=0,Windup=0,Duration=0},
 MeditationRecall={Name="Вернуть чакру",Key="J",KeyLabel="T → Z",Cooldown=5,Windup=0,Duration=0},
 Odama={Name="Одама Расенган",Key="Z",KeyLabel="Q → Z",Cooldown=40,Windup=2,Duration=15},
 Rasenshuriken={Name="Расенсюрикен",Key="X",KeyLabel="Q → X",Cooldown=60,Windup=1.3,Duration=15},
 ShadowSleep={Name="Сон противника",Key="T",KeyLabel="E → Z",Cooldown=0,Windup=0,Duration=3},
 KuramaForm={Name="Курама",Key="Six",KeyLabel="C → X",Cooldown=160,Windup=0,Duration=30},
 KcmDash={Name="Рывок KCM",Key="E",KeyLabel="F → F",Cooldown=40,Windup=0,Duration=0},
 KcmCancel={Name="Выйти из KCM",Key="X",KeyLabel="C → V",Cooldown=0,Windup=0,Duration=0},
 KuramaConvert={Name="Обмен чакры",Key="Left",KeyLabel="T → X",Cooldown=0,Windup=0,Duration=0},
 GamakichiOil={Name="Масло",Key="G",KeyLabel="R → Z",Cooldown=25,Windup=0,Duration=6},
 GamakichiChop={Name="Рубящий канал",Key="H",KeyLabel="R → X",Cooldown=30,Windup=.5,Duration=3.5},
	Rasengan = { Name = "Расенган I", Key = "One", KeyLabel = "Q", Cooldown = 60, Windup = 2, Duration = 15 },
	ShadowClones = { Name = "Клоны I", Key = "Two", KeyLabel = "E → E", Cooldown = 50, Windup = 0.25, Duration = 20 },
	Gamakichi = { Name = "Гамакичи", Key = "Three", KeyLabel = "R → R", Cooldown = 0, Windup = 0, Duration = 0 },
	SageMode = { Name = "Режим мудреца", Key = "Four", KeyLabel = "C → C", Cooldown = 150, Windup = 10, Duration = 51 },
	KCM = { Name = "KCM", Key = "Five", KeyLabel = "C → Z", Cooldown = 10, Windup = 0, Duration = 0 },
	CloneCommand = { Name = "Цель клонам", Key = "F", KeyLabel = "E → X", Cooldown = 0, Windup = 0, Duration = 0 },
}
for id,d in require("../Abilities/SasukeDefinitions").Spells do
 abilities[id]={Name=d.name,Key="Unknown",KeyLabel="Семейство",Cooldown=d.cd,Windup=0,Duration=d.duration}
end
return table.freeze({
	Abilities = abilities, Order = { "Rasengan", "ShadowClones", "Gamakichi", "SageMode", "KCM", "KuramaForm" },
	PrototypeEnabled = table.freeze({ MeditationCast=true, RasenshurikenThrow=true, RikudoHY=true, RikudoHZ=true, KuramaForm=true, KCM=true, KcmDash=true, KcmCancel=true, KuramaConvert=true, Odama=true, Rasenshuriken=true, ShadowSleep=false, Rasengan = true, ShadowClones = true, Gamakichi = true, CloneCommand = true, GamakichiOil=true, GamakichiChop=true, SageMode=true, MeditationToggle=true, MeditationRecall=true }),
	InputAliases = table.freeze({ Q="Rasengan", Z="Odama", X="Rasenshuriken" }),
	MaxRequestId = 2147483647, Burst = 4, RequestsPerSecond = 3, ReplyInterval = 0.25,
	Clones = { Count = 2, GlobalLimit = 24, Lifetime = 5, Radius = 18, Range = 4, Damage = 3,
		MaxHits = 3, Interval = 0.8, UpdateInterval = 0.1, Speed = 16, SpawnOffset = 3, SpawnForward = 1 },
	Visual = { MaxEffects = 32, SmokeLifetime = 0.55, ViewDistance = 240, BlendSpeed = 20, HUDInterval = 0.1 },
})
