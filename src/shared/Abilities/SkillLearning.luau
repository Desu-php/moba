--!strict
-- Initial point/+1 per level follow documented native defaults. Clone unlock is MVP policy.
export type Profile = { Level: number, SkillPoints: number, Learned: { [string]: number } }
local Learning = {}
Learning.Order = table.freeze({ "Rasengan", "ShadowClones", "Gamakichi", "SageMode", "KCM" })
local lines: { [string]: { max: number, runtime: number, levels: { number } } } = {
	Rasengan = { max=3, runtime=1, levels={4,11,18} },
	ShadowClones = { max=4, runtime=1, levels={1} }, -- Provisional initial unlock; inherited native field unresolved.
	Gamakichi = { max=10, runtime=0, levels={} },
	SageMode = { max=3, runtime=0, levels={6,10,14} },
	KCM = { max=3, runtime=0, levels={13,20,27} },
}
function Learning.reason(profile: Profile, id: string): string?
	local line = lines[id]; if not line then return "UnknownAbility" end
	local rank = profile.Learned[id] or 0
	if rank >= line.max then return "MaxRank" end
	if rank >= line.runtime then return "NotImplemented" end
	local required = line.levels[rank+1]; if not required then return "SourceUnknown" end
	if profile.Level < required then return "Level" end
	if profile.SkillPoints <= 0 then return "NoPoints" end
	return nil
end
function Learning.learn(profile: Profile, id: string): (boolean, string)
	local reason = Learning.reason(profile,id); if reason then return false,reason end
	profile.SkillPoints -= 1; profile.Learned[id] = (profile.Learned[id] or 0)+1
	return true,"Learned"
end
return Learning
