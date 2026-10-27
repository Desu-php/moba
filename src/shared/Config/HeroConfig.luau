--!strict
export type Hero = { Name: string, Profile: string, Abilities: { string } }
local heroes: { [string]: Hero } = {
	OrangeNinja = { Name = "Оранжевый ниндзя", Profile = "OrangeNinja", Abilities = { "ShadowClones", "SpiralSphere", "WindPalm" } },
}
return table.freeze({ DefaultHero = "OrangeNinja", Heroes = heroes, AppearanceVersion = 1 })
