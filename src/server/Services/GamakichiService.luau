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
type Record={owner: Player, character: Model, model: Model, root: BasePart, humanoid: Humanoid,
 state: Domain.State, cast: Domain.Cast, commands: Commands.State, nextHit: number, hitAt: number?, target: Model?}
local records: {[Player]: Record}={}
local Service={}
function Service.Get(player: Player): Record? return records[player] end
function Service.Remove(player: Player)
 local r=records[player]; if not r then return end
 records[player]=nil
 if r.state.active==r.cast then Domain.cancel(r.state) end
 Fighters.Remove(r.model); r.model:Destroy()
 if r.character.Parent then r.character:SetAttribute("GamakichiCount",0) end
end
function Service.Reset() for player in records do Service.Remove(player) end end
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
 model:SetAttribute("OilImplemented",false); model:SetAttribute("ChoppingImplemented",false)
 local offset=source.CFrame.RightVector*Domain.Policy.SpawnOffset
 local ray=RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances={character}; ray.RespectCanCollide=true
 local wall=workspace:Blockcast(source.CFrame,root.Size,offset,ray)
 if wall then offset=offset.Unit*math.max(0,wall.Distance-.05) end
 model:PivotTo(source.CFrame+offset); model.Parent=folder
 records[player]={owner=player,character=character,model=model,root=root,humanoid=hp,state=state,cast=cast,commands=commands,nextHit=0,hitAt=nil,target=nil}
 Fighters.GetOrCreate(model); character:SetAttribute("GamakichiCount",1)
end
function Service.Update(now: number,delta: number)
 for player,r in records do
  if player.Parent~=Players or player.Character~=r.character or not Damage.CanAct(r.character)
   or not r.model.Parent or r.humanoid.Health<=0 or not Domain.live(r.state,r.cast,now) then Service.Remove(player); continue end
  local fighter=Fighters.Get(r.model)
  if fighter and fighter.logic.mode=="Stunned" then r.hitAt=nil; r.target=nil; continue end
  r.humanoid.Health=math.min(r.humanoid.MaxHealth,r.humanoid.Health+r.cast.profile.regen*delta)
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
    local hp=victim:FindFirstChildOfClass("Humanoid"); if hp then Damage.Apply(r.model,hp,r.cast.profile.rawDamage) end
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
   local move=flat.Unit*math.min(flat.Magnitude-horizontalStop,Units.toStuds(r.cast.profile.speed)*math.min(delta,.1))
   local ray=RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances={r.model,r.character}; ray.RespectCanCollide=true
   if not workspace:Blockcast(r.root.CFrame,r.root.Size,move,ray) then r.model:PivotTo(CFrame.lookAt(r.root.Position+move,r.root.Position+move+flat)) end
  end
 end
end
return Service
