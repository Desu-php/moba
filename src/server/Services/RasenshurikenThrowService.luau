--!strict
local Shared=game.ReplicatedStorage.Shared
local Rules=require(Shared.Abilities.RasenshurikenThrowRules)
local Units=require(Shared.Abilities.WorldUnits)
local Structures=require(Shared.Game.StructureRules)
local Damage=require(script.Parent.DamageService)
local Fighters=require(script.Parent.FighterStateService)
type Flight={id:number,source:Model,origin:Vector3,direction:Vector3,at:number,distance:number,strength:()->number,valid:()->boolean}
type Area={id:number,tick:number,source:Model,position:Vector3,at:number,nextAt:number,strength:()->number,valid:()->boolean}
local flights:{Flight}={};local areas:{Area}={};local serial=0
local S={Visual=Instance.new("BindableEvent")}
local function params(source:Model):RaycastParams
 local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Exclude;p.RespectCanCollide=true
 local excluded:{Instance}={source}
 for model in Fighters.GetAll() do table.insert(excluded,model) end
 p.FilterDescendantsInstances=excluded;return p
end
function S.Begin(source:Model,aim:Vector3,now:number,strength:()->number,valid:()->boolean):boolean
 local root=source:FindFirstChild("HumanoidRootPart")
 if not root or not root:IsA("BasePart") or not Rules.finite(aim.X) or not Rules.finite(aim.Y) or not Rules.finite(aim.Z) then return false end
 local origin=root.Position+Vector3.new(0,2,0);local delta=aim-origin
 if delta.Magnitude<.1 or #flights>=32 then return false end
 serial+=1
 local flight:Flight={id=serial,source=source,origin=origin,direction=delta.Unit,at=now+Rules.Windup,distance=0,strength=strength,valid=valid}
 table.insert(flights,flight)
 S.Visual:Fire({kind="RasenshurikenFlight",id=serial,source=source,position=origin,direction=flight.direction,releaseAt=flight.at,speed=Rules.Speed,range=Rules.Range})
 return true
end
function S.Update(now:number)
 for i=#flights,1,-1 do
  local f=flights[i]
  if not f.valid() then S.Visual:Fire({kind="RasenshurikenFlightEnd",id=f.id,position=f.origin});table.remove(flights,i);continue end
  if now<f.at then continue end
  local distance=math.min(Rules.Range,(now-f.at)*Rules.Speed)
  local from=f.origin+f.direction*f.distance;local travel=distance-f.distance
  if travel<=0 then continue end
  local ray=workspace:Spherecast(from,.8,f.direction*travel,params(f.source))
  local nearest=if ray then ray.Distance else travel+1
  local hit:Model?=nil
  for model,fighter in Fighters.GetAll() do
   if not Damage.CanDamage(f.source,model) then continue end
   local offset=fighter.root.Position-from;local along=math.clamp(offset:Dot(f.direction),0,travel)
   local radius=math.min(4,math.max(fighter.root.Size.X,fighter.root.Size.Y,fighter.root.Size.Z)*.5)+.8
   if (offset-f.direction*along).Magnitude<=radius and along<nearest then nearest=along;hit=model end
  end
  f.distance=distance
  if hit or ray or distance>=Rules.Range then
   local position=from+f.direction*math.min(travel,nearest)
   if hit then local fighter=Fighters.Get(hit);if fighter then Fighters.StunSpell(fighter,4.5) end end
   table.insert(areas,{id=f.id,tick=0,source=f.source,position=position,at=now+Rules.ImpactDelay,nextAt=now+Rules.ImpactDelay,strength=f.strength,valid=f.valid})
   S.Visual:Fire({kind="RasenshurikenDetonate",id=f.id,position=position,radius=Units.toStuds(Rules.Radius),startAt=now+Rules.ImpactDelay,duration=Rules.Duration})
   table.remove(flights,i)
  end
 end
 for i=#areas,1,-1 do
  local a=areas[i]
  if not a.valid() or now>=a.at+Rules.Duration then S.Visual:Fire({kind="RasenshurikenAreaEnd",id=a.id,position=a.position});table.remove(areas,i);continue end
  while a.nextAt<=now and a.nextAt<a.at+Rules.Duration do
   local radius=Units.toStuds(Rules.radiusForTick(a.tick+1))
   local rayParams=params(a.source)
   for model,fighter in Fighters.GetAll() do
    local delta=fighter.root.Position-a.position
    if delta.Magnitude<=radius and not Structures.isStructure(model:GetAttribute("EntityKind")) and Damage.CanDamage(a.source,model) and (delta.Magnitude<.01 or not workspace:Raycast(a.position,delta,rayParams)) then
     Damage.Apply(a.source,fighter.humanoid,Rules.pulse(a.strength()))
     local pull=-delta*Vector3.new(1,0,1)
     if pull.Magnitude>.001 and not fighter.root.Anchored then
      local step=pull.Unit*math.min(Units.toStuds(4),pull.Magnitude)
      if not workspace:Blockcast(fighter.root.CFrame,fighter.root.Size,step,rayParams) then fighter.root.CFrame+=step end
     end
    end
   end
   a.tick+=1;a.nextAt=a.at+a.tick*Rules.Interval
  end
 end
end
function S.Reset() table.clear(flights);table.clear(areas) end
return S
