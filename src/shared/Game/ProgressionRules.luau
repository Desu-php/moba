--!strict
export type Configuration = {
 read StartingLevel: number, read MaxLevel: number, read XPBase: number, read XPPerLevel: number, read MaxGrant: number, read MaxGold: number,
 read BaseStats: { MaxHealth: number, WalkSpeed: number, AttackDamageMultiplier: number, Defense: number },
 read HealthPerLevel: number, read DamagePerLevel: number, read DefenseScale: number,
}
export type Item = { Name: string, Description: string, Permanent: boolean, Cost: number, DamageBonus: number?, HealthBonus: number?, SpeedBonus: number?, DefenseBonus: number?, Heal: number? }
export type Profile = { Level: number, CurrentXP: number, TotalKills: number, TotalDeaths: number, TotalMinionKills: number, Assists: number, Owned: { [string]: boolean } }
export type Stats = { MaxHealth: number, WalkSpeed: number, AttackDamageMultiplier: number, Defense: number, Level: number }
local Module = {}
function Module.configure(Config: Configuration, items: { [string]: Item })
local Rules = {}
function Rules.validAmount(amount: number): boolean
 if typeof(amount) ~= "number" then return false end
 return amount == amount and amount >= 0 and amount <= Config.MaxGrant and amount % 1 == 0
end
function Rules.new(): Profile
 return { Level = Config.StartingLevel, CurrentXP = 0, TotalKills = 0, TotalDeaths = 0, TotalMinionKills = 0, Assists = 0, Owned = {} }
end
function Rules.required(level: number): number
 return if level >= Config.MaxLevel then 0 else Config.XPBase + (level - 1) * Config.XPPerLevel
end
function Rules.addXP(profile: Profile, amount: number): (number, number)
 if not Rules.validAmount(amount) or profile.Level >= Config.MaxLevel then return 0, 0 end
 local levels = 0
 profile.CurrentXP += amount
 while profile.Level < Config.MaxLevel and profile.CurrentXP >= Rules.required(profile.Level) do
  profile.CurrentXP -= Rules.required(profile.Level); profile.Level += 1; levels += 1
 end
 if profile.Level >= Config.MaxLevel then profile.CurrentXP = 0 end
 return levels, amount
end
function Rules.stats(profile: Profile): Stats
 local levels = math.clamp(profile.Level, 1, Config.MaxLevel) - 1
 local base = Config.BaseStats
 local result = { MaxHealth = base.MaxHealth + levels * Config.HealthPerLevel, WalkSpeed = base.WalkSpeed,
  AttackDamageMultiplier = base.AttackDamageMultiplier + levels * Config.DamagePerLevel, Defense = base.Defense, Level = profile.Level }
 for id, owned in profile.Owned do
  local item = items[id]
  if owned and item and item.Permanent then
   result.MaxHealth += item.HealthBonus or 0; result.WalkSpeed += item.SpeedBonus or 0
   result.AttackDamageMultiplier += item.DamageBonus or 0; result.Defense += item.DefenseBonus or 0
  end
 end
 return result
end
function Rules.mitigate(amount: number, defense: number): number
 return amount * Config.DefenseScale / (Config.DefenseScale + math.max(0, defense))
end
function Rules.balanceAfter(balance: number, amount: number, spend: boolean): number?
 if not Rules.validAmount(amount) then return nil end
 if spend then return if balance >= amount then balance - amount else nil end
 return math.min(Config.MaxGold, balance + amount)
end
function Rules.purchaseReason(profile: Profile, gold: number, id: string, health: number, maximum: number): string?
 local item = items[id]
 if not item then return "UnknownItem" end
 if item.Permanent and profile.Owned[id] then return "Purchased" end
 if item.Heal and health >= maximum then return "FullHealth" end
 if gold < item.Cost then return "NotEnoughGold" end
 return nil
end
return Rules
end
return Module
