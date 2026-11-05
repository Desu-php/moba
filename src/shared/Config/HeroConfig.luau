--!strict
export type Hero = { Name: string, Profile: string, Abilities: { string } }
local heroes: { [string]: Hero } = {
	OrangeNinja = { Name = "Наруто · базовый прототип", Profile = "OrangeNinja",
		Abilities = { "MeditationCast", "RasenshurikenThrow", "RikudoHY", "RikudoHZ", "Odama", "Rasenshuriken", "Rasengan", "ShadowClones", "Gamakichi", "SageMode", "KCM", "KcmDash", "KcmCancel", "KuramaConvert", "KuramaForm", "CloneCommand", "GamakichiOil", "GamakichiChop", "MeditationToggle", "MeditationRecall" } },
}
local sasuke = {}
for id in require("../Abilities/SasukeDefinitions").Spells do table.insert(sasuke,id) end
heroes.Sasuke = {Name="Саске Учиха",Profile="Sasuke",Abilities=sasuke}
return table.freeze({ DefaultHero = "OrangeNinja", Heroes = heroes, AppearanceVersion = 1 })
