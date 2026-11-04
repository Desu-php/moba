--!strict
-- Concrete server ports for KCM. NarutoAbilityService provides only mana/busy/Sage seams.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared.Abilities.NarutoKcmConfig)
local Domain=require(Shared.Abilities.NarutoKcmState).configure(Config)
local Adapter=require(Shared.Abilities.NarutoKcmAdapter)
local RangedDomain=require(Shared.Abilities.NarutoRangedState)
local Gameplay=require(Shared.Abilities.NarutoKcmGameplay)
local Kurama=require(script.Parent.NarutoKuramaService)
local Units=require(Shared.Abilities.WorldUnits)
local Stats=require(script.Parent.CharacterStatsService)
local Progression=require(script.Parent.HeroProgressionService)
local Fighters=require(script.Parent.FighterStateService)
local Damage=require(script.Parent.DamageService)
local Targets=require(script.Parent.AbilityTargetService)
local Hitboxes=require(script.Parent.HitboxService)
local Teams=require(script.Parent.TeamService)
export type Hooks={mana: (Player)->number,restoreMana: (Player,number)->(),spendMana: (Player,number)->boolean,
 busy: (Player)->boolean,sage: (Player)->(number,boolean)}
type Record={player: Player,token: Adapter.Token?,model: Model?,dash: Gameplay.DashState,hagoromo: Gameplay.Hagoromo,
 epoch: number,lastRequest: number,sageEntryBlocked: boolean}
local records: {[string]: Record}={}
local visuals: {[Adapter.Token]: Highlight}={}
local models: {[Adapter.Token]: Model}={}
local hooks: Hooks?=nil
type Runtime=typeof(Adapter.configure(Domain,{} :: Adapter.Ports,{} :: Adapter.MorphPolicy))
local runtime: Runtime?=nil
local S={}
local function round(): number local match=Teams.GetState(); return if match then match.roundId else 0 end
local function snapshot(owner: string): Adapter.Snapshot?
 local r=records[owner]; local h=hooks; if not r or not h then return nil end
 local p=r.player; local model=p.Character; local profile=Progression.Get(p)
 local fighter=if model then Fighters.Get(model) else nil
 if not model or not profile or not fighter then return nil end
 local match=Teams.GetState(); local left,aura=h.sage(p)
 if left<=0 then r.sageEntryBlocked=false end
 local live=Damage.CanAct(model)
 return {life=(model:GetAttribute("LifeId") or 0) :: number,epoch=round(),eligible=p.Parent==Players and p:GetAttribute("HeroId")=="OrangeNinja"
  and match~=nil and match.phase=="InProgress" and Teams.IsParticipant(p),
  canCast=live and not (fighter.sleep and fighter.sleep.active) and fighter.logic.mode=="Idle" and fighter.logic.nextAttackAt<=workspace:GetServerTimeNow()
   and not fighter.root.Anchored and not h.busy(p),
  context={level=profile.Level,rank=profile.Learned.KCM or 0,hagoromo=r.hagoromo.granted,alive=live,
   fullKurama=Kurama.IsActive(p),kuramaCooldown=Kurama.IsLocked(p),sageRemaining=left,sageAuraPresent=aura},
  allowed={kcm=(profile.Learned.KCM or 0)>0 and not r.sageEntryBlocked,gamakichi=(profile.Learned.Gamakichi or 0)>0,
   sage=(profile.Learned.SageMode or 0)>0,dash=true,sharing=false,fullKurama=profile.Level>=21}}
end
local function owned(token: Adapter.Token): Model?
 local model=models[token]; local p=Players:GetPlayerByUserId(tonumber(token.owner) or 0)
 if model and p and p.Character==model and model:GetAttribute("LifeId")==token.life
  and model:GetAttribute("RoundId")==token.epoch then return model end
 return nil
