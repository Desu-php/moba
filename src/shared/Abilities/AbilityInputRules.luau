--!strict
-- One key resolves to one request. KCM cancel takes X only while that form is active.
local Rules = {}
function Rules.ownsArrow(key: string, textFocused: boolean, menuOpen: boolean, guiSelected: boolean, shopOpen: boolean): boolean
	return (key == "Right" or key == "Left") and not (textFocused or menuOpen or guiSelected or shopOpen)
end
function Rules.resolve(aliases: { read [string]: string }, key: string, kcmActive: boolean): string?
	if key == "X" and kcmActive then return "KcmCancel" end
	return aliases[key]
end
return Rules
