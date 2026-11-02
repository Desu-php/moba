--!strict
-- Server-owned HY/HZ transaction/world adapter. Source policies: docs/NARUTO-RANGED-RUNTIME.md.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Domain=require(Shared.Abilities.NarutoRangedState)
local Units=require(Shared.Abilities.WorldUnits)
local Kcm=require(script.Parent.NarutoKcmService)
local Fighters=require(script.Parent.FighterStateService)
local Damage=require(script.Parent.DamageService)
local Teams=require(script.Parent.TeamService)
local Hitboxes=require(script.Parent.HitboxService)
local Structures=require(Shared.Game.StructureRules)
export type Hooks={mana:(Player)->number,spend:(Player,number)->boolean,strength:(Player)->number,
 busy:(Player)->boolean,pause:(Player,number)->()}
type Presentation={key:string,origin:Vector3,target:Vector3}
type Record={state:Domain.State,model:Model,kcmCast:number?,presentations:{[number]:Presentation}}
type Ownership={model:Model,untilAt:number}
local records:{[Player]:Record}={}
local retained:{[string]:{round:number,balance:Domain.Balance}}={}
local ownership:{[BasePart]:Ownership}={}
local hooks:Hooks?=nil
local S={Visual=Instance.new("BindableEvent"),Event=Instance.new("BindableEvent")}
local function epoch():number local match=Teams.GetState();return if match then match.roundId else 0 end
local function raw(point:Vector3):Domain.Point return {x=point.X/Units.StudsPerWarcraftUnit,z=point.Z/Units.StudsPerWarcraftUnit} end
local function finish(r:Record,id:number)
 local p=r.presentations[id];if not p then return end
 r.presentations[id]=nil;S.Visual:Fire({kind="RikudoEnd",key=p.key})
end
local function cancel(r:Record)
 for _,cast in r.state.casts do Domain.cancel(r.state,cast) end
 for id in r.presentations do finish(r,id) end
 r.model:SetAttribute("RangedPreparingUntil",nil);r.model:SetAttribute("RangedCastStartedAt",nil)
end
local function bind(p:Player,now:number):Record?
 local model=p.Character;local life=if model then model:GetAttribute("LifeId") else nil
 if not model or typeof(life)~="number" then return nil end
 local r=records[p]
 if not r then
  local owner=tostring(p.UserId);local saved=retained[owner]
  local created:Record={state=Domain.new(owner,epoch(),life,now,if saved and saved.round==epoch() then saved.balance else nil),model=model,kcmCast=nil,presentations={}};records[p]=created;r=created
  retained[owner]=nil
 elseif r.model~=model or r.state.life~=life or r.state.round~=epoch() then
  cancel(r)
  if r.state.round~=epoch() then Domain.reset(r.state,epoch(),life) else Domain.newLife(r.state,epoch(),life) end
  r.model=model;r.kcmCast=nil
 end
 return r
end
function S.IsAbility(id:string):boolean return id=="RikudoHY" or id=="RikudoHZ" end
function S.Ready(p:Player):{[string]:number}
 local r=records[p];return if r then {RikudoHY=r.state.cooldowns.A0HY or 0,RikudoHZ=r.state.cooldowns.A0HZ or 0} else {}
end
function S.Busy(p:Player):boolean
 local r=records[p];if not r then return false end
 local now=workspace:GetServerTimeNow()
 for _,c in r.state.casts do if now<c.unpauseAt then return true end end
 return false
end
function S.Invalidate(p:Player) local r=records[p];if r then cancel(r) end end
function S.Remove(p:Player)
 local r=records[p];if r then
  cancel(r);retained[tostring(p.UserId)]={round=r.state.round,balance=Domain.balance(r.state)}
  Domain.close(r.state);records[p]=nil
 end
end
function S.Inspect(p:Player):Domain.State? local r=records[p];return if r then r.state else nil end
local function publish(r:Record,grant:Domain.Grant?)
 local model=r.model
 model:SetAttribute("RikudoRangedGranted",grant~=nil)
 model:SetAttribute("Ready_RikudoHY",r.state.cooldowns.A0HY or 0)
 model:SetAttribute("Ready_RikudoHZ",r.state.cooldowns.A0HZ or 0)
end
function S.TryCast(p:Player,id:string,requestId:number,now:number,target:any):(boolean,string)
 local h=hooks;local r=bind(p,now)
 if not h or not r or not S.IsAbility(id) then return false,"Unavailable" end
 local grant,kcmCast=Kcm.RikudoGrant(p,now)
 if not grant or not kcmCast then publish(r,nil);return false,"Rikudo" end
 if r.kcmCast and r.kcmCast~=kcmCast then cancel(r) end;r.kcmCast=kcmCast
 local fighter=Fighters.Get(r.model)
 if not fighter or not Damage.CanAct(r.model) or fighter.logic.mode~="Idle" or fighter.logic.nextAttackAt>now
  or (fighter.sleep and fighter.sleep.active) or fighter.root.Anchored or h.busy(p) or S.Busy(p) then return false,"Busy" end
 if typeof(target)~="Vector3" or not Hitboxes.IsFiniteCFrame(CFrame.new(target)) then return false,"Target" end
 local point=target :: Vector3;local origin=fighter.root.Position
 if (point-origin).Magnitude>Units.toStuds(Domain.RangeWarcraft) then return false,"Range" end
 local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude
 local ignored:{Instance}={};for model in Fighters.GetAll() do table.insert(ignored,model) end
 ray.FilterDescendantsInstances=ignored;ray.RespectCanCollide=true
 local ground=workspace:Raycast(point+Vector3.new(0,12,0),Vector3.new(0,-36,0),ray)
 if not ground then return false,"Ground" end
 point=Vector3.new(point.X,ground.Position.Y,point.Z)
 if (point-origin).Magnitude>Units.toStuds(Domain.RangeWarcraft) then return false,"Range" end
 local code=if id=="RikudoHY" then "A0HY" else "A0HZ"
 grant.abilityId=code
 local cast,reason,debit=Domain.request(r.state,now,requestId,code,h.mana(p),raw(origin),raw(point),grant,true)
 if not cast then publish(r,grant);return false,reason end
 assert(h.spend(p,debit),"Ranged state/debit must commit without yielding")
 local key=string.format("%s:%d:%d:%d:%d",r.state.ownerId,r.state.round,r.state.life,kcmCast,cast.id)
 local visualOrigin=origin+Vector3.new(0,1,0)
 r.presentations[cast.id]={key=key,origin=visualOrigin,target=point+Vector3.new(0,1,0)}
 r.model:SetAttribute("RangedPreparingUntil",now+1.5);r.model:SetAttribute("RangedCastStartedAt",now)
 h.pause(p,1.5);publish(r,grant)
 S.Visual:Fire({kind="RikudoStart",key=key,caster=r.model,abilityId=code,origin=visualOrigin,
  target=point+Vector3.new(0,1,0),startedAt=now,releaseAt=cast.releaseAt,life=r.state.life})
 return true,"Accepted"
