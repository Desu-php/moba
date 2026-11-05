--!strict
local Navigation=require(script.Parent.CloneNavigation)
local Collision=require(script.Parent.SummonCollision)
local Damage=require(script.Parent.DamageService)
local Appearance=require(game.ReplicatedStorage.Shared.AodaAppearance)
local S={}
local summons:{any}={}
local poisons:{any}={}
local Fighters=require(script.Parent.FighterStateService)
local Teams=require(script.Parent.TeamService)
local function release(s:any)
 Damage.ClearAodaGuard(s.model);s.channel=nil;s.model:SetAttribute("AodaConstrictUntil",0);s.model:SetAttribute("AodaGuardUntil",0)
end
local function remove(i:number) local s=summons[i];release(s);Navigation.Remove(s.model);s.model:Destroy();table.remove(summons,i) end
function S.Reset() for i=#summons,1,-1 do remove(i) end;table.clear(poisons) end
function S.Get(owner:Model):any
 for _,s in summons do if s.owner==owner then return s end end
 return nil
end
function S.Command(owner:Model,target:Model,now:number):(boolean,string)
 local s=S.Get(owner);if not s or not Damage.CanAct(s.model) or s.rank<6 then return false,"Нужна взрослая Аода" end
 local tr=target:FindFirstChild("HumanoidRootPart");local h=target:FindFirstChildOfClass("Humanoid")
 local kind=target:GetAttribute("EntityKind")
 if target==s.model or not tr or not tr:IsA("BasePart") or not h or not Damage.CanAct(target) or target:FindFirstChildOfClass("ForceField")
  or kind=="Tower" or kind=="Core" or kind=="Structure" then return false,"Выберите бойца" end
 local allied=Teams.GetId(owner)~=nil and Teams.GetId(owner)==Teams.GetId(target)
 if not allied and not Damage.CanDamage(s.model,target) then return false,"Недоступная цель" end
 if (tr.Position-s.root.Position).Magnitude>300/16 then return false,"Цель слишком далеко от Аоды" end
 if now<s.constrictAt or s.channel then return false,"Удушение/защита восстанавливается" end
 if ((s.model:GetAttribute("CombatStunUntil") or 0) :: number)>now or ((s.model:GetAttribute("SleepUntil") or 0) :: number)>now then return false,"Аода под контролем" end
 local ray=RaycastParams.new();ray.FilterDescendantsInstances={s.model,owner,target};ray.RespectCanCollide=true
 if workspace:Raycast(s.root.Position,tr.Position-s.root.Position,ray) then return false,"Путь Аоды перекрыт" end
 s.pendingBite=nil;s.model:SetAttribute("AodaStrikeAt",-100);s.constrictAt=now+30;s.channel={target=target,life=target:GetAttribute("LifeId"),untilAt=now+3,next=now+1,ticks=0,allied=allied}
 s.model:SetAttribute("Ready_AodaBind",s.constrictAt);owner:SetAttribute("Ready_AodaBind",s.constrictAt);owner:SetAttribute("Ready_AodaGuardSelf",s.constrictAt)
 Navigation.Stop(s.model);s.model:SetAttribute("SummonMoving",false);s.model:SetAttribute("AodaConstrictUntil",now+3)
 if allied then Damage.SetAodaGuard(target,s.model,now+3);s.model:SetAttribute("AodaGuardUntil",now+3)
 else local f=Fighters.GetOrCreate(target);if f then Fighters.StunSpell(f,4) end end
 return true,"Cast"
end
function S.Spawn(owner:Model,player:Player,rank:number,point:Vector3):boolean
 for i=#summons,1,-1 do if summons[i].owner==owner then remove(i) end end
 local folder=workspace:FindFirstChild("HeroSummons") or Instance.new("Folder");folder.Name="HeroSummons";folder.Parent=workspace
 local model=Instance.new("Model");model.Name="Аода";model:SetAttribute("NativeAoda",true);model:SetAttribute("EntityKind","Summon");model:SetAttribute("SummonOwner",player.UserId)
 model:SetAttribute("TeamId",owner:GetAttribute("TeamId"));model:SetAttribute("RoundId",owner:GetAttribute("RoundId"))
 model:SetAttribute("SummonArmor",if rank>=6 then 15 else 10)
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Size=Vector3.new(3,4,3);root.Transparency=1;root.Anchored=true;root.Parent=model;model.PrimaryPart=root
 local h=Instance.new("Humanoid");h.MaxHealth=if rank>=6 then 1500 else 500;h.Health=h.MaxHealth;h.HipHeight=0;h.RequiresNeck=false;h.Parent=model
 Appearance.Build(model,root,rank>=6)
 model.Parent=folder;Collision.Apply(model);Navigation.Register(model,root,h)
 if not Navigation.Place(model,owner,CFrame.new(point),3) then Navigation.Remove(model);model:Destroy();return false end
 table.insert(summons,{model=model,root=root,h=h,owner=owner,untilAt=workspace:GetServerTimeNow()+10+5*(rank-1),rank=rank,damage=if rank>=6 then 101 else 41,attackAt=0,poisonAt=0,constrictAt=0,nextTarget=0,target=nil})
 return true
