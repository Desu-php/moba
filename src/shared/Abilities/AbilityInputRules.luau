--!strict
-- One key resolves to one request. KCM cancel takes X only while that form is active.
local Rules = {}
function Rules.resolve(aliases: { read [string]: string }, key: string, kcmActive: boolean): string?
	if key == "X" and kcmActive then return "KcmCancel" end
	return aliases[key]
end
return Rules
