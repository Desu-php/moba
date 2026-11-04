--!strict
-- Integrator-only isolated Studio fixture; source worker never launches Studio.
assert(game:GetService("RunService"):IsStudio())
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Services=game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match=require(Services.MatchService)
local Progression=require(Services.HeroProgressionService)
local Stats=require(Services.CharacterStatsService)
local Naruto=require(Services.NarutoAbilityService)
local Kurama=require(Services.NarutoKuramaService)
local Ability=require(Services.AbilityService)
local Fighters=require(Services.FighterStateService)
local Hitboxes=require(Services.HitboxService)
local CombatState=require(RS.Shared.Combat.CombatState)
local Avatar=require(RS.Shared.Config.KuramaAvatarConfig)
local Learning=require(RS.Shared.Abilities.SkillLearning)
local Rules=require(RS.Shared.Game.ProgressionRules).configure(require(RS.Shared.Config.ProgressionConfig),require(RS.Shared.Config.ItemConfig).Items)
local count=0
local function check(name: string,ok: boolean) assert(ok,name); count+=1; print("[KuramaTests] PASS "..name) end
local function waitFor(test: ()->boolean,seconds: number,name: string)
 local untilAt=os.clock()+seconds
 repeat if test() then return end; task.wait(.02) until os.clock()>=untilAt
 error("Kurama timeout "..name)
