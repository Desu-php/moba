--!strict
export type Item = {
 Name: string, Description: string, Cost: number, Permanent: boolean,
 DamageBonus: number?, HealthBonus: number?, SpeedBonus: number?, DefenseBonus: number?, Heal: number?,
}
local items: { [string]: Item } = {
 IronBlade = { Name = "Iron Blade", Description = "+15% к базовому урону", Cost = 200, Permanent = true, DamageBonus = 0.15 },
 GuardianArmor = { Name = "Guardian Armor", Description = "+40 максимального HP", Cost = 200, Permanent = true, HealthBonus = 40 },
 SwiftBoots = { Name = "Swift Boots", Description = "+2 к скорости передвижения", Cost = 150, Permanent = true, SpeedBonus = 2 },
 HealingPotion = { Name = "Healing Potion", Description = "Сразу восстанавливает 60 HP", Cost = 100, Permanent = false, Heal = 60 },
}
return { Order = { "IronBlade", "GuardianArmor", "SwiftBoots", "HealingPotion" }, Items = items }
