--!strict
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Form=require(Shared.Abilities.NarutoKuramaState)
local CombatConfig=require(Shared.Config.CombatConfig)
local Avatar=require(Shared.Config.KuramaAvatarConfig)
local Units=require(Shared.Abilities.WorldUnits)
local Structures=require(Shared.Game.StructureRules)
local Stats=require(script.Parent.CharacterStatsService)
local Fighters=require(script.Parent.FighterStateService)
local Teams=require(script.Parent.TeamService)
local Damage=require(script.Parent.DamageService)
local Hitboxes=require(script.Parent.HitboxService)
export type Hooks={chakra: (Player)->number?,spend: (Player,number)->boolean,kcm: (Player)->boolean,
 busy: (Player)->boolean,restoreMana: (Player,number)->(),released: (Player)->()}
type PreviousCombat={id: string,profile: CombatConfig.AttackProfile}
type Record={state: Form.State,model: Model?,visual: Highlight?,body: BasePart?,previousCombat: PreviousCombat?,
 cleanupConnections: {RBXScriptConnection},lastRequest: number,applied: boolean}
local records: {[Player]: Record}={}
local retained: {[string]: {epoch: number,balance: Form.Balance}}={}
local hooks: Hooks?=nil
local rng=Random.new()
local summonMana: ((Model,number)->boolean)?=nil
local S={Visual=Instance.new("BindableEvent")}
local function epoch(): number local m=Teams.GetState(); return if m then m.roundId else 0 end
local function valid(p: Player,r: Record): boolean
 local model=r.model
 return p.Parent==Players and model~=nil and p.Character==model and model:GetAttribute("LifeId")==r.state.life
  and epoch()==r.state.epoch and Damage.CanAct(model)
end
local function teardown(r: Record)
 if not r.applied and not r.visual and not r.body and not r.previousCombat then return end; r.applied=false
 for _,connection in r.cleanupConnections do connection:Disconnect() end
 table.clear(r.cleanupConnections)
 if r.body then r.body:Destroy();r.body=nil end
 local model=r.model
 if model then
  model:SetAttribute("CombatBodyRadius",nil)
  local fighter=Fighters.Get(model);local previous=r.previousCombat
  if fighter and previous then Fighters.SetAttackProfile(fighter,previous.id,previous.profile) end
  Stats.SetLayer(model,"NarutoKurama",nil); Stats.SetLayer(model,"NarutoKuramaThreeHead",nil)
  model:SetAttribute("KuramaActive",false); model:SetAttribute("KuramaProcPending",false)
 end
 r.previousCombat=nil
 if r.visual then r.visual:Destroy(); r.visual=nil end
end
local function applyBody(r: Record,fighter: Fighters.Fighter)
 local model=fighter.character
 r.previousCombat={id=fighter.profileId,profile=fighter.profile}
 Fighters.SetAttackProfile(fighter,"Kurama")
 local body=Instance.new("Part");body.Name="KuramaCombatBody";body.Transparency=1;body.CastShadow=false
 body.Size=Vector3.new(Avatar.BodySize.X,Avatar.BodySize.Y,Avatar.BodySize.Z)
 body.CFrame=fighter.root.CFrame*CFrame.new(Avatar.BodyOffset.X,Avatar.BodyOffset.Y,Avatar.BodyOffset.Z)
 body.Anchored=false;body.Massless=true;body.CanCollide=true;body.CanQuery=true;body.CanTouch=false
 body.CollisionGroup="SurvivalHeroes";body:SetAttribute("HeroCosmetic",false)
 local weld=Instance.new("WeldConstraint");weld.Part0=fighter.root;weld.Part1=body;weld.Parent=body
 body.Parent=model;r.body=body
 model:SetAttribute("CombatBodyRadius",Avatar.BodyRadius)
 table.insert(r.cleanupConnections,fighter.humanoid.Died:Connect(function() teardown(r) end))
 table.insert(r.cleanupConnections,model.AncestryChanged:Connect(function()
  if not model:IsDescendantOf(workspace) then teardown(r) end
 end))
 table.insert(r.cleanupConnections,model.Destroying:Connect(function() teardown(r) end))
end
local function events(r: Record,list: {Form.Event})
 local h=hooks
 for _,e in list do
  if e.kind=="Exited" then teardown(r)
  elseif e.kind=="Released" and h and r.model then
   local p=Players:GetPlayerFromCharacter(r.model)
   if p and p.Character==r.model and r.model:GetAttribute("LifeId")==r.state.life and epoch()==r.state.epoch then h.released(p) end
  end
 end
 local model=r.model; if model then model:SetAttribute("KuramaLocked",Form.isLocked(r.state)) end