end
function S.Start(h: Hooks)
 if runtime then return end; hooks=h
 local ports: Adapter.Ports={now=function() return workspace:GetServerTimeNow() end,read=snapshot,
  kuramaPulse=function(token) local r=records[token.owner]; if r then Kurama.Pulse(r.player) end end,
  publish=function(token,chakra,mask,cooldownAt)
   local model=owned(token); if not model then return end
   model:SetAttribute("KuramaChakra",chakra); model:SetAttribute("KuramaChakraThreshold",900+100*Stats.Get(records[token.owner].player).Level)
   model:SetAttribute("Ready_KCM",cooldownAt)
   model:SetAttribute("KuramaFormAllowed",mask.fullKurama)
   model:SetAttribute("KcmAllowed",mask.kcm); model:SetAttribute("KcmDashReady",mask.dash)
   model:SetAttribute("KcmGamakichiAllowed",mask.gamakichi); model:SetAttribute("KcmSageAllowed",mask.sage)
  end,
  effect=function(token,kind,id)
   local model=owned(token); if not model then return end
   if kind=="Entered" then
    model:SetAttribute("KcmActive",true); model:SetAttribute("KcmCastId",id)
    local highlight=Instance.new("Highlight"); highlight.Archivable=false; highlight.Name="NarutoKcmAura"; highlight.Adornee=model
    highlight.FillColor=Color3.fromRGB(255,179,30); highlight.OutlineColor=Color3.fromRGB(255,230,110)
    highlight.FillTransparency=.8; highlight.DepthMode=Enum.HighlightDepthMode.Occluded; highlight.Parent=model; visuals[token]=highlight
   elseif kind=="Exited" then
    model:SetAttribute("KcmActive",false); model:SetAttribute("KcmCastId",nil)
    local r=records[token.owner]; if r then r.sageEntryBlocked=false end
   end
  end,
  reapplySage=function(_token) end, -- Additive owned layers remain composed; never snapshot/restart Sage.
  restoreMana=function(token,amount) local model=owned(token); if model then h.restoreMana(records[token.owner].player,amount) end end,
  revokeSharing=function(_token) end, -- Sharing branch is deliberately unavailable in snapshot.allowed.
  fault=function(token,reason) warn("KCM "..token.owner..": "..reason) end,
 }
 local policy: Adapter.MorphPolicy={enabled=true,
  apply=function(token,rank)
   local r=records[token.owner]; local model=if r then r.player.Character else nil; local m=Gameplay.modifier(rank)
   if not model or not m or model:GetAttribute("LifeId")~=token.life or round()~=token.epoch then return false end
   models[token]=model
   Stats.SetLayer(model,"NarutoKcm",{health=m.health,armor=m.armor,attack=m.attack,speed=Units.toStuds(m.speedWarcraft)})
   model:SetAttribute("RikudoActive",rank==3)
   model:SetAttribute("KcmRank",rank); model:SetAttribute("KcmPolicy",Gameplay.Policy.Id)
   return true
  end,
  remove=function(token,_rank)
   local model=models[token]
   if model then
    Stats.SetLayer(model,"NarutoKcm",nil)
    model:SetAttribute("RikudoActive",false)
    model:SetAttribute("KcmActive",false); model:SetAttribute("KcmDashReady",false); model:SetAttribute("KcmRank",0)
   end
   local visual=visuals[token]; if visual then visual:Destroy(); visuals[token]=nil end
  end,
 }
 runtime=Adapter.configure(Domain,ports,policy)
 Kurama.Start({
  chakra=function(p) local r=records[tostring(p.UserId)]; return if runtime and r and r.token then runtime.Chakra(r.token) else nil end,
  spend=function(p,amount) local r=records[tostring(p.UserId)]; return runtime~=nil and r~=nil and r.token~=nil and runtime.SpendChakra(r.token,amount) end,
  kcm=function(p) local r=records[tostring(p.UserId)]; return runtime~=nil and r~=nil and r.token~=nil and runtime.IsActive(r.token) end,
  busy=h.busy,restoreMana=h.restoreMana,
 })
end
local function record(p: Player): Record
 assert(runtime)
 local key=tostring(p.UserId); local r=records[key]
 if not r then
  local created: Record={player=p,token=nil,model=nil,dash=Gameplay.newDash(),hagoromo=Gameplay.newHagoromo(),epoch=round(),lastRequest=0,sageEntryBlocked=false}
  records[key]=created; r=created
 end
 if r.epoch~=round() then
  if r.token then runtime.Remove(r.token); models[r.token]=nil end
  r.token=nil; r.dash=Gameplay.newDash(); r.hagoromo=Gameplay.newHagoromo(); r.epoch=round(); r.lastRequest=0; r.sageEntryBlocked=false
 end
 return r
