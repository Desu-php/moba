--!strict
local Rules = {}
function Rules.isStructure(kind: any): boolean return kind == "Base" or kind == "Tower" end
function Rules.canReceive(kind: any, remainingTowers: number): boolean
	return kind ~= "Base" or remainingTowers <= 0
end
return Rules