end
local function record(p: Player,now: number): Record
 local r=records[p]; local model=p.Character; local life=if model then (model:GetAttribute("LifeId") or 0) :: number else 0
 if not r then
  local owner=tostring(p.UserId); local saved=retained[owner]
  local created: Record={state=Form.new(owner,epoch(),life,now,if saved and saved.epoch==epoch() then saved.balance else nil),model=model,visual=nil,
   body=nil,previousCombat=nil,cleanupConnections={},lastRequest=0,applied=false}
  retained[owner]=nil
  r=created; records[p]=created
 elseif r.state.epoch~=epoch() or r.state.life~=life or r.model~=model then
  events(r,Form.newLife(r.state,epoch(),life,now))
  r.model=model; r.lastRequest=0
 end
 return r
end
function S.Start(h: Hooks) hooks=h end
function S.ConfigureSummonManaReceiver(receiver: (Model,number)->boolean) summonMana=receiver end
function S.IsActive(p: Player): boolean
 local r=records[p]; local c=if r then r.state.active else nil
 return r~=nil and r.applied and c~=nil and c.buff and (c.externalBuff or workspace:GetServerTimeNow()<c.expiresAt) and valid(p,r)
end
function S.IsLocked(p: Player): boolean
 local r=records[p]; local model=if r then r.model else nil
 return r~=nil and model~=nil and r.state.epoch==epoch() and model==p.Character and model:GetAttribute("LifeId")==r.state.life and Form.isLocked(r.state)
end
function S.TryCast(p: Player,request: number,now: number,target: any): (boolean,string)
 local h=hooks; if not h then return false,"Unavailable" end
 if target~=nil then return false,"Malformed" end
 local r=record(p,now); local model=p.Character; local fighter=if model then Fighters.Get(model) else nil
 if not model or not fighter or not valid(p,r) or p:GetAttribute("HeroId")~="OrangeNinja" then return false,"Unavailable" end
 if request~=request or request%1~=0 or request<1 or request==math.huge then return false,"Malformed" end
 if request<=r.lastRequest then return false,"Replay" end; r.lastRequest=request
 events(r,Form.update(r.state,now,true))
 local before=table.clone(r.state)
 local accepted,reason,cost=Form.request(r.state,now,{level=Stats.Get(p).Level,alive=true,
  canCast=fighter.logic.mode=="Idle" and fighter.logic.nextAttackAt<=now and not fighter.root.Anchored and not h.busy(p),
  kcm=h.kcm(p),chakra=h.chakra(p) or 0})
 if not accepted then return false,reason end
 -- Resource owner and policy application are synchronous; no client debit/attributes are accepted.
 if not h.spend(p,cost) then r.state=before; return false,"Chakra" end
 r.applied=true
 applyBody(r,fighter)
 local m=Form.modifier()
 Stats.SetLayer(model,"NarutoKurama",{health=m.health,armor=m.armor,attack=m.attack,speed=Units.toStuds(m.speedWarcraft)})
 model:SetAttribute("KuramaActive",true); model:SetAttribute("KuramaLocked",true)
 model:SetAttribute("KuramaCastId",r.state.serial); model:SetAttribute("KuramaExpiresAt",now+Form.Duration)
 model:SetAttribute("Ready_KuramaForm",r.state.cooldownAt); model:SetAttribute("KuramaPolicy",Form.Policy.Retention)
 local v=Instance.new("Highlight"); v.Name="NarutoKuramaAura"; v.Archivable=false; v.Adornee=model
 v.FillColor=Color3.fromRGB(255,202,70); v.OutlineColor=Color3.fromRGB(255,237,146); v.FillTransparency=1;v.OutlineTransparency=.45
 v.DepthMode=Enum.HighlightDepthMode.Occluded; v.Parent=model; r.visual=v
 return true,"Accepted"
end
-- Attack intent with an admitted target, before landed M1 damage. Structures may be initial targets.
function S.AttackStarted(p: Player,hasTarget: boolean)
 local r=records[p]; if not r or not S.IsActive(p) then return end
 local model=r.model; if not model then return end
 local root=model:FindFirstChild("HumanoidRootPart"); if not root or not root:IsA("BasePart") or not Hitboxes.IsFiniteCFrame(root.CFrame) then return end
 local at=root.Position
 if Form.attackStart(r.state,workspace:GetServerTimeNow(),rng:NextNumber(1,100),model:GetAttribute("NativeNarutoClone")==true,hasTarget,at.X,at.Y,at.Z) then
  model:SetAttribute("KuramaProcPending",true)
 end
