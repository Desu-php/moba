--!strict
-- Compatibility resolver for the three direct Rasengan aliases. Family routing owns other inputs.
local Rules = {}
function Rules.ownsArrow(key: string, textFocused: boolean, menuOpen: boolean, guiSelected: boolean, shopOpen: boolean): boolean
	return (key == "Right" or key == "Left") and not (textFocused or menuOpen or guiSelected or shopOpen)
end
function Rules.resolve(aliases: { read [string]: string }, key: string, _kcmActive: boolean): string?
	return aliases[key]
end
return Rules
