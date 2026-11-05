--!strict
local Navigation=require(script.Parent.CloneNavigation)
local Collision=require(script.Parent.SummonCollision)
local Damage=require(script.Parent.DamageService)
local S={}
local summons:{any}={}
local poisons:{any}={}
local Fighters=require(script.Parent.FighterStateService)
local function remove(i:number) local s=summons[i];Navigation.Remove(s.model);s.model:Destroy();table.remove(summons,i) end
function S.Reset() for i=#summons,1,-1 do remove(i) end end
function S.Spawn(owner:Model,player:Player,rank:number,point:Vector3):boolean
 for i=#summons,1,-1 do if summons[i].owner==owner then remove(i) end end
 local folder=workspace:FindFirstChild("HeroSummons") or Instance.new("Folder");folder.Name="HeroSummons";folder.Parent=workspace
 local model=Instance.new("Model");model.Name="Аода";model:SetAttribute("NativeAoda",true);model:SetAttribute("EntityKind","Summon");model:SetAttribute("SummonOwner",player.UserId)
 model:SetAttribute("TeamId",owner:GetAttribute("TeamId"));model:SetAttribute("RoundId",owner:GetAttribute("RoundId"))
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Size=Vector3.new(3,4,3);root.Transparency=1;root.Anchored=true;root.Parent=model;model.PrimaryPart=root
 local h=Instance.new("Humanoid");h.MaxHealth=if rank>=6 then 1500 else 500;h.Health=h.MaxHealth;h.HipHeight=0;h.RequiresNeck=false;h.Parent=model
 local segments={}
 for i=0,11 do
  local p=Instance.new("Part");p.Name=if i==0 then "Head" else "SerpentBody";p.Shape=Enum.PartType.Ball
  local size=if i==0 then Vector3.new(3.4,2.3,4) else Vector3.new(2.6,2.6,3)*(1-i*.055)
  p.Size=size;p.Color=if i==0 then Color3.fromRGB(72,108,159) else Color3.fromRGB(65,92,133);p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.Parent=model;table.insert(segments,p)
 end
 for side=-1,1,2 do
  local eye=Instance.new("Part");eye.Name="AodaEye";eye.Shape=Enum.PartType.Ball;eye.Size=Vector3.new(.2,.4,.5);eye.Color=Color3.fromRGB(236,213,86);eye.Anchored=true;eye.Parent=model
  eye:SetAttribute("EyeSide",side)
 end
 model.Parent=folder;Collision.Apply(model);Navigation.Register(model,root,h)
 if not Navigation.Place(model,owner,CFrame.new(point),3) then Navigation.Remove(model);model:Destroy();return false end
 table.insert(summons,{model=model,root=root,h=h,owner=owner,untilAt=workspace:GetServerTimeNow()+10+5*(rank-1),rank=rank,damage=if rank>=6 then 101 else 41,attackAt=0,poisonAt=0,constrictAt=0,nextTarget=0,target=nil,segments=segments})
 return true
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
  local controlled=((s.model:GetAttribute("CombatStunUntil") or 0) :: number)>now
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
    s.attackAt=now+(if s.rank>=6 then 1.6 else 2);s.model:SetAttribute("AodaStrikeAt",now)
    local hp=target:FindFirstChildOfClass("Humanoid");if hp and not (s.channelUntil and now<s.channelUntil) then Damage.ApplyAttack(s.model,hp,s.damage) end
    if hp and target:GetAttribute("EntityKind")~="Tower" and target:GetAttribute("EntityKind")~="Core" then
     if now>=s.poisonAt then
      local adult=s.rank>=6;local duration=if adult then 15 else 7
      s.poisonAt=now+(if adult then 20 else 25)
      target:SetAttribute("SnakePoisonUntil",now+duration);target:SetAttribute("SnakePoisonMove",if adult then .9 else .95);target:SetAttribute("SnakePoisonAttack",if adult then .85 else .9);target:SetAttribute("SnakePoisonArmor",if adult then 4 else 1)
      Fighters.SetWalkSpeed(target,Fighters.GetWalkSpeed(target))
      table.insert(poisons,{source=s.model,target=target,hp=hp,next=now+1,ticks=duration,damage=if adult then 20 else 10})
     end
     if s.rank>=6 and now>=s.constrictAt then
      s.constrictAt=now+30;s.channelUntil=now+4;s.model:SetAttribute("AodaConstrictUntil",now+4)
      local fighter=Fighters.GetOrCreate(target);if fighter then Fighters.StunSpell(fighter,4) end
      table.insert(poisons,{source=s.model,target=target,hp=hp,next=now+1,ticks=4,damage=62.5})
     end
    end
   end
  else Navigation.Stop(s.model) end
  for index,p in s.segments do
   local t=index-1;local moving=s.model:GetAttribute("SummonMoving")==true
   local x=math.sin(now*(if moving then 5 else 1.5)-t*.7)*t*.12
   local strike=(s.model:GetAttribute("AodaStrikeAt") or 0) :: number;local lunge=math.sin(math.clamp((now-strike)/.7,0,1)*math.pi)*8*math.max(0,1-t/7)
   p.CFrame=s.root.CFrame*CFrame.new(x,-.7,t*1.2-2-lunge)*CFrame.Angles(0,math.sin(now*3-t*.7)*.12,0)
  end
  for _,p in s.model:GetChildren() do if p:IsA("BasePart") and p:GetAttribute("EyeSide") then p.CFrame=s.segments[1].CFrame*CFrame.new((p:GetAttribute("EyeSide") :: number)*1.6,.4,-.9) end end
 end
end
return S
