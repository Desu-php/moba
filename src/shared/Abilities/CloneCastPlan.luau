--!strict
-- Explicit Roblox policy: mass eligibility reads mana AFTER base 200 debit.
local Domain=require("./NarutoRules")
local Rules=Domain.configure(require("./NarutoDefinitions"))
local Plan={}
function Plan.create(rank: number,target: string,mana: number,maximum: number): (Domain.ClonePlan?, string)
 if mana~=mana or mana<200 or mana==math.huge then return nil,"Mana" end
 return Rules.clonePlan(rank,target,mana-200,maximum)
end
return table.freeze(Plan)