end
local function refresh(p: Player): Record?
 if not runtime then return nil end
 local r=record(p); local profile=Progression.Get(p); local model=p.Character
 local alive=model~=nil and Damage.CanAct(model)
 if profile then
  local event=Gameplay.updateHagoromo(r.hagoromo,workspace:GetServerTimeNow(),profile.Level,alive)
  if event=="Cutscene" and model then local fighter=Fighters.Get(model); if fighter then Fighters.StunSpell(fighter,1) end end
  local folder=Progression.GetFolder(p)
  if folder then folder:SetAttribute("HagoromoUnlocked",r.hagoromo.granted); folder:SetAttribute("HagoromoReadyAt",r.hagoromo.deadline or 0) end
 end
 if r.token then
  local ok=runtime.Update(r.token)
  if not ok then models[r.token]=nil; r.token=nil end
 end
 if not r.token and alive then
  local token=runtime.Bind(tostring(p.UserId))
  if token then r.token=token; r.model=model; if model then models[token]=model end; runtime.Update(token) end
 end
 if model then
  model:SetAttribute("Ready_KcmDash",r.dash.cooldownAt); model:SetAttribute("HagoromoUnlocked",r.hagoromo.granted)
 end
 return r
end
function S.RikudoGrant(p: Player,now: number): (RangedDomain.Grant?,number?)
 if Kurama.IsActive(p) or Kurama.IsLocked(p) then return nil,nil end
 local r=refresh(p);local rt=runtime
 if not rt or not r or not r.token then return nil,nil end
 local rank,castId=rt.ActiveCast(r.token);local model=owned(r.token);local profile=Progression.Get(p)
 if rank~=3 or not castId or not model or not profile or not r.hagoromo.granted
  or (profile.Learned.KCM or 0)~=3 or profile.Level<27 then return nil,nil end
 return {abilityId="",ownerId=tostring(p.UserId),round=r.token.epoch,life=r.token.life,form="Ewrd",
  kcmRank=3,heroLevel=profile.Level,hagoromo=true,expiresAt=now+.1},castId
end
function S.IsAbility(id: string): boolean return id=="KuramaForm" or id=="KCM" or id=="KcmCancel" or id=="KcmDash" or id=="KuramaConvert" end
-- A09J activation disables A017; the source KCM exit action can restore it.
-- Keep this admission action separate from independently composed stat layers.
function S.SageActivated(p: Player)
 local r=records[tostring(p.UserId)]; if r then r.sageEntryBlocked=true end
end
function S.MeditationForm(p: Player): "Ordinary" | "KCM" | "Kurama"
 if Kurama.IsActive(p) then return "Kurama" end
 local r=records[tostring(p.UserId)]
 return if runtime and r and r.token and runtime.IsActive(r.token) then "KCM" else "Ordinary"
end
function S.IsRikudo(p: Player): boolean
 local r=records[tostring(p.UserId)]
 return runtime~=nil and r~=nil and r.token~=nil and runtime.ActiveRank(r.token)==3
end
function S.OnAttackStarted(p: Player,hasTarget: boolean) Kurama.AttackStarted(p,hasTarget) end
function S.Blocked(model: Model,id: string): boolean
 local player=Players:GetPlayerFromCharacter(model)
 return player~=nil and S.MeditationForm(player)=="KCM" and id=="Gamakichi"
