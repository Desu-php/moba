--!strict
-- Prototype native-default inference from the supplement, not exact Warcraft runtime parity.
export type Hero = { read Strength: number, read StrengthGrowth: number, read Intelligence: number,
	read IntelligenceGrowth: number, read BaseMana: number }
export type Native = { read ManaPerIntelligence: number, read RegenPerIntelligence: number, read BaseManaRegen: number }
export type Values = { rawStrength: number, strength: number, intelligence: number, maxMana: number, regen: number }
export type Pool = { mana: number, maximum: number, regen: number, at: number }
local Module = {}
local function finite(value: number): boolean return value == value and math.abs(value) < math.huge end
function Module.configure(hero: Hero, native: Native)
	local Rules = {}
	function Rules.values(level: number, strengthBonus: number): Values
		assert(finite(level) and level >= 1 and level % 1 == 0 and finite(strengthBonus))
		local raw = hero.Strength + (level - 1) * hero.StrengthGrowth + strengthBonus
		-- Explicit provisional floor policy; preserve raw growth for later engine comparison.
		local strength = math.max(0, math.floor(raw + 1e-9))
		local intelligence = hero.Intelligence + (level - 1) * hero.IntelligenceGrowth
		return { rawStrength = raw, strength = strength, intelligence = intelligence,
			maxMana = hero.BaseMana + native.ManaPerIntelligence * intelligence,
			regen = native.BaseManaRegen + native.RegenPerIntelligence * intelligence }
	end
	return Rules
end
function Module.new(values: Values, now: number): Pool
	return { mana = values.maxMana, maximum = values.maxMana, regen = values.regen, at = now }
end
function Module.update(pool: Pool, now: number)
	if not finite(now) or now < pool.at then return end
	pool.mana = math.min(pool.maximum, pool.mana + (now - pool.at) * pool.regen); pool.at = now
end
function Module.recalculate(pool: Pool, values: Values, now: number)
	Module.update(pool, now); pool.maximum = values.maxMana; pool.regen = values.regen
	pool.mana = math.min(pool.mana, pool.maximum) -- Level-up does not invent a mana refill.
end
function Module.spend(pool: Pool, amount: number): boolean
	if not finite(amount) or amount < 0 or amount > pool.mana then return false end
	pool.mana -= amount; return true
end
return Module
