--!strict
export type Hero = { Name: string, Profile: string, Abilities: { string } }
local heroes: { [string]: Hero } = {
	OrangeNinja = { Name = "Наруто · базовый прототип", Profile = "OrangeNinja",
		Abilities = { "Rasengan", "ShadowClones", "Gamakichi", "SageMode", "KCM", "CloneCommand", "GamakichiOil", "GamakichiChop" } },
}
return table.freeze({ DefaultHero = "OrangeNinja", Heroes = heroes, AppearanceVersion = 1 })
