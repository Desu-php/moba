--!strict
-- Autonomous combat summon: local enemies, then towers. Follow is an explicit recall.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Domain=require(Shared.Abilities.GamakichiState)
local Commands=require(Shared.Abilities.CloneCommands)
local Units=require(Shared.Abilities.WorldUnits)
local Fighters=require(script.Parent.FighterStateService)
local Damage=require(script.Parent.DamageService)
local Targets=require(script.Parent.AbilityTargetService)
local Spells=require(Shared.Abilities.GamakichiSpells)
local Oil=require(script.Parent.OilStatusService)
local Hitboxes=require(script.Parent.HitboxService)
local Navigation=require(script.Parent.CloneNavigation)
local Collision=require(script.Parent.SummonCollision)
local Autonomy=require(Shared.Abilities.CloneAutonomyPolicy)
local Appearance=require(Shared.GamakichiAppearance)
local Structures=require(script.Parent.StructureService)
type Record={autoTarget: Model?,nextScan:number,returning:boolean,recallUntil:number,manualRequest:number,owner: Player, character: Model, model: Model, root: BasePart, humanoid: Humanoid,
 state: Domain.State, cast: Domain.Cast, commands: Commands.State, commandRequest: number, nextHit: number, hitAt: number?, target: Model?, spells: Spells.State, oilTarget: Model?, oilLife: any, center: Vector3?}
local records: {[Player]: Record}={}
local Service={Visual=Instance.new("BindableEvent")}
function Service.Get(player: Player): Record? return records[player] end
function Service.Remove(player: Player)
 local r=records[player]; if not r then return end
 records[player]=nil
 Oil.ClearSource(tostring(player.UserId)..":"..tostring(r.cast.id)); Spells.cancel(r.spells)
 if r.state.active==r.cast then Domain.cancel(r.state) end
 Navigation.Remove(r.model); Fighters.Remove(r.model); r.model:Destroy()
 if r.character.Parent then r.character:SetAttribute("GamakichiCount",0); r.character:SetAttribute("GamakichiAdult",false) end
end
function Service.Reset() for player in records do Service.Remove(player) end; Oil.Reset() end
function Service.Spawn(player: Player, character: Model, state: Domain.State, cast: Domain.Cast, commands: Commands.State)
 Service.Remove(player)
 local source=character:FindFirstChild("HumanoidRootPart") :: BasePart
 local folder=workspace:FindFirstChild("HeroSummons")
 if not folder then folder=Instance.new("Folder"); folder.Name="HeroSummons"; folder.Parent=workspace end
 local model=Instance.new("Model"); model.Name="Gamakichi"
 local function part(name: string,size: Vector3,offset: Vector3,color: Color3): Part
  local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Color=color; p.Anchored=true; p.CanCollide=false; p.CanTouch=false
  p.Position=offset; p.Parent=model; if name~="HumanoidRootPart" then p.CanQuery=false; p:SetAttribute("HeroCosmetic",true) end; return p
 end
 local size=if cast.profile.adult then 1.4 else 1
 local root=part("HumanoidRootPart",Vector3.new(5,3,5)*size,Vector3.zero,Color3.fromRGB(176,78,40))
 root.Transparency=1
 Appearance.Build(model,root,cast.profile.adult)
 local hp=Instance.new("Humanoid"); hp.RequiresNeck=false; hp.BreakJointsOnDeath=false
 hp.HipHeight=0
 hp.EvaluateStateMachine=false -- Navigation owns movement; no automatic collision changes.
 hp.MaxHealth=cast.profile.health; hp.Health=cast.profile.health; hp.DisplayName=if cast.profile.adult then "Гамакичи · взрослый" else "Гамакичи"
 hp.Parent=model; model.PrimaryPart=root
 model:SetAttribute("EntityKind","Summon"); model:SetAttribute("NativeGamakichi",true); model:SetAttribute("SummonOwner",player.UserId)
 model:SetAttribute("TeamId",character:GetAttribute("TeamId")); model:SetAttribute("RoundId",character:GetAttribute("RoundId"))
 model:SetAttribute("SummonArmor",cast.profile.armor); model:SetAttribute("SummonRank",cast.rank)
 model:SetAttribute("Mana",cast.profile.mana); model:SetAttribute("MaxMana",cast.profile.mana)
 model:SetAttribute("OilImplemented",true); model:SetAttribute("ChoppingImplemented",cast.profile.adult)
 Collision.Apply(model); model.PrimaryPart=root
 Navigation.Register(model,root,hp)
 Navigation.Place(model,character,source.CFrame,Domain.Policy.SpawnOffset)
 model.Parent=folder
 records[player]={autoTarget=nil,nextScan=0,returning=false,recallUntil=0,manualRequest=0,owner=player,character=character,model=model,root=root,humanoid=hp,state=state,cast=cast,commands=commands,commandRequest=commands.lastRequest,nextHit=0,hitAt=nil,target=nil,spells=Spells.new(),oilTarget=nil,oilLife=nil,center=nil}
 Fighters.GetOrCreate(model); character:SetAttribute("GamakichiCount",1); character:SetAttribute("GamakichiAdult",cast.profile.adult); character:SetAttribute("Ready_GamakichiOil",0); character:SetAttribute("Ready_GamakichiChop",0)
