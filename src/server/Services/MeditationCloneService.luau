--!strict
-- Entity adapter. Owner validation and mana credit are injected by NarutoAbilityService.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Domain=require(Shared.Abilities.MeditationState)
local Units=require(Shared.Abilities.WorldUnits)
local Fighters=require(script.Parent.FighterStateService)
local Collision=require(script.Parent.SummonCollision)
type Record={model: Model, humanoid: Humanoid, owner: Player, character: Model, state: Domain.State, clone: Domain.Clone, valid: ()->boolean, credit: (number)->(), connection: RBXScriptConnection?}
local records: {[Model]: Record}={}
local Service={}
function Service.GetAll(): {[Model]: Record} return records end
-- Kurama pulses credit the owned domain pool, never just its replicated display.
function Service.RestoreMana(model: Model, amount: number): boolean
 local record=records[model]
 if not record or not model:IsDescendantOf(workspace) or record.humanoid.Health<=0 or not record.valid() then return false end
 if not Domain.restore(record.state,record.clone,workspace:GetServerTimeNow(),amount) then return false end
 model:SetAttribute("Mana",record.clone.mana)
 return true
end
local function remove(record: Record, now: number, transfer: boolean)
 if records[record.model]~=record then return end
 records[record.model]=nil
 if record.connection then record.connection:Disconnect() end
 local amount=Domain.settle(record.state,record.clone,now,transfer and record.valid())
 if amount>0 then record.credit(amount) end
 Fighters.Remove(record.model); record.model:Destroy()
end
function Service.ClearOwner(owner: Player)
 for _,record in records do if record.owner==owner then remove(record,workspace:GetServerTimeNow(),false) end end
end
function Service.Reset()
 for _,record in records do remove(record,workspace:GetServerTimeNow(),false) end
end
function Service.Recall(owner: Player, now: number)
 for _,record in records do if record.owner==owner then remove(record,now,true) end end
end
function Service.Spawn(owner: Player, character: Model, state: Domain.State, clones: {Domain.Clone}, valid: ()->boolean, credit: (number)->())
 local sourceRoot=character:FindFirstChild("HumanoidRootPart")
 if not sourceRoot or not sourceRoot:IsA("BasePart") then
  for _,clone in clones do Domain.settle(state,clone,workspace:GetServerTimeNow(),false) end
  return
 end
 for index,clone in clones do
  local archivable=character.Archivable; character.Archivable=true
  local model=character:Clone(); character.Archivable=archivable
  -- Remove inherited combat/VFX tags and state, keep only identity/team/round.
  for _,tag in game:GetService("CollectionService"):GetTags(model) do game:GetService("CollectionService"):RemoveTag(model,tag) end
  for key in model:GetAttributes() do
   if key~="TeamId" and key~="RoundId" and key~="HeroId" then model:SetAttribute(key,nil) end
  end
  for _,item in model:GetDescendants() do
   if item:IsA("LuaSourceContainer") or item:IsA("Tool") or item:IsA("ForceField") then item:Destroy()
   elseif item:IsA("BasePart") then item.CanCollide=false; item.CanTouch=false; item.Massless=true end
  end
  local root=model:FindFirstChild("HumanoidRootPart")
  local humanoid=model:FindFirstChildOfClass("Humanoid")
  if not root or not root:IsA("BasePart") or not humanoid then
   Domain.settle(state,clone,workspace:GetServerTimeNow(),false); model:Destroy(); continue
  end
  model.Name="MeditationClone"
  model:SetAttribute("EntityKind","Summon"); model:SetAttribute("NativeMeditationClone",true)
  model:SetAttribute("SummonOwner",owner.UserId); model:SetAttribute("CombatDisabled",false)
  model:SetAttribute("MeditationExpiresAt",clone.expiresAt); model:SetAttribute("Mana",clone.mana); model:SetAttribute("MaxMana",clone.maximum)
  humanoid.MaxHealth=1; humanoid.Health=1; humanoid.WalkSpeed=0; humanoid.AutoRotate=false
  humanoid.BreakJointsOnDeath=false; humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
  root.Anchored=true; model.PrimaryPart=root
  -- Side placement in studs; clamp against walls. Kurama retains larger offset policy.
  local distance=Units.toStuds(if clone.maximum==2000 then 300 else 100)
  local offset=sourceRoot.CFrame.RightVector*(if index==1 then -distance else distance)
  local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={character}; params.RespectCanCollide=true
  local wall=workspace:Blockcast(sourceRoot.CFrame,sourceRoot.Size,offset,params)
  if wall then offset=offset.Unit*math.max(0,wall.Distance-.1) end
  local folder=workspace:FindFirstChild("HeroSummons")
  if not folder then folder=Instance.new("Folder"); folder.Name="HeroSummons"; folder.Parent=workspace end
  Collision.Apply(model)
  model:PivotTo(character:GetPivot()+offset); model.Parent=folder
  -- A built-in seated meditation pose; no external animation/asset dependency.
  humanoid.Sit=true
  local record: Record={model=model,humanoid=humanoid,owner=owner,character=character,state=state,clone=clone,valid=valid,credit=credit,connection=nil}
  records[model]=record
  record.connection=humanoid.Died:Connect(function() remove(record,workspace:GetServerTimeNow(),true) end)
  Fighters.GetOrCreate(model)
 end
end
function Service.Update(now: number)
 for _,record in records do
  if not record.valid() or not Domain.live(record.state,record.clone) or not record.model.Parent then remove(record,now,false)
  elseif record.humanoid.Health<=0 or now>=record.clone.expiresAt then remove(record,now,true)
  else Domain.update(record.state,record.clone,now); record.model:SetAttribute("Mana",record.clone.mana) end
 end
end
return Service
