--!strict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Abilities.GamakichiSpells)
local Fighters=require(script.Parent.FighterStateService)
local Teams=require(script.Parent.TeamService)
type Record={state: Rules.Debuff,round: number}
local records: {[Model]: Record}={}
local random=Random.new()
local Service={}
local function publish(model: Model,r: Record,now: number)
 local ends=Rules.untilAt(r.state,now)
 local tags=game:GetService("CollectionService")
 if ends>now then tags:AddTag(model,"GamakichiOilStatus") else tags:RemoveTag(model,"GamakichiOilStatus") end
 model:SetAttribute("OilUntil",if ends>now then ends else nil)
 model:SetAttribute("OilMoveMultiplier",if ends>now then 1-Rules.Oil.MoveReduction else nil)
 Fighters.SetWalkSpeed(model,Fighters.GetWalkSpeed(model))
end
function Service.Apply(model: Model,key: string,now: number)
 local match=Teams.GetState(); local round=if match then match.roundId else 0
 local r=records[model]
 if not r or r.round~=round then r={state=Rules.debuff(),round=round}; records[model]=r end
 Rules.apply(r.state,key,now); publish(model,r,now)
end
function Service.ClearSource(key: string)
 local now=workspace:GetServerTimeNow()
 for model,r in records do Rules.clear(r.state,key); publish(model,r,now) end
end
function Service.Movement(model: Model,now: number): number
 local r=records[model]; return if r then Rules.movement(r.state,now) else 1
end
function Service.MissesAttack(model: Model): boolean
 local r=records[model]; local now=workspace:GetServerTimeNow()
 local missed=r~=nil and Rules.misses(r.state,now,random:NextNumber())
 if missed then model:SetAttribute("OilMissAt",now) end
 return missed
end
function Service.Update(now: number)
 local match=Teams.GetState()
 for model,r in records do
  local hp=model:FindFirstChildOfClass("Humanoid")
  if not model.Parent or not hp or hp.Health<=0 or (match and (match.roundId~=r.round or match.phase~="InProgress")) then table.clear(r.state.grants) end
  if Rules.untilAt(r.state,now)==0 then publish(model,r,now); records[model]=nil end
 end
end
function Service.Reset()
 local now=workspace:GetServerTimeNow()
 for model,r in records do table.clear(r.state.grants); publish(model,r,now) end
 table.clear(records)
end
return Service