end
-- Called on the EXISTING separate-chakra resource1s phase, after its strict threshold admission.
function S.Pulse(p: Player)
 local r=records[p]; local h=hooks; if not r or not h or not S.IsActive(p) then return end
 local model=r.model; if not model then return end
 local root=model:FindFirstChild("HumanoidRootPart"); if not root or not root:IsA("BasePart") then return end
 local receiver=summonMana
 for target,fighter in Fighters.GetAll() do
  local kind=target:GetAttribute("EntityKind")
  if not Structures.isStructure(kind) and not Teams.IsEnemy(model,target)
   and Teams.GetId(model)==Teams.GetId(target) and (fighter.root.Position-root.Position).Magnitude<=Units.toStuds(400) then
   -- Source predicate has no alive test. Roblox safety: never resurrect dead Humanoids.
   if fighter.humanoid.Health>0 then fighter.humanoid.Health=math.min(fighter.humanoid.MaxHealth,fighter.humanoid.Health+20) end
   local player=Players:GetPlayerFromCharacter(target)
   if player then h.restoreMana(player,20)
   elseif target:GetAttribute("NativeGamakichi")==true then
    local mana,maxMana=target:GetAttribute("Mana"),target:GetAttribute("MaxMana")
    if typeof(mana)=="number" and typeof(maxMana)=="number" then target:SetAttribute("Mana",math.min(maxMana,mana+20)) end
   elseif receiver then receiver(target,20) end -- Optional authoritative meditation/other-mana-owner seam, never edit presentation mana.
  end
 end
end
function S.ObserveBuff(p: Player,life: number,round: number,cast: number,present: boolean): boolean
 local r=records[p]
 if not r or r.state.life~=life or r.state.epoch~=round or not valid(p,r) then return false end
 return Form.observeBuff(r.state,cast,present)
end
function S.ObserveBuffRemoved(p: Player,life: number,round: number,cast: number): boolean
 local r=records[p]
 if not r or r.state.life~=life or r.state.epoch~=round or not valid(p,r) then return false end
 return Form.buffRemoved(r.state,cast)
end
function S.Update(now: number)
 for p in records do
  local r=record(p,now)
  local alive=valid(p,r)
  events(r,Form.update(r.state,now,alive))
  local model=r.model
  if model then model:SetAttribute("Ready_KuramaForm",r.state.cooldownAt) end
  if alive and model then
   local hp=model:FindFirstChildOfClass("Humanoid")
   local proc,amount=Form.claimProc(r.state,now,if hp then hp.MaxHealth else 0)
   if proc and amount then
    model:SetAttribute("KuramaProcPending",false)
    local center=Vector3.new(proc.x,proc.y,proc.z)
    S.Visual:Fire({kind="KuramaShockwave",character=model,center=center,radius=Units.toStuds(Form.ProcRadius),startAt=now,castId=proc.id})
    for target,fighter in Fighters.GetAll() do
     local kind=target:GetAttribute("EntityKind")
     if not Structures.isStructure(kind) and Damage.CanDamage(model,target)
      and (fighter.root.Position-center).Magnitude<=Units.toStuds(Form.ProcRadius) then Damage.Apply(model,fighter.humanoid,amount) end
    end
   end
   model:SetAttribute("Ready_KuramaForm",r.state.cooldownAt)
  end
 end
end
function S.Remove(p: Player)
 local r=records[p]; if r then
  events(r,Form.update(r.state,workspace:GetServerTimeNow(),false)); teardown(r)
  retained[tostring(p.UserId)]={epoch=r.state.epoch,balance=Form.balance(r.state)}
  records[p]=nil
 end
end
function S.StudioResetCooldowns(p: Player)
 if not game:GetService("RunService"):IsStudio() then return end
 local r=records[p];if not r then return end
 r.state.cooldownAt=0;r.state.threeHeadAt=0
 if r.state.active and not r.state.active.buff then r.state.active=nil end
 if r.model then r.model:SetAttribute("Ready_KuramaForm",0);r.model:SetAttribute("KuramaLocked",Form.isLocked(r.state)) end
end
function S.Reset()
 for p,r in records do
  local model=r.model; S.Remove(p)
  if model then model:SetAttribute("Ready_KuramaForm",0); model:SetAttribute("KuramaExpiresAt",0); model:SetAttribute("KuramaCastId",nil) end
 end
 table.clear(retained)
end
return S