end
local ok,err=xpcall(function(): string
 waitFor(function() return #Players:GetPlayers()==2 and Match.GetState()~=nil end,90,"two clients")
 local match=Match.GetState(); assert(match); match.phase="Preparing"; match.preparationEnds=0
 waitFor(function() return match.phase=="InProgress" end,15,"match")
 match.startedAt=workspace:GetServerTimeNow()+10000; match.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(Services.JungleService).Stop(); require(RS.Shared.Config.TowerConfig).Range=0; require(Services.TowerService).CancelAll()
 local a,b=table.unpack(Players:GetPlayers())
 waitFor(function() return a.Character~=nil and b.Character~=nil and Naruto.Get(a)~=nil and Naruto.Get(b)~=nil end,20,"heroes")
 local actor=a.Character :: Model; local other=b.Character :: Model
 local pa,pb=Progression.Get(a),Progression.Get(b); assert(pa and pb)
 for _,p in {a,b} do local profile=Progression.Get(p); assert(profile); while profile.Level<21 do Progression.AddXP(p,Rules.required(profile.Level)) end; assert(Learning.learn(profile,"KCM")); Progression.Publish(p) end
 check("same five learninglines",#Learning.Order==5 and pa.Learned.KuramaForm==nil)
 local floor=Instance.new("Part"); floor.Name="KuramaQAFloor"; floor.Anchored=true; floor.Size=Vector3.new(120,2,120); floor.CFrame=CFrame.new(600,30,600); floor.Parent=workspace
 actor:PivotTo(CFrame.new(600,35,600)); other:PivotTo(CFrame.new(612,35,600))
 for _,model in {actor,other} do
  local shield=model:FindFirstChildOfClass("ForceField"); if shield then shield:Destroy() end
  local regen=model:FindFirstChild("Health"); if regen and regen:IsA("Script") then regen:Destroy() end
 end
 task.wait(.5)
 local serialA,serialB=0,0
 local function cast(p: Player,id: string): (boolean,string)
  if p==a then serialA+=1; return Ability.HandleRequest(p,serialA,actor,id,match.roundId) end
  serialB+=1; return Ability.HandleRequest(p,serialB,other,id,match.roundId)
 end
 local accepted,reason=cast(a,"KuramaForm")
 check("insufficientpool denied",not accepted and reason=="Chakra" and not Kurama.IsActive(a))
 check("failed admission no scriptCD productpolicy",(actor:GetAttribute("Ready_KuramaForm") or 0)==0)
 print("[KuramaTests] Waiting for real idle resource to2500; no production cheat setters or time overrides")
 waitFor(function() return ((actor:GetAttribute("KuramaChakra") or 0) :: number)>=2500 and ((other:GetAttribute("KuramaChakra") or 0) :: number)>=2500 end,110,"natural2500chakra")
 local sa,sb=Naruto.Get(a),Naruto.Get(b); assert(sa and sb)
 local ha=actor:FindFirstChildOfClass("Humanoid"); local hb=other:FindFirstChildOfClass("Humanoid"); assert(ha and hb)
 sa.pool.mana=100; sb.pool.mana=100; ha.Health=100; hb.Health=100
 local base=Stats.Get(a); local points=pa.SkillPoints; local pool=actor:GetAttribute("KuramaChakra") :: number
 local otherPool=other:GetAttribute("KuramaChakra")
 local fa,fb=Fighters.Get(actor),Fighters.Get(other);assert(fa and fb)
 local priorA,priorB=fa.profile,fb.profile;local priorIdA,priorIdB=fa.profileId,fb.profileId
 check("real A01F-like admission",cast(a,"KuramaForm"))
 check("form uses authoritative combat profile",fa.profileId=="Kurama" and actor:GetAttribute("CombatProfileId")=="Kurama")
 local body=actor:FindFirstChild("KuramaCombatBody");assert(body and body:IsA("BasePart"))
 check("giant has solid queryable noncosmetic body",body.CanCollide and body.CanQuery and body.Massless and body.Transparency==1 and body:GetAttribute("HeroCosmetic")==false and body.CollisionGroup=="SurvivalHeroes")
 check("body is grounded independently from cosmetic scale",body.Size==Vector3.new(Avatar.BodySize.X,Avatar.BodySize.Y,Avatar.BodySize.Z) and actor:GetAttribute("CombatBodyRadius")==Avatar.BodyRadius)
 local savedOther=other:GetPivot()
 local side=fa.root.Position+Vector3.new(9,0,0)
 other:PivotTo(CFrame.lookAt(side,fa.root.Position))
 check("normal melee can hit giant flank beyond root range",table.find(Hitboxes.GetTargets(other,fb.root,priorB),ha)~=nil)
 local wall=Instance.new("Part");wall.Anchored=true;wall.Size=Vector3.new(.5,20,20);wall.CFrame=CFrame.new(fa.root.Position+Vector3.new(7,0,0));wall.Parent=workspace
 check("giant flank still respects wall",table.find(Hitboxes.GetTargets(other,fb.root,priorB),ha)==nil)
 wall:Destroy()
 local shield=Instance.new("ForceField");shield.Parent=actor
 check("giant flank still respects forcefield",table.find(Hitboxes.GetTargets(other,fb.root,priorB),ha)==nil)
 shield:Destroy();other:PivotTo(savedOther)
 check("exact2500 debit",actor:GetAttribute("KuramaChakra")==pool-2500)
 check("no crossowner debit",other:GetAttribute("KuramaChakra")==otherPool)
 check("no skillpoint purchase",pa.SkillPoints==points)
 check("Ewar retained layer",ha.MaxHealth==base.MaxHealth+2500 and Stats.Get(a).Defense==base.Defense+20 and Stats.Get(a).AttackDamageBonus==base.AttackDamageBonus+90)
 check("capacity does not heal",ha.Health==100)
 check("ordinarymaxmana retained",sa.pool.maximum==base.MaxMana and sa.pool.mana<101)
 check("source30s not25",math.abs((actor:GetAttribute("KuramaExpiresAt") :: number)-workspace:GetServerTimeNow()-30)<.2)
 check("meditation gets Kurama",require(Services.NarutoKcmService).MeditationForm(a)=="Kurama")
 check("KCM blocked byfullform",not cast(a,"KCM"))
 check("second owner independentform",cast(b,"KuramaForm") and Kurama.IsActive(a) and Kurama.IsActive(b))
 waitFor(function() return ha.Health>=120 end,2,"passive20HP")
 check("passive ordinarymana",sa.pool.mana>=120)
 local id=other:GetAttribute("KuramaCastId") :: number
 local life=other:GetAttribute("LifeId") :: number
 check("stale buff report denied",not Kurama.ObserveBuffRemoved(b,life,match.roundId,id+1))
 local swingAt=workspace:GetServerTimeNow()
 check("unfinished giant swing staged",CombatState.Request(fb.logic,fb.profile,swingAt,999)=="Started")
 fb.logic.buffered={requestId=1000,dueAt=fb.logic.nextAttackAt,expiresAt=fb.logic.nextAttackAt+.12}
 local swingDeadline=fb.logic.nextAttackAt
 check("correct buff report",Kurama.ObserveBuffRemoved(b,life,match.roundId,id))
 Kurama.Update(swingAt)
 waitFor(function() return not Kurama.IsActive(b) and other:GetAttribute("KuramaActive")==false end,2,"early removal")
 check("exit restores exact previous profile",fb.profileId==priorIdB and fb.profile==priorB)
 check("exit cancels pending swing and buffer without resetting cooldown",fb.logic.active==nil and fb.logic.buffered==nil and fb.logic.nextAttackAt==swingDeadline)
 check("early exit removes physical body and radius",other:FindFirstChild("KuramaCombatBody")==nil and other:GetAttribute("CombatBodyRadius")==nil)
 waitFor(function() return workspace:GetServerTimeNow()>=swingDeadline end,3,"preserved attack cooldown")
 accepted,reason=cast(b,"KCM"); check("script25wait independent ofbuff",not accepted and reason=="KuramaLocked")
 check("other owner's nativeform unaffected",Kurama.IsActive(a))
 waitFor(function() return not Kurama.IsActive(a) and actor:GetAttribute("KuramaActive")==false end,31,"native30expiry")
 check("formlayer removed retained stats",Stats.Get(a).MaxHealth==base.MaxHealth and Stats.Get(a).AttackDamageBonus==base.AttackDamageBonus)
 check("no aura orphan",actor:FindFirstChild("NarutoKuramaAura")==nil)
 check("expiry restores exact profile and body",fa.profile==priorA and fa.profileId==priorIdA and actor:FindFirstChild("KuramaCombatBody")==nil and actor:GetAttribute("CombatBodyRadius")==nil)
 check("scriptlock released",not Kurama.IsLocked(a) and not Kurama.IsLocked(b))
 accepted,reason=cast(a,"KuramaForm"); check("CD160 outlives form",not accepted and reason=="Cooldown")
 check("KCM restored after earlybuff cleanup25plus",cast(b,"KCM"))
 check("Hagoromo not activeRikudo",other:GetAttribute("RikudoActive")==false)
 print("[KuramaTests] ALL PASS: "..count.." runtime checks (proc roll/arithmetic covered deterministically by CLI)")
 return "PASS"
end,function(message: any): string return debug.traceback(tostring(message)) end)
if not ok then warn("[KuramaTests] FAILED "..tostring(err)); error(err) end
