--!strict
-- Integrator-only isolated Studio fixture. Not referenced by production project; never run by this worker.
assert(game:GetService("RunService"):IsStudio())
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Services=game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match=require(Services.MatchService)
local Progression=require(Services.HeroProgressionService)
local Stats=require(Services.CharacterStatsService)
local Naruto=require(Services.NarutoAbilityService)
local Ability=require(Services.AbilityService)
local Learning=require(RS.Shared.Abilities.SkillLearning)
local Rules=require(RS.Shared.Game.ProgressionRules).configure(require(RS.Shared.Config.ProgressionConfig),require(RS.Shared.Config.ItemConfig).Items)
local count=0
local function check(name: string,ok: boolean) assert(ok,name); count+=1; print("[KcmTests] PASS "..name) end
local function waitFor(test: ()->boolean,seconds: number,name: string)
 local untilAt=os.clock()+seconds
 repeat if test() then return end; task.wait(.02) until os.clock()>=untilAt
 error("KCM timeout "..name)
end
local ok,err=xpcall(function(): string
 waitFor(function() return #Players:GetPlayers()==2 and Match.GetState()~=nil end,90,"two clients")
 local match=Match.GetState(); assert(match); match.phase="Preparing"; match.preparationEnds=0
 waitFor(function() return match.phase=="InProgress" end,15,"match")
 match.startedAt=workspace:GetServerTimeNow()+10000; match.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(Services.JungleService).Stop(); require(RS.Shared.Config.TowerConfig).Range=0; require(Services.TowerService).CancelAll()
 local a,b=table.unpack(Players:GetPlayers())
 waitFor(function() return a.Character~=nil and b.Character~=nil and Naruto.Get(a)~=nil and Naruto.Get(b)~=nil end,20,"heroes")
 local actor=a.Character :: Model; local enemy=b.Character :: Model
 local pa,pb=Progression.Get(a),Progression.Get(b); assert(pa and pb)
 while pa.Level<13 do Progression.AddXP(a,Rules.required(pa.Level)) end
 while pb.Level<20 do Progression.AddXP(b,Rules.required(pb.Level)) end
 check("rank1 learning",Learning.learn(pa,"KCM")); check("rank2 first learning",Learning.learn(pb,"KCM")); check("rank2 learning",Learning.learn(pb,"KCM"))
 check("Sage learning",Learning.learn(pa,"SageMode"))
 for _=1,3 do assert(Learning.learn(pb,"SageMode")) end
 Progression.Publish(a); Progression.Publish(b)
 local floor=Instance.new("Part"); floor.Name="KcmQAFloor"; floor.Anchored=true; floor.Size=Vector3.new(120,2,120); floor.CFrame=CFrame.new(600,30,600); floor.Parent=workspace
 actor:PivotTo(CFrame.new(600,35,600)); enemy:PivotTo(CFrame.new(612,35,600))
 for _,model in {actor,enemy} do local shield=model:FindFirstChildOfClass("ForceField"); if shield then shield:Destroy() end end
 task.wait(.7)
 local sa,sb=Naruto.Get(a),Naruto.Get(b); assert(sa and sb); sa.pool.mana=500; sb.pool.mana=500
 local baseA,baseB=Stats.Get(a),Stats.Get(b)
 local ha=actor:FindFirstChildOfClass("Humanoid"); local hb=enemy:FindFirstChildOfClass("Humanoid"); assert(ha and hb)
 local maxMana=sa.pool.maximum; local serialA,serialB=0,0
 local function cast(p: Player,id: string,target: any): (boolean,string)
  local serial: number; local model: Model
  if p==a then serialA+=1; serial=serialA; model=actor else serialB+=1; serial=serialB; model=enemy end
  if target~=nil then return Ability.HandleRequest(p,serial,model,id,target,match.roundId) end
  return Ability.HandleRequest(p,serial,model,id,match.roundId)
 end
 local chakraA=actor:GetAttribute("KuramaChakra") :: number
 check("rank1 network cast",cast(a,"KCM",nil))
 check("entry chakra debit200",actor:GetAttribute("KuramaChakra")==chakraA-200)
 check("no mana morph rewrite",math.abs(sa.pool.mana-500)<1 and sa.pool.maximum==maxMana)
 check("rank1 retained layer",Stats.Get(a).AttackDamageBonus==baseA.AttackDamageBonus+25 and Stats.Get(a).Defense==baseA.Defense+5)
 check("rank1 health retention",ha.MaxHealth==baseA.MaxHealth)
 check("rank2 network cast",cast(b,"KCM",nil))
 check("rank2 retained layer",Stats.Get(b).AttackDamageBonus==baseB.AttackDamageBonus+50)
 check("peer SageIII preparation inside KCM",cast(b,"SageMode",nil))
 check("Gamakichi blocked in KCM",not Naruto.TryCast(a,"Gamakichi",100,workspace:GetServerTimeNow(),nil))
 waitFor(function() return actor:GetAttribute("KcmDashReady")==true end,2,"dash readiness")
 local hpBefore=hb.Health; local manaBefore=sa.pool.mana
 check("unit dash",cast(a,"KcmDash",enemy))
 check("unit dash damage",hb.Health<hpBefore)
 check("unit dash mana100",math.abs(sa.pool.mana-(manaBefore-100))<.5)
 check("dash cooldown40",(actor:GetAttribute("Ready_KcmDash") :: number)>workspace:GetServerTimeNow()+39)
 check("dash not repeatable",not cast(a,"KcmDash",enemy))
 check("Sage cast remains available during KCM",cast(a,"SageMode",nil))
 check("cancel accepted during Sage preparation",cast(a,"KcmCancel",nil))
 waitFor(function() return actor:GetAttribute("KcmActive")==false end,2,"cancel cleanup")
 check("KCM modifier removed",Stats.Get(a).AttackDamageBonus==baseA.AttackDamageBonus and Stats.Get(a).Defense==baseA.Defense)
 check("no aura orphan",actor:FindFirstChild("NarutoKcmAura")==nil)
 check("other owner unaffected",enemy:GetAttribute("KcmActive")==true)
 check("stale epoch rejected",not Ability.HandleRequest(a,1000,actor,"KCM",match.roundId-1))
 check("Sage preparation survives KCM exit",sa.sage.active~=nil)
 waitFor(function() return enemy:GetAttribute("SagePhase")=="Active" end,5,"peer SageIII activation")
 local peerSageExpiry=enemy:GetAttribute("SageExpiresAt")
 check("peer SageIII and KCM compose",enemy:GetAttribute("KcmActive")==true and Stats.Get(b).AttackDamageBonus==baseB.AttackDamageBonus+100)
 check("peer cancellation while Sage active",cast(b,"KcmCancel",nil))
 waitFor(function() return enemy:GetAttribute("KcmActive")==false end,2,"peer layered exit")
 check("peer exit preserves Sage layer and timer",Stats.Get(b).AttackDamageBonus==baseB.AttackDamageBonus+50 and enemy:GetAttribute("SageExpiresAt")==peerSageExpiry)
 waitFor(function() return actor:GetAttribute("SagePhase")=="Active" end,12,"Sage activation")
 local sageStats=Stats.Get(a); local sageExpiry=actor:GetAttribute("SageExpiresAt")
 check("Sage activated outside KCM disables entry",not cast(a,"KCM",nil))
 check("rejected entry preserves Sage stats and timer",Stats.Get(a).MaxHealth==sageStats.MaxHealth and Stats.Get(a).AttackDamageBonus==sageStats.AttackDamageBonus and actor:GetAttribute("SageExpiresAt")==sageExpiry)
 check("source KCM exit restores entry over surviving Sage",cast(b,"KCM",nil))
 check("restored layered entry preserves Sage timer",Stats.Get(b).AttackDamageBonus==baseB.AttackDamageBonus+100 and enemy:GetAttribute("SageExpiresAt")==peerSageExpiry)
 check("final layered cancel",cast(b,"KcmCancel",nil))
 waitFor(function() return enemy:GetAttribute("KcmActive")==false end,2,"final layered exit")
 check("Sage remains after final exit",Stats.Get(b).AttackDamageBonus==baseB.AttackDamageBonus+50 and enemy:GetAttribute("SageExpiresAt")==peerSageExpiry)
 print("[KcmTests] ALL PASS: "..count.." runtime checks")
 return "PASS"
end,function(message: any): string return debug.traceback(tostring(message)) end)
if not ok then warn("[KcmTests] FAILED "..tostring(err)); error(err) end
