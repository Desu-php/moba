--!strict
-- Explicit Roblox policy: mass eligibility reads mana AFTER base 200 debit.
local Domain=require("./NarutoRules")
local Rules=Domain.configure(require("./NarutoDefinitions"))
local Plan={}
function Plan.create(rank: number,target: string,mana: number,maximum: number,fullKurama: boolean?): (Domain.ClonePlan?, string)
 if mana~=mana or mana<200 or mana==math.huge then return nil,"Mana" end
 local plan,reason=Rules.clonePlan(rank,target,mana-200,maximum)
 if plan and plan.kind=="Burst" and fullKurama then
  -- war3map.j 45196,45239-45263: B03V keeps the initial four; only non-Kurama
  -- casts enter rank-count and self-target mass-count/extra-mana branches.
  plan.count=4; plan.extraManaDrain=0
 end
 return plan,reason
end
return table.freeze(Plan)