end
local function publish(r: Record)
 r.character:SetAttribute("Ready_GamakichiOil",r.spells.oilReady)
 r.character:SetAttribute("Ready_GamakichiChop",r.spells.chopReady)
 r.character:SetAttribute("GamakichiAdult",r.cast.profile.adult)
 r.model:SetAttribute("Channeling",r.spells.channel~=nil)
end
local function affected(r: Record,center: Vector3,radius: number): {Model}
 local result={}
 for model,fighter in Fighters.GetAll() do
  local kind=model:GetAttribute("EntityKind")
  if (kind=="Hero" or kind=="Minion" or kind=="Summon") and Damage.CanDamage(r.model,model)
   and not model:FindFirstChildOfClass("ForceField") and (fighter.root.Position-center).Magnitude<=Units.toStuds(radius)
   and Targets.Visible(r.model,model,center+Vector3.new(0,.1,0),fighter.root.Position) then table.insert(result,model) end
 end
 return result
end
function Service.TrySpell(player: Player,id: string,request: number,now: number,target: any,automatic: boolean?): (boolean,string)
 local r=records[player]
 if not r or r.character~=player.Character or not Domain.live(r.state,r.cast,now) or not Damage.CanAct(r.character) or not Damage.CanAct(r.model) then return false,"Unavailable" end
 if not automatic then
  if request~=request or request%1~=0 or request<1 or request==math.huge then return false,"Malformed" end
  if request<=r.manualRequest then return false,"Replay" end
  r.manualRequest=request
 end
 local fighter=Fighters.Get(r.model); if not fighter or (fighter.logic.mode=="Stunned" or (fighter.sleep and fighter.sleep.active)) then return false,"Busy" end
 if not Hitboxes.IsFiniteCFrame(r.root.CFrame) then return false,"Unavailable" end
 local point: Vector3
 local selected: Model?=nil
 if id=="GamakichiOil" then
  if typeof(target)~="Instance" then return false,"Target" end
  local instance=target :: Instance
  if not instance:IsA("Model") or not Damage.CanDamage(r.model,instance) then return false,"Target" end
  selected=instance
  local root=instance:FindFirstChild("HumanoidRootPart"); local kind=instance:GetAttribute("EntityKind")
  if not root or not root:IsA("BasePart") or (kind~="Hero" and kind~="Minion" and kind~="Summon") or instance:FindFirstChildOfClass("ForceField") then return false,"Target" end
  point=root.Position
 elseif id=="GamakichiChop" and typeof(target)=="Vector3" then point=target
 else return false,"Malformed" end
 if not Hitboxes.IsFiniteCFrame(CFrame.new(point)) then return false,"Target" end
 local distance=(point-r.root.Position).Magnitude
 local range=if id=="GamakichiOil" then Spells.Oil.Range else Spells.Chopping.Range
 if distance>Units.toStuds(range) or not Targets.Visible(r.model,r.model,r.root.Position,point+Vector3.new(0,.1,0)) then return false,"Target" end
 local accepted,reason=Spells.request(r.spells,id,now,r.spells.lastRequest+1,r.cast.profile.adult,distance/Units.toStuds(Spells.Oil.ProjectileSpeed))
 if not accepted then return false,reason end
 local facing=(point-r.root.Position)*Vector3.new(1,0,1)
 if facing.Magnitude>.01 then r.model:PivotTo(CFrame.lookAt(r.root.Position,r.root.Position+facing)) end
 r.hitAt=nil; r.target=nil
 r.model:SetAttribute("SummonSpell",id);r.model:SetAttribute("SummonSpellAt",now)
 if selected then
  r.oilTarget=selected; r.oilLife=selected:GetAttribute("LifeId")
  Service.Visual:Fire({source=r.model,kind="GamakichiOil",position=r.root.Position,destination=point,duration=distance/Units.toStuds(Spells.Oil.ProjectileSpeed)})
 else r.center=point; r.model:SetAttribute("ChannelWave",0); Service.Visual:Fire({source=r.model,kind="GamakichiChannel",position=point,radius=Units.toStuds(Spells.Chopping.Radius)}) end
 publish(r); return true,"Accepted"