end
function S.TryCast(p: Player,id: string,request: number,now: number,target: any): (boolean,string)
 local r=refresh(p); local h=hooks; if not runtime or not r or not r.token or not h then return false,"Unavailable" end
 if request<=r.lastRequest then return false,"Replay" end; r.lastRequest=request
 local token=r.token; local model=p.Character; if not model then return false,"Unavailable" end
 if id=="KuramaForm" then return Kurama.TryCast(p,request,now,target)
 elseif id=="KCM" then
  if target~=nil then return false,"Malformed" end
  local ok,reason=runtime.Enter(token)
  return ok,reason
 elseif id=="KcmCancel" then
  if target~=nil then return false,"Malformed" end
  return runtime.Cancel(token,(model:GetAttribute("KcmCastId") or 0) :: number)
 elseif id=="KuramaConvert" then
  if target~=nil then return false,"Malformed" end
  return runtime.Convert(token)
 elseif id~="KcmDash" then return false,"Unsupported" end
 local snap=snapshot(tostring(p.UserId)); if not snap or not snap.canCast then return false,"Busy" end
 local fighter=Fighters.Get(model); if not fighter then return false,"Unavailable" end
 local destination: Vector3; local victim: Model?=nil
 if typeof(target)=="Vector3" then destination=target
 elseif typeof(target)=="Instance" then
  local selected=target :: Instance; if not selected:IsA("Model") then return false,"Target" end
  victim=selected; local root=selected:FindFirstChild("HumanoidRootPart")
  local kind=selected:GetAttribute("EntityKind")
  if not root or not root:IsA("BasePart") or (kind~="Hero" and kind~="Minion" and kind~="Summon")
   or not Damage.CanDamage(model,selected) or selected:FindFirstChildOfClass("ForceField") then return false,"Target" end
  destination=root.Position
 else return false,"Target" end
 if not Hitboxes.IsFiniteCFrame(CFrame.new(destination)) then return false,"Target" end
 local start=fighter.root.Position; local distance=(destination-start).Magnitude
 if distance>Units.toStuds(Gameplay.Dash.RangeWarcraft) or math.abs(destination.Y-start.Y)>12 then return false,"Range" end
 if not Targets.Visible(model,victim or model,start,destination) then return false,"Blocked" end
 if victim then
  local delta=(start-destination)*Vector3.new(1,0,1)
  if delta.Magnitude>.01 then destination+=delta.Unit*3 end
 end
 local ray=RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances={model}
 if victim then ray.FilterDescendantsInstances={model,victim} end
 ray.RespectCanCollide=true
 local ground=workspace:Raycast(destination+Vector3.new(0,6,0),Vector3.new(0,-18,0),ray)
 if not ground or ground.Normal.Y<.5 then return false,"Ground" end
 destination=Vector3.new(destination.X,ground.Position.Y+fighter.humanoid.HipHeight+fighter.root.Size.Y/2,destination.Z)
 local movement=destination-start
 if movement.Magnitude>.01 and workspace:Blockcast(fighter.root.CFrame,fighter.root.Size*.8,movement,ray) then return false,"Blocked" end
 local strength=(model:GetAttribute("Strength") or Stats.Get(p).Strength) :: number
 local ok,reason,cost,damage=Gameplay.dash(r.dash,now,request,runtime.IsActive(token),
  runtime.IsDashReady(token),h.mana(p),distance/Units.StudsPerWarcraftUnit,if victim then "Unit" else "Point",strength)
 if not ok then return false,reason end
 assert(h.spendMana(p,cost)); fighter.root.CFrame=CFrame.new(destination)*fighter.root.CFrame.Rotation
 fighter.root.AssemblyLinearVelocity=Vector3.zero
 if victim and damage then local hp=victim:FindFirstChildOfClass("Humanoid"); if hp then Damage.Apply(model,hp,damage) end end
 model:SetAttribute("Ready_KcmDash",r.dash.cooldownAt)
 return true,"Accepted"
end
function S.StudioResetCooldowns(p: Player)
 if not game:GetService("RunService"):IsStudio() then return end
 local r=records[tostring(p.UserId)]
 if r then r.dash.cooldownAt=0;if runtime and r.token then runtime.ResetCooldown(r.token) end end
end
function S.Update()
 if runtime then for _,p in Players:GetPlayers() do refresh(p) end; Kurama.Update(workspace:GetServerTimeNow()) end
end
function S.Remove(p: Player)
 assert(runtime)
 local key=tostring(p.UserId); local r=records[key]
 if r and r.token then runtime.Remove(r.token); models[r.token]=nil end
 Kurama.Remove(p); records[key]=nil
end
function S.Reset()
 Kurama.Reset()
 if runtime then runtime.Reset() end
 for _,r in records do r.token=nil; r.dash=Gameplay.newDash(); r.hagoromo=Gameplay.newHagoromo(); r.epoch=round(); r.lastRequest=0; r.sageEntryBlocked=false end
 table.clear(models); table.clear(visuals)
end
return S
