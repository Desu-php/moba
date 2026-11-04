--!strict
local Rules = {}

function Rules.setting(value: any, fallback: number, minimum: number, maximum: number): number
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(value, minimum, maximum)
end

function Rules.alpha(rate: number, dt: number): number
	if rate <= 0 then return 1 end
	return 1 - math.exp(-rate * math.max(0, dt))
end

function Rules.move(x: number, z: number): (number, number)
	local length = math.sqrt(x * x + z * z)
	if length > 1 then return x / length, z / length end
	return x, z
end

function Rules.captured(focused: boolean, menu: boolean, text: boolean, shop: boolean, stats: boolean, cursor: boolean): boolean
	return focused and not (menu or text or shop or stats or cursor)
end

return Rules