end
function Service.Update(now: number,delta: number)
 Oil.Update(now)
 for player,r in records do
  if player.Parent~=Players or player.Character~=r.character or not Damage.CanAct(r.character)
   or not r.model.Parent or r.humanoid.Health<=0 or not Domain.live(r.state,r.cast,now) then Service.Remove(player); continue end
  if not Navigation.Settle(r.model,r.character,delta) then Navigation.Stop(r.model);r.model:SetAttribute("SummonBehavior","Landing");continue end
  local intent=Commands.resolve(r.commands)
  if r.commandRequest~=r.commands.lastRequest then
   r.commandRequest=r.commands.lastRequest;r.hitAt=nil;r.target=nil;r.autoTarget=nil;r.nextScan=0
   r.returning=intent.mode=="Follow";r.recallUntil=now+Autonomy.RecallGrace
   if intent.mode=="Hold" or intent.mode=="Follow" then Spells.cancel(r.spells);r.oilTarget=nil;r.center=nil end
  end
  local fighter=Fighters.Get(r.model)
  if fighter and (fighter.logic.mode=="Stunned" or (fighter.sleep and fighter.sleep.active)) then Navigation.Stop(r.model); r.hitAt=nil; r.target=nil; Spells.cancel(r.spells); r.oilTarget=nil; r.center=nil; publish(r); continue end
  r.humanoid.Health=math.min(r.humanoid.MaxHealth,r.humanoid.Health+r.cast.profile.regen*delta)
  if Spells.claimOil(r.spells,now) then
   local target=r.oilTarget; r.oilTarget=nil
   if target and target:GetAttribute("LifeId")==r.oilLife and Damage.CanDamage(r.model,target) then
    local root=target:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") and Targets.Visible(r.model,target,r.root.Position,root.Position) then
     for _,victim in affected(r,root.Position,Spells.Oil.Radius) do Oil.Apply(victim,tostring(player.UserId)..":"..tostring(r.cast.id),now) end
     Service.Visual:Fire({source=r.model,kind="GamakichiOilImpact",position=root.Position,radius=Units.toStuds(Spells.Oil.Radius)})
    end
   end
  end
  local wave=Spells.claimWave(r.spells,now)
  if wave and r.center then
   local victims=affected(r,r.center,Spells.Chopping.Radius)
   local raw=Spells.waveDamage(#victims)
   for _,victim in victims do local hp=victim:FindFirstChildOfClass("Humanoid"); if hp then Damage.Apply(r.model,hp,raw) end end
   r.model:SetAttribute("ChannelWave",wave)
   Service.Visual:Fire({source=r.model,kind="GamakichiChopImpact",position=r.center,radius=Units.toStuds(Spells.Chopping.Radius),wave=wave})
  end
  publish(r)
  if r.spells.channel or r.spells.flight then Navigation.Stop(r.model); continue end
  if intent.mode=="Idle" or intent.mode=="Hold" then r.hitAt=nil;r.target=nil;r.autoTarget=nil;r.model:SetAttribute("SummonBehavior",intent.mode);Navigation.Stop(r.model);continue end
  local ownerRoot=r.character:FindFirstChild("HumanoidRootPart")
  if not ownerRoot or not ownerRoot:IsA("BasePart") then continue end
  local ownerDistance=(ownerRoot.Position-r.root.Position).Magnitude
  -- Only the explicit Follow order recalls the toad. Owner motion is not an AI goal.
  if r.returning and ownerDistance<Domain.Policy.FollowDistance+1 and now>=r.recallUntil then r.returning=false end
  local function valid(candidate:Model?,range:number,visible:boolean?):boolean
   if not candidate or not candidate.Parent or not Damage.CanDamage(r.model,candidate) or candidate:FindFirstChildOfClass("ForceField") then return false end
   local cr=candidate:FindFirstChild("HumanoidRootPart")
   return cr~=nil and cr:IsA("BasePart") and (cr.Position-r.root.Position).Magnitude<=range
    and (visible==false or Targets.Visible(r.model,candidate,r.root.Position,cr.Position))
  end
  local target:Model?=nil
  if not r.returning and intent.targetId then
   for candidate in Fighters.GetAll() do if candidate:GetAttribute("AbilityEntityId")==intent.targetId and valid(candidate,Autonomy.PursueRadius) then target=candidate;break end end
  end
  if not target and not r.returning then
   local current=r.autoTarget
   local isTower=current~=nil and current:GetAttribute("EntityKind")=="Tower"
   if not valid(current,if isTower then math.huge else Autonomy.PursueRadius,not isTower) then r.autoTarget=nil end
   if now>=r.nextScan then
    r.nextScan=now+Autonomy.ScanInterval
    -- A nearby living enemy preempts siege; never waste oil/chopping on a building.
    local unit:Model?=nil
    for _,enemy in Targets.InCone(r.model,r.root.CFrame,Autonomy.AcquireRadius,-1,false,math.huge) do
     local candidate=enemy.Parent
     if candidate and candidate:IsA("Model") and valid(candidate,Autonomy.AcquireRadius) then unit=candidate;break end
    end
    if r.autoTarget and r.autoTarget:GetAttribute("EntityKind")~="Tower" then
     -- Retain a valid unit target until it dies/leaves pursuit range.
    elseif unit then r.autoTarget=unit
    else
     local nearest:Model?=nil;local best=math.huge
     for model,tower in Structures.GetAll() do
      if tower.kind~="Tower" or not Structures.Alive(tower) or not valid(model,math.huge,false) then continue end
      local distance=(tower.root.Position-r.root.Position).Magnitude
      if distance<best or (distance==best and nearest~=nil and model.Name<nearest.Name) then nearest=model;best=distance end
     end
     r.autoTarget=nearest
    end
   end
   target=r.autoTarget
  end
  r.model:SetAttribute("SummonBehavior",if target then (if target:GetAttribute("EntityKind")=="Tower" then "Siege" else "Attack") elseif r.returning then "Return" else "Guard")
  r.model:SetAttribute("SummonTarget",if target then target.Name else "")
  if target and target:GetAttribute("EntityKind")~="Tower" and not r.hitAt then
   local tr=target:FindFirstChild("HumanoidRootPart") :: BasePart
   local distance=(tr.Position-r.root.Position).Magnitude
   local oilUntil=(target:GetAttribute("OilUntil") or 0) :: number
   if now>=r.spells.oilReady and oilUntil<=now and distance<=Units.toStuds(Spells.Oil.Range) then
    if Service.TrySpell(player,"GamakichiOil",0,now,target,true) then Navigation.Stop(r.model);continue end
   elseif r.cast.profile.adult and now>=r.spells.chopReady and distance<=Units.toStuds(Spells.Chopping.Range) then
    if Service.TrySpell(player,"GamakichiChop",0,now,tr.Position,true) then Navigation.Stop(r.model);continue end
   end
  end
  if r.hitAt and now>=r.hitAt then
   local victim=r.target; r.hitAt=nil; r.target=nil
   local root=if victim then victim:FindFirstChild("HumanoidRootPart") else nil
   if victim and root and root:IsA("BasePart") and Damage.CanDamage(r.model,victim)
    and (root.Position-r.root.Position).Magnitude<=Units.toStuds(100)+(root.Size.X+r.root.Size.X)/2
    and Targets.Visible(r.model,victim,r.root.Position,root.Position) then
    local hp=victim:FindFirstChildOfClass("Humanoid"); if hp then Damage.ApplyAttack(r.model,hp,r.cast.profile.rawDamage) end
   end
  end
  local destination=if target then target:FindFirstChild("HumanoidRootPart") elseif r.returning then ownerRoot else nil
  if not destination or not destination:IsA("BasePart") then Navigation.Stop(r.model);continue end
  local stop=if target then Units.toStuds(100)+(r.root.Size.X+destination.Size.X)/2 else Domain.Policy.FollowDistance
  local distance=destination.Position-r.root.Position
  local inRange=target~=nil and distance.Magnitude<=stop and Targets.Visible(r.model,target,r.root.Position,destination.Position)
  local function face(direction:Vector3)
   local flat=direction*Vector3.new(1,0,1)
   if flat.Magnitude>.01 then
    local desired=CFrame.lookAt(r.root.Position,r.root.Position+flat)
    r.model:PivotTo(r.root.CFrame:Lerp(desired,1-math.exp(-12*math.clamp(delta,0,.1))))
   end
  end
  if inRange and now>=r.nextHit and not r.hitAt then
   r.nextHit=now+Domain.Policy.AttackInterval;r.hitAt=now+Domain.Policy.DamagePoint;r.target=target;r.model:SetAttribute("SummonSwingAt",now)
  end
  if r.hitAt or inRange then Navigation.Stop(r.model);face(distance)
  else
   local before=r.root.Position
   local moving=Navigation.Step(r.model,r.character,target or r.character,destination,stop,now,delta,Units.toStuds(r.cast.profile.speed)*Oil.Movement(r.model,now))
   r.model:SetAttribute("SummonMoving",moving)
   if moving then face(r.root.Position-before) end
  end
 end
end
return Service