end
local function impact(s:any,now:number)
 local bite=s.pendingBite;if not bite or now<bite.impactAt then return end
 s.pendingBite=nil
 local target=bite.target;local tr=target:FindFirstChild("HumanoidRootPart")
 if not tr or not tr:IsA("BasePart") or target:GetAttribute("LifeId")~=bite.life or not Damage.CanDamage(s.model,target) then return end
 local delta=tr.Position-s.root.Position
 if (delta*Vector3.new(1,0,1)).Magnitude>230/16 or math.abs(delta.Y)>=5 then return end
 local ray=RaycastParams.new();ray.FilterDescendantsInstances={s.model,s.owner,target};ray.RespectCanCollide=true
 if workspace:Raycast(s.root.Position,delta,ray) then return end
 local hp=target:FindFirstChildOfClass("Humanoid");if hp then Damage.ApplyAttack(s.model,hp,s.damage) end
    if hp and target:GetAttribute("EntityKind")~="Tower" and target:GetAttribute("EntityKind")~="Core" then
     if now>=s.poisonAt then
      local adult=s.rank>=6;local duration=if adult then 15 else 7
      s.poisonAt=now+(if adult then 20 else 25)
      target:SetAttribute("SnakePoisonUntil",now+duration);target:SetAttribute("SnakePoisonMove",if adult then .9 else .95);target:SetAttribute("SnakePoisonAttack",if adult then .85 else .9);target:SetAttribute("SnakePoisonArmor",if adult then 4 else 1)
      Fighters.SetWalkSpeed(target,Fighters.GetWalkSpeed(target))
      table.insert(poisons,{source=s.model,target=target,hp=hp,next=now+1,ticks=duration,damage=if adult then 20 else 10})
     end
    end
end
function S.Update(now:number,dt:number)
 for i=#poisons,1,-1 do local poison=poisons[i]
  if poison.ticks<=0 or not Damage.CanDamage(poison.source,poison.target) then
   if poison.target.Parent and ((poison.target:GetAttribute("SnakePoisonUntil") or 0) :: number)<=now then Fighters.SetWalkSpeed(poison.target,Fighters.GetWalkSpeed(poison.target)) end
   table.remove(poisons,i)
  elseif now>=poison.next then poison.next+=1;poison.ticks-=1;Damage.Apply(poison.source,poison.hp,poison.damage) end
 end
 for i=#summons,1,-1 do local s=summons[i]
  if not s.owner.Parent or not Damage.CanAct(s.owner) or not s.model.Parent or s.h.Health<=0 or now>=s.untilAt then remove(i);continue end
  Navigation.Settle(s.model,s.owner,dt)
  local controlled=((s.model:GetAttribute("CombatStunUntil") or 0) :: number)>now or ((s.model:GetAttribute("SleepUntil") or 0) :: number)>now
  if controlled or s.channel then s.pendingBite=nil else impact(s,now) end
  local channel=s.channel
  if channel then
   local target=channel.target;local tr=target:FindFirstChild("HumanoidRootPart")
   if controlled or not tr or not tr:IsA("BasePart") or not Damage.CanAct(target) or target:GetAttribute("LifeId")~=channel.life
    or (channel.allied and Teams.GetId(target)~=Teams.GetId(s.owner)) or (not channel.allied and not Damage.CanDamage(s.model,target)) then release(s)
   else
    s.model:PivotTo(CFrame.new(tr.Position)*s.root.CFrame.Rotation)
    while not channel.allied and channel.ticks<5 and now+1e-5>=channel.next do
     channel.next+=.5;channel.ticks+=1;local hp=target:FindFirstChildOfClass("Humanoid");if hp then Damage.Apply(s.model,hp,50) end
    end
    if now>=channel.untilAt then release(s) end
   end
  end
  if not s.channel then
  if now>=s.nextTarget then
   s.nextTarget=now+.5;local best:Model?=nil;local score=math.huge
   for _,item in workspace:GetDescendants() do if item:IsA("Humanoid") and item.Parent and item.Parent:IsA("Model") then
    local target=item.Parent;local tr=target:FindFirstChild("HumanoidRootPart")
    if tr and tr:IsA("BasePart") and Damage.CanDamage(s.model,target) then
     local distance=(tr.Position-s.root.Position).Magnitude;local priority=distance+(if target:GetAttribute("EntityKind")=="Tower" then 60 else 0)
     if distance<120 and priority<score then best=target;score=priority end
    end
   end end;s.target=best
  end
  local target=s.target;local tr=if target then target:FindFirstChild("HumanoidRootPart") else nil
  if target and tr and tr:IsA("BasePart") and Damage.CanDamage(s.model,target) then
   Navigation.SetFrontline(s.model,target,true)
   local moving=if controlled or (s.channelUntil and s.channelUntil>now) then false else Navigation.Step(s.model,s.owner,target,tr,230/16,now,dt,if s.rank>=6 then 420/16 else 330/16)
   s.model:SetAttribute("SummonMoving",moving)
   local delta=(tr.Position-s.root.Position)*Vector3.new(1,0,1)
   if delta.Magnitude>.01 then s.model:PivotTo(CFrame.lookAt(s.root.Position,s.root.Position+delta)) end
   local ray=RaycastParams.new();ray.FilterDescendantsInstances={s.model,s.owner,target};ray.RespectCanCollide=true
   if not controlled and delta.Magnitude<=230/16 and math.abs(tr.Position.Y-s.root.Position.Y)<5 and not workspace:Raycast(s.root.Position,tr.Position-s.root.Position,ray) and now>=s.attackAt then
    s.attackAt=now+(if s.rank>=6 then 1.6 else 2);s.model:SetAttribute("AodaStrikeDistance",delta.Magnitude);s.model:SetAttribute("AodaStrikeAt",now)
    s.pendingBite={target=target,life=target:GetAttribute("LifeId"),impactAt=now+.22}

   end
  else Navigation.Stop(s.model);s.model:SetAttribute("SummonMoving",false) end
  end
 end
end
return S
