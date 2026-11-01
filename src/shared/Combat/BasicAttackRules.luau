--!strict
-- Naruto balance: the actual AGI stat improves attack rate. No combo progression.
export type Profile = { read AttackCooldown: number, read AttackSpeedPerAgility: number, read MaxAttacksPerSecond: number }
local Rules = {}
function Rules.speed(profile: Profile, agility: number): number
 if agility ~= agility or math.abs(agility) == math.huge then agility = 0 end
 return math.min(1 + math.max(0, agility) * profile.AttackSpeedPerAgility, profile.MaxAttacksPerSecond * profile.AttackCooldown)
end
return Rules