end
local function allied(a:Model,b:Model):boolean
 if a==b then return true end
 local first,second=Teams.GetId(a),Teams.GetId(b)
 return first~=nil and first==second
end
local function move(model:Model,root:BasePart,center:Vector3,amount:number,now:number)
 if root.Anchored then return end
 local flat=(center-root.Position)*Vector3.new(1,0,1);if flat.Magnitude<.001 then return end
 local step=flat.Unit*(if amount>0 then math.min(amount,flat.Magnitude) else amount)
 local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude;ray.FilterDescendantsInstances={model};ray.RespectCanCollide=true
 local hit=workspace:Blockcast(root.CFrame,root.Size*.8,step,ray)
 if hit then step=step.Unit*math.max(0,math.min(step.Magnitude,hit.Distance-.03)) end
 if root:CanSetNetworkOwnership() then
  local saved=ownership[root]
  if not saved then
   saved={model=model,untilAt=now+.4};ownership[root]=saved
  end
  saved.untilAt=now+.4
  local fighter=Fighters.Get(model); if fighter then Fighters.LeaseNetworkOwnership(fighter,saved.untilAt) end
 end
 root.CFrame+=step
end
local function restore(now:number,force:boolean?)
 for root,saved in ownership do
  if force or now>=saved.untilAt or not root.Parent then
   ownership[root]=nil
   local fighter=Fighters.Get(saved.model)
   if fighter then Fighters.ReleaseNetworkOwnership(fighter) end
  end
 end
end
local function apply(p:Player,r:Record,e:Domain.Event,now:number)
 local view=r.presentations[e.id];if not view then return end
 if p.Character~=r.model or e.life~=r.state.life or e.round~=epoch() or not Damage.CanAct(r.model) then cancel(r);return end
 local center=Vector3.new(Units.toStuds(e.center.x),view.target.Y,Units.toStuds(e.center.z))
 if e.kind=="Arrived" then
  S.Visual:Fire({kind="RikudoArrived",key=view.key,position=center,at=e.at})
 elseif e.kind=="DamagePulse" or e.kind=="Motion" then
  local radius=Units.toStuds(e.radius)
  local affected=0
  for model,victim in Fighters.GetAll() do
   local flat=(victim.root.Position-center)*Vector3.new(1,0,1)
   -- Safe adaptation: absent source null groups introduce no live exclusion groups.
   if flat:Dot(flat)<=radius*radius and Damage.CanAct(model) and Domain.eligible(e.filter or "",allied(r.model,model),
    Teams.IsEnemy(r.model,model),Structures.isStructure(model:GetAttribute("EntityKind")),false) then
    if e.damage then Damage.Apply(r.model,victim.humanoid,e.damage) end
    if e.displacement and victim.humanoid.Health>0 then move(model,victim.root,center,Units.toStuds(e.displacement),now) end
    affected+=1
   end
  end
  S.Event:Fire(p,e,affected)
  if e.kind=="DamagePulse" and (e.abilityId=="A0HZ" or e.pulse%4==1 or e.pulse==58) then
   S.Visual:Fire({kind="RikudoPulse",key=view.key,radius=radius,at=e.at})
  end
 elseif e.kind=="Completed" or e.kind=="Cancelled" then finish(r,e.id);S.Event:Fire(p,e,0) end
end
function S.Update(now:number)
 local h=hooks;if not h then return end
 for _,p in Players:GetPlayers() do
  local r=bind(p,now);if not r then continue end
  local grant,castId=Kcm.RikudoGrant(p,now)
  if not grant or (r.kcmCast and r.kcmCast~=castId) or not Damage.CanAct(r.model) then cancel(r) end
  r.kcmCast=castId;publish(r,grant)
  if grant then
   local events=Domain.update(r.state,now,function():number return h.strength(p) end)
   for _,e in events do apply(p,r,e,now) end
  end
 end
 restore(now)
end
function S.Reset()
 for _,r in records do cancel(r);Domain.reset(r.state,epoch(),r.state.life);publish(r,nil);r.kcmCast=nil end
 restore(workspace:GetServerTimeNow(),true)
 table.clear(retained)
end
function S.Start(h:Hooks) assert(not hooks,"Ranged hooks already configured");hooks=h end
return S
