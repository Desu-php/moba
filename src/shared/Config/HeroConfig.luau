--!strict
export type Hero = { Name: string, Profile: string, Abilities: { string } }
local heroes: { [string]: Hero } = {
	OrangeNinja = { Name = "Наруто · базовый прототип", Profile = "OrangeNinja",
		Abilities = { "Odama", "Rasenshuriken", "ShadowSleep", "Rasengan", "ShadowClones", "Gamakichi", "SageMode", "KCM", "KcmDash", "KcmCancel", "KuramaConvert", "KuramaForm", "CloneCommand", "GamakichiOil", "GamakichiChop", "MeditationToggle", "MeditationRecall" } },
}
return table.freeze({ DefaultHero = "OrangeNinja", Heroes = heroes, AppearanceVersion = 1 })
