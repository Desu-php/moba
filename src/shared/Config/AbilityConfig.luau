--!strict
export type Ability = { Name: string, Key: string, KeyLabel: string, Cooldown: number, Windup: number, Duration: number }
local abilities: { [string]: Ability } = {
 RasenshurikenThrow={Name="Бросок Расенсюрикена",Key="Unknown",KeyLabel="ЛКМ",Cooldown=0,Windup=.35,Duration=3.5},
 RikudoHY={Name="Cho Bijudama RS",Key="V",KeyLabel="V",Cooldown=60,Windup=1.5,Duration=8},
 RikudoHZ={Name="Cho Bijuu RS",Key="B",KeyLabel="B",Cooldown=60,Windup=1.5,Duration=8},
 MeditationToggle={Name="Медитация",Key="Right",KeyLabel="→",Cooldown=0,Windup=0,Duration=0},
 MeditationRecall={Name="Вернуть чакру",Key="J",KeyLabel="J",Cooldown=5,Windup=0,Duration=0},
 Odama={Name="Одама Расенган",Key="Z",KeyLabel="Z",Cooldown=40,Windup=2,Duration=15},
 Rasenshuriken={Name="Расенсюрикен",Key="X",KeyLabel="X",Cooldown=60,Windup=1.3,Duration=15},
 ShadowSleep={Name="Sleep (enemy)",Key="T",KeyLabel="T",Cooldown=0,Windup=0,Duration=3},
 KuramaForm={Name="Курама",Key="Six",KeyLabel="6",Cooldown=160,Windup=0,Duration=30},
 KcmDash={Name="KCM Dash",Key="E",KeyLabel="E",Cooldown=40,Windup=0,Duration=0},
 KcmCancel={Name="KCM Cancel",Key="X",KeyLabel="X",Cooldown=0,Windup=0,Duration=0},
 KuramaConvert={Name="Kurama Chakra",Key="Left",KeyLabel="Left",Cooldown=0,Windup=0,Duration=0},
 GamakichiOil={Name="Масло",Key="G",KeyLabel="G",Cooldown=25,Windup=0,Duration=6},
 GamakichiChop={Name="Рубящий канал",Key="H",KeyLabel="H",Cooldown=30,Windup=.5,Duration=3.5},
	Rasengan = { Name = "Расенган I", Key = "One", KeyLabel = "1 / Q", Cooldown = 60, Windup = 2, Duration = 15 },
	ShadowClones = { Name = "Клоны I", Key = "Two", KeyLabel = "2", Cooldown = 50, Windup = 0.25, Duration = 20 },
	Gamakichi = { Name = "Гамакичи", Key = "Three", KeyLabel = "3", Cooldown = 0, Windup = 0, Duration = 0 },
	SageMode = { Name = "Режим мудреца", Key = "Four", KeyLabel = "4", Cooldown = 150, Windup = 10, Duration = 51 },
	KCM = { Name = "KCM", Key = "Five", KeyLabel = "5", Cooldown = 10, Windup = 0, Duration = 0 },
	CloneCommand = { Name = "Цель клонам", Key = "F", KeyLabel = "F", Cooldown = 0, Windup = 0, Duration = 0 },
}
return table.freeze({
	Abilities = abilities, Order = { "Rasengan", "ShadowClones", "Gamakichi", "SageMode", "KCM", "CloneCommand", "GamakichiOil", "GamakichiChop" },
	PrototypeEnabled = table.freeze({ RasenshurikenThrow=true, RikudoHY=true, RikudoHZ=true, KuramaForm=true, KCM=true, KcmDash=true, KcmCancel=true, KuramaConvert=true, Odama=true, Rasenshuriken=true, ShadowSleep=true, Rasengan = true, ShadowClones = true, Gamakichi = true, CloneCommand = true, GamakichiOil=true, GamakichiChop=true, SageMode=true, MeditationToggle=true, MeditationRecall=true }),
	InputAliases = table.freeze({ V="RikudoHY", B="RikudoHZ", Q = "Rasengan", Six="KuramaForm", E="KcmDash", Left="KuramaConvert", Z="Odama", X="Rasenshuriken", T="ShadowSleep", Right = "MeditationToggle", J = "MeditationRecall" }),
	MaxRequestId = 2147483647, Burst = 4, RequestsPerSecond = 3, ReplyInterval = 0.25,
	Clones = { Count = 2, GlobalLimit = 24, Lifetime = 5, Radius = 18, Range = 4, Damage = 3,
		MaxHits = 3, Interval = 0.8, UpdateInterval = 0.1, Speed = 16, SpawnOffset = 3, SpawnForward = 1 },
	Visual = { MaxEffects = 32, SmokeLifetime = 0.55, ViewDistance = 240, BlendSpeed = 20, HUDInterval = 0.1 },
})
