--!strict
local Fighters=require(script.Parent.FighterStateService)
local Damage=require(script.Parent.DamageService)
local Teams=require(script.Parent.TeamService)
local Sleep=require(game.ReplicatedStorage.Shared.Abilities.SleepState)
local Service={}
local cosmetics: {[Model]: number}={}
function Service.CanWakeAlly(attacker: Model,target: Model): boolean
 if attacker==target or not Damage.CanAct(attacker) or not Damage.CanAct(target)
  or Teams.IsNeutral(attacker) or Teams.IsNeutral(target) or target:FindFirstChildOfClass("ForceField") then return false end
 local team=Teams.GetId(attacker)
 if not team or team~=Teams.GetId(target) or not Teams.IsActive(team) then return false end
 local kind=target:GetAttribute("EntityKind")
 if kind~="Hero" and kind~="Minion" and kind~="Summon" then return false end
 local fighter=Fighters.Get(target)
 return fighter~=nil and Sleep.isActive(fighter.sleep,workspace:GetServerTimeNow())
end
function Service.TryWakeAlly(attacker: Model,target: Model): boolean
 if not Service.CanWakeAlly(attacker,target) then return false end
 local fighter=Fighters.Get(target); assert(fighter)
 -- Wake is not damage: no rewards, offensive procs, or friendly-fire exception.
 Fighters.WakeSleep(fighter); return true
end
function Service.Apply(caster: Model,target: Model,now: number): boolean
 if not Damage.CanDamage(caster,target) or target:FindFirstChildOfClass("ForceField") then return false end
 local kind=target:GetAttribute("EntityKind")
 if kind~="Hero" and kind~="Minion" and kind~="Summon" then return false end
 local fighter=Fighters.GetOrCreate(target); if not fighter then return false end
 Fighters.Sleep(fighter,now)
 -- Five noncombat silhouettes: no humanoids, scripts, tags, collision or targeting.
 local folder=Instance.new("Model"); folder.Name="SleepCosmetics"
 local previous=caster.Archivable; caster.Archivable=true
 for i=1,5 do
  local copy=caster:Clone()
  for _,tag in game:GetService("CollectionService"):GetTags(copy) do game:GetService("CollectionService"):RemoveTag(copy,tag) end
  for name in copy:GetAttributes() do copy:SetAttribute(name,nil) end
  for _,item in copy:GetDescendants() do
   if item:IsA("LuaSourceContainer") or item:IsA("Humanoid") or item:IsA("Tool") then item:Destroy()
   elseif item:IsA("BasePart") then item.Anchored=true; item.CanCollide=false; item.CanTouch=false; item.CanQuery=false; item.Transparency=math.max(.5,item.Transparency) end
  end
  local angle=2*math.pi*i/5
  local point=fighter.root.Position+Vector3.new(math.cos(angle),0,math.sin(angle))*7.5
  copy:PivotTo(CFrame.lookAt(point,fighter.root.Position)); copy.Parent=folder
 end
 caster.Archivable=previous; folder.Parent=workspace; cosmetics[folder]=now+3
 return true
end
function Service.Update(now: number)
 for model,deadline in cosmetics do if now>=deadline then cosmetics[model]=nil; model:Destroy() end end
end
function Service.Reset()
 for model in cosmetics do model:Destroy() end; table.clear(cosmetics)
 for _,fighter in Fighters.GetAll() do Fighters.WakeSleep(fighter) end
end
Damage.Applied.Event:Connect(function(_attacker: Model,target: Model)
 local fighter=Fighters.Get(target); if fighter then Fighters.WakeSleep(fighter) end
end)
Damage.AttackAttempt.Event:Connect(function(_attacker: Model,target: Model)
 local fighter=Fighters.Get(target); if fighter then Fighters.WakeSleep(fighter) end
end)
return Service
