--!strict
-- Bounded melee-only adapter. 0.04 cadence over 3.5s is an explicit scheduling policy.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local V=require(Shared.Abilities.RasenganVariants)
local AreaRules=require(Shared.Abilities.RasenshurikenThrowRules)
local Structures=require(Shared.Game.StructureRules)
local Units=require(Shared.Abilities.WorldUnits)
local Fighters=require(script.Parent.FighterStateService)
local Damage=require(script.Parent.DamageService)
type Area={id:number,at:number,caster: Model,target: Model,nextAt: number,untilAt: number,tick: number,valid: ()->boolean,strength: ()->number}
local areas: {Area}={}
local serial=0
local Service={Visual=Instance.new("BindableEvent")}
function Service.Begin(caster: Model,target: Model,now: number,valid: ()->boolean,strength: ()->number,snapshot: number)
 if not valid() then return end
 local hp=caster:FindFirstChildOfClass("Humanoid")
 if hp then hp:TakeDamage(V.selfDamage(snapshot)) end
 if not valid() then return end
 serial-=1
 Service.Visual:Fire({kind="RasenshurikenArea",id=serial,startAt=now,source=target,position=target:GetPivot().Position,radius=Units.toStuds(300)})
 table.insert(areas,{id=serial,at=now,caster=caster,target=target,nextAt=now,untilAt=now+3.5,tick=0,valid=valid,strength=strength})
end
function Service.Update(now: number)
 for i=#areas,1,-1 do
  local area=areas[i]
  if not area.valid() or not area.target.Parent then Service.Visual:Fire({kind="RasenshurikenAreaEnd",id=area.id,position=Vector3.zero});table.remove(areas,i); continue end
  while area.nextAt<=now and area.nextAt<area.untilAt do
   local root=area.target:FindFirstChild("HumanoidRootPart"); if not root or not root:IsA("BasePart") then break end
   local center=root.Position
   local radius=Units.toStuds(AreaRules.radiusForTick(area.tick+1))
   for model,victim in Fighters.GetAll() do
    local offset=center-victim.root.Position
    if offset.Magnitude<=radius and not Structures.isStructure(model:GetAttribute("EntityKind")) and Damage.CanDamage(area.caster,model) then
     Damage.Apply(area.caster,victim.humanoid,AreaRules.pulse(area.strength()))
     local flat=offset*Vector3.new(1,0,1)
     if flat.Magnitude>.001 and not victim.root.Anchored then
      local step=flat.Unit*math.min(Units.toStuds(4),flat.Magnitude)
      local ray=RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances={model,area.caster}; ray.RespectCanCollide=true
      if not workspace:Blockcast(victim.root.CFrame,victim.root.Size,step,ray) then victim.root.CFrame+=step end
     end
    end
   end
   area.tick+=1; area.nextAt=area.at+area.tick*AreaRules.Interval
  end
  if now>=area.untilAt then table.remove(areas,i) end
 end
end
function Service.Reset() table.clear(areas) end
return Service
