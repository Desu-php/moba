--!strict
-- Roblox entity/geometry adapter. Follow/assist + shared F command is our PC control policy.
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
type Record={owner: Player, character: Model, model: Model, root: BasePart, humanoid: Humanoid,
 state: Domain.State, cast: Domain.Cast, commands: Commands.State, nextHit: number, hitAt: number?, target: Model?, spells: Spells.State, oilTarget: Model?, oilLife: any, center: Vector3?}
local records: {[Player]: Record}={}
local Service={Visual=Instance.new("BindableEvent")}
function Service.Get(player: Player): Record? return records[player] end
function Service.Remove(player: Player)
 local r=records[player]; if not r then return end
 records[player]=nil
 Oil.ClearSource(tostring(player.UserId)..":"..tostring(r.cast.id)); Spells.cancel(r.spells)
 if r.state.active==r.cast then Domain.cancel(r.state) end
 Fighters.Remove(r.model); r.model:Destroy()
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
 local head=part("Head",Vector3.new(4,2,3)*size,Vector3.new(0,1.5,-1)*size,Color3.fromRGB(200,109,57))
 part("LeftEye",Vector3.new(.7,.7,.7)*size,Vector3.new(-1.3,2.4,-2.2)*size,Color3.fromRGB(234,211,90))
 part("RightEye",Vector3.new(.7,.7,.7)*size,Vector3.new(1.3,2.4,-2.2)*size,Color3.fromRGB(234,211,90))
 head.CanQuery=false
 local hp=Instance.new("Humanoid"); hp.RequiresNeck=false; hp.BreakJointsOnDeath=false
 hp.MaxHealth=cast.profile.health; hp.Health=cast.profile.health; hp.DisplayName=if cast.profile.adult then "Гамакичи · взрослый" else "Гамакичи"
 hp.Parent=model; model.PrimaryPart=root
 model:SetAttribute("EntityKind","Summon"); model:SetAttribute("NativeGamakichi",true); model:SetAttribute("SummonOwner",player.UserId)
 model:SetAttribute("TeamId",character:GetAttribute("TeamId")); model:SetAttribute("RoundId",character:GetAttribute("RoundId"))
 model:SetAttribute("SummonArmor",cast.profile.armor); model:SetAttribute("SummonRank",cast.rank)
 model:SetAttribute("Mana",cast.profile.mana); model:SetAttribute("MaxMana",cast.profile.mana)
 model:SetAttribute("OilImplemented",true); model:SetAttribute("ChoppingImplemented",cast.profile.adult)
 local offset=source.CFrame.RightVector*Domain.Policy.SpawnOffset
 local ray=RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances={character}; ray.RespectCanCollide=true
 local wall=workspace:Blockcast(source.CFrame,root.Size,offset,ray)
 if wall then offset=offset.Unit*math.max(0,wall.Distance-.05) end
 model:PivotTo(source.CFrame+offset); model.Parent=folder
 records[player]={owner=player,character=character,model=model,root=root,humanoid=hp,state=state,cast=cast,commands=commands,nextHit=0,hitAt=nil,target=nil,spells=Spells.new(),oilTarget=nil,oilLife=nil,center=nil}
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
function Service.TrySpell(player: Player,id: string,request: number,now: number,target: any): (boolean,string)
 local r=records[player]
 if not r or r.character~=player.Character or not Domain.live(r.state,r.cast,now) or not Damage.CanAct(r.character) or not Damage.CanAct(r.model) then return false,"Unavailable" end
 local fighter=Fighters.Get(r.model); if not fighter or fighter.logic.mode=="Stunned" then return false,"Busy" end
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
 local accepted,reason=Spells.request(r.spells,id,now,request,r.cast.profile.adult,distance/Units.toStuds(Spells.Oil.ProjectileSpeed))
 if not accepted then return false,reason end
 r.hitAt=nil; r.target=nil
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
  local fighter=Fighters.Get(r.model)
  if fighter and fighter.logic.mode=="Stunned" then r.hitAt=nil; r.target=nil; Spells.cancel(r.spells); r.oilTarget=nil; r.center=nil; publish(r); continue end
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
  if r.spells.channel or r.spells.flight then continue end
  local intent=Commands.resolve(r.commands)
  local target: Model?=nil
  if intent.targetId then
   for candidate in Fighters.GetAll() do if candidate:GetAttribute("AbilityEntityId")==intent.targetId then target=candidate; break end end
   if not target or not Damage.CanDamage(r.model,target) then target=nil end
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
  local destination=if target then target:FindFirstChild("HumanoidRootPart") else r.character:FindFirstChild("HumanoidRootPart")
  if not destination or not destination:IsA("BasePart") or intent.mode=="Idle" then continue end
  local distance=destination.Position-r.root.Position; local flat=distance*Vector3.new(1,0,1)
  local stop=if target then Units.toStuds(100)+(r.root.Size.X+destination.Size.X)/2 else Domain.Policy.FollowDistance
  if target and distance.Magnitude<=stop and now>=r.nextHit and not r.hitAt and Targets.Visible(r.model,target,r.root.Position,destination.Position) then
   r.nextHit=now+Domain.Policy.AttackInterval; r.hitAt=now+Domain.Policy.DamagePoint; r.target=target; r.model:SetAttribute("SummonSwingAt",now)
  end
  local horizontalStop=math.sqrt(math.max(0,stop*stop-distance.Y*distance.Y))
  if flat.Magnitude>horizontalStop+.001 and not r.hitAt then
   local move=flat.Unit*math.min(flat.Magnitude-horizontalStop,Units.toStuds(r.cast.profile.speed)*math.min(delta,.1)*Oil.Movement(r.model,now))
   local ray=RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances={r.model,r.character}; ray.RespectCanCollide=true
   if not workspace:Blockcast(r.root.CFrame,r.root.Size,move,ray) then r.model:PivotTo(CFrame.lookAt(r.root.Position+move,r.root.Position+move+flat)) end
  end
 end
end
return Service
