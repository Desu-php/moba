--!strict
assert(game:GetService("RunService"):IsStudio())
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local services=game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match=require(services.MatchService)
local Progression=require(services.HeroProgressionService)
local Stats=require(services.CharacterStatsService)
local Learning=require(RS.Shared.Abilities.SkillLearning)
local Rules=require(RS.Shared.Game.ProgressionRules).configure(require(RS.Shared.Config.ProgressionConfig),require(RS.Shared.Config.ItemConfig).Items)
local Ability=require(services.AbilityService)
local Naruto=require(services.NarutoAbilityService)
local Fighters=require(services.FighterStateService)
local Combat=require(services.CombatService)
local Oil=require(services.OilStatusService)
local count=0
local function check(name: string,ok: boolean) assert(ok,name); count+=1; print("[SageTests] PASS: "..name) end
local function waitFor(fn: ()->boolean,seconds: number,name: string)
 local limit=os.clock()+seconds; repeat if fn() then return end; task.wait(.02) until os.clock()>=limit; error("Timeout: "..name)
end
local ok,err=xpcall(function()
 waitFor(function() return #Players:GetPlayers()==2 and Match.GetState()~=nil end,90,"clients")
 local state=Match.GetState(); assert(state); state.phase="Preparing"; state.preparationEnds=0
 waitFor(function() return state.phase=="InProgress" end,15,"match")
 state.startedAt=workspace:GetServerTimeNow()+10000; state.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(services.JungleService).Stop(); require(RS.Shared.Config.TowerConfig).Range=0; require(services.TowerService).CancelAll()
 local a,b=table.unpack(Players:GetPlayers())
 waitFor(function() return a.Character~=nil and b.Character~=nil and Naruto.Get(a)~=nil and Naruto.Get(b)~=nil end,20,"heroes")
 local actor=a.Character :: Model; local other=b.Character :: Model
 actor:PivotTo(CFrame.new(0,36,0)); other:PivotTo(CFrame.new(12,36,-12))
 local pa,pb=Progression.Get(a),Progression.Get(b); assert(pa and pb)
 while pa.Level<6 do Progression.AddXP(a,Rules.required(pa.Level)) end
 while pb.Level<10 do Progression.AddXP(b,Rules.required(pb.Level)) end
 check("rank1 learned via existing rules",Learning.learn(pa,"SageMode")); check("rank2 first rank",Learning.learn(pb,"SageMode")); check("rank2 learned",Learning.learn(pb,"SageMode"))
 assert(Learning.learn(pa,"Rasengan")); Progression.Publish(a); Progression.Publish(b); task.wait(.2)
 local sa,sb=Naruto.Get(a),Naruto.Get(b); assert(sa and sb)
 local ha=actor:FindFirstChildOfClass("Humanoid"); local hb=other:FindFirstChildOfClass("Humanoid"); assert(ha and hb)
 for _,c in {actor,other} do local h=c:FindFirstChild("Health"); if h and h:IsA("Script") then h:Destroy() end end -- isolate explicit capacity changes from Roblox passive regeneration
 ha.Health=200; hb.Health=250
 local baseA,baseB=Stats.Get(a),Stats.Get(b)
 sa.pool.mana=500; sb.pool.mana=500
 check("rank1 real cast",Ability.HandleRequest(a,1,actor,"SageMode",state.roundId))
 check("rank1 debited25 once",math.abs(sa.pool.mana-475)<.1)
 check("rank2 real cast",Ability.HandleRequest(b,1,other,"SageMode",state.roundId))
 local ca,cb=sa.sage.active,sb.sage.active; assert(ca and cb)
 check("independent per-owner casts",ca~=cb and ca.owner~=cb.owner and ca.rank==1 and cb.rank==2)
 check("source10and7 preparation",math.abs(ca.readyAt-workspace:GetServerTimeNow()-10)<.1 and math.abs(cb.readyAt-workspace:GetServerTimeNow()-7)<.1)
 check("cooldown150 from cast",math.abs(sa.sage.cooldownAt-workspace:GetServerTimeNow()-150)<.1)
 check("preparation immobilizes",ha.WalkSpeed==0 and hb.WalkSpeed==0)
 check("no early modifiers or heal",Stats.Get(a).AttackDamageBonus==0 and ha.MaxHealth==baseA.MaxHealth and ha.Health==200)
 check("M1 rejected during preparation",Combat.HandleRequest(a,1,actor,state.roundId)=="Rejected")
 local accepted,reason=Ability.HandleRequest(a,2,actor,"Rasengan",state.roundId)
 check("other hero casts blocked during prep",not accepted and reason=="Busy")
 accepted,reason=Ability.HandleRequest(a,3,actor,"SageMode",Vector3.zero,state.roundId)
 check("forged target rejected",not accepted and reason=="Malformed")
 accepted,reason=Ability.HandleRequest(b,2,other,"SageMode",state.roundId-1)
 check("stale epoch rejected",not accepted and reason=="StaleRound")
 waitFor(function() return cb.phase=="Active" end,8,"rank2 activation")
 check("rank1 still preparing when rank2 activates",ca.phase=="Preparing" and Stats.Get(a).AttackDamageBonus==0)
 check("rank2 exact layer",Stats.Get(b).AttackDamageBonus==30 and hb.MaxHealth==baseB.MaxHealth+200 and Stats.Get(b).Defense==baseB.Defense+7)
 check("rank2 direct mana restore350",math.abs(sb.pool.mana-(475+(workspace:GetServerTimeNow()-(cb.readyAt-7))*baseB.ManaRegen+350))<2)
 waitFor(function() return ca.phase=="Active" end,4,"rank1 activation")
 check("rank1 exact layer",Stats.Get(a).AttackDamageBonus==10 and ha.MaxHealth==baseA.MaxHealth+150 and Stats.Get(a).Defense==baseA.Defense+3)
 check("capacity addition does not heal",ha.Health==200 and hb.Health==250)
 check("speed105 converted once",math.abs(ha.WalkSpeed-baseA.WalkSpeed-105/16)<.01)
 check("rank1 direct mana restore200",math.abs(sa.pool.mana-(475+(workspace:GetServerTimeNow()-(ca.readyAt-10))*baseA.ManaRegen+200))<2)
 local target=Instance.new("Model"); target.Name="SageM1Target"
 local targetRoot=Instance.new("Part"); targetRoot.Name="HumanoidRootPart"; targetRoot.Anchored=true; targetRoot.Size=Vector3.new(2,4,2); targetRoot.Parent=target
 local targetHP=Instance.new("Humanoid"); targetHP.MaxHealth=10000; targetHP.Health=10000; targetHP.Parent=target; target.PrimaryPart=targetRoot
 target:SetAttribute("TeamId",other:GetAttribute("TeamId")); target:SetAttribute("EntityKind","Minion"); target:SetAttribute("RoundId",state.roundId); target.Parent=workspace
 local root=actor:FindFirstChild("HumanoidRootPart"); assert(root and root:IsA("BasePart")); root:SetNetworkOwner(nil); root.CFrame=CFrame.new(0,36,0); targetRoot.CFrame=CFrame.new(0,36,-3)
 Fighters.GetOrCreate(target)
 local profile=require(RS.Shared.Config.CombatConfig).Profiles.OrangeNinja
 check("active Sage permits ordinary M1",Combat.HandleRequest(a,2,actor,state.roundId)=="Started")
 waitFor(function() return targetHP.Health<10000 end,2,"Sage M1")
 check("flat attack10 reaches real damage path",math.abs(10000-targetHP.Health-(profile.Damage*baseA.AttackDamageMultiplier+10))<.01)
 Fighters.Remove(target); target:Destroy()
 task.wait(.5)
 local mana=sa.pool.mana; local health=ha.MaxHealth
 Naruto.Update(workspace:GetServerTimeNow())
 check("repeated update cannot stack or refill",ha.MaxHealth==health and sa.pool.mana-mana<1)
 accepted=Ability.HandleRequest(a,4,actor,"SageMode",state.roundId)
 check("active reentry denied without debit",not accepted and sa.pool.mana>=mana and sa.pool.mana-mana<1)
 -- Exercise current permanent state while the owned layer remains active.
 pa.Owned.GuardianArmor=true; pa.Owned.SwiftBoots=true
 Progression.AddXP(a,Rules.required(pa.Level)); task.wait(.1)
 local current=Rules.stats(pa)
 check("level and items compose under Sage",ha.MaxHealth==current.MaxHealth+150 and math.abs(Stats.Get(a).WalkSpeed-current.WalkSpeed-105/16)<.01)
 Stats.SetLayer(actor,"IndependentFixture",{health=20,armor=2,attack=1,speed=1})
 Oil.Apply(actor,"FixtureOil",workspace:GetServerTimeNow())
 check("oil applies to current layered speed",math.abs(ha.WalkSpeed-(current.WalkSpeed+105/16+1)*.6)<.01)
 -- Pure tests prove 51 seconds. Advance only this test cast's expiry to avoid idle wait.
 ca.expiresAt=workspace:GetServerTimeNow()
 waitFor(function() return sa.sage.active==nil end,1,"expiry")
 check("expiry preserves latest growth items other layer",ha.MaxHealth==current.MaxHealth+20 and Stats.Get(a).AttackDamageBonus==1 and Stats.Get(a).Defense==current.Defense+2)
 check("other Sage owner unaffected",sb.sage.active==cb and Stats.Get(b).AttackDamageBonus==30)
 Oil.ClearSource("FixtureOil"); Stats.SetLayer(actor,"IndependentFixture",nil)
 check("speed restores latest permanent baseline",math.abs(ha.WalkSpeed-current.WalkSpeed)<.01)
 -- Cooldown bypass exists only in fixture state, never on the network boundary.
 sa.sage.cooldownAt=workspace:GetServerTimeNow(); task.wait(.5)
 check("new preparation for death test",Ability.HandleRequest(a,5,actor,"SageMode",state.roundId))
 local deathRoot=actor:FindFirstChild("HumanoidRootPart"); assert(deathRoot and deathRoot:IsA("BasePart")); deathRoot:SetNetworkOwner(nil); ha.Health=0
 waitFor(function() return sa.sage.active==nil end,1,"death cancellation")
 check("death cannot leave modifier or late refill",Stats.Get(a).AttackDamageBonus==0 and not game:GetService("CollectionService"):HasTag(actor,"NarutoSage"))
 waitFor(function() return a.Character~=nil and a.Character~=actor end,8,"respawn")
 local learned=Progression.Get(a); assert(learned)
 check("respawn preserves learning and committed cooldown",learned.Learned.SageMode==1 and sa.sage.cooldownAt>workspace:GetServerTimeNow() and Stats.Get(a).AttackDamageBonus==0)
 accepted=Ability.HandleRequest(a,6,actor,"SageMode",state.roundId)
 check("old life request rejected",not accepted)
 state.phase="Finished"
 waitFor(function() return sb.sage.active==nil end,1,"terminal cleanup")
 check("terminal removes owned layer and aura",Stats.Get(b).AttackDamageBonus==0 and hb.MaxHealth==baseB.MaxHealth and not game:GetService("CollectionService"):HasTag(other,"NarutoSage"))
 print("[SageTests] ALL PASS: "..count.." checks"); return "passed"
end,function(message) return debug.traceback(tostring(message),2) end)
if not ok then warn("[SageTests] FAILED after "..count..": "..tostring(err)) end
