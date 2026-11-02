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
local Clones=require(services.MeditationCloneService)
local Damage=require(services.DamageService)
local Sage=require(RS.Shared.Abilities.SageState)
local count=0
local function check(name: string,ok: boolean) assert(ok,name); count+=1; print("[MeditationTests] PASS: "..name) end
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
 actor:PivotTo(CFrame.new(0,36,0)); other:PivotTo(CFrame.new(60,36,0))
 for _,player in {a,b} do
  local profile=Progression.Get(player); assert(profile)
  while profile.Level<18 do Progression.AddXP(player,Rules.required(profile.Level)) end
  for _=1,3 do assert(Learning.learn(profile,"SageMode")) end
  Progression.Publish(player)
 end
 Naruto.ConfigureMeditationForms(function(player) return if player==b then "KCM" else "Ordinary" end)
 local sa,sb=Naruto.Get(a),Naruto.Get(b); assert(sa and sb)
 sa.pool.mana=100; sb.pool.mana=100
 local base=Stats.Get(a)
 check("toggle admitted through actual remote boundary",Ability.HandleRequest(a,1,actor,"MeditationToggle",state.roundId))
 check("second owner toggle",Ability.HandleRequest(b,1,other,"MeditationToggle",state.roundId))
 check("rankIII meditation cast",Ability.HandleRequest(a,2,actor,"SageMode",state.roundId))
 check("KCM seam meditation cast",Ability.HandleRequest(b,2,other,"SageMode",state.roundId))
 local cast=sa.sage.active; assert(cast)
 check("III preparation4 debit25",math.abs(cast.readyAt-workspace:GetServerTimeNow()-4)<.2 and math.abs(sa.pool.mana-75)<1)
 waitFor(function() return next(sa.meditation.clones)~=nil and next(sb.meditation.clones)~=nil end,1,"clone spawn")
 local owned: {Model}={}; local foreign: Model?=nil
 for model,record in Clones.GetAll() do
  if record.owner==a then table.insert(owned,model) else foreign=model end
  check("clone HP1 and stationary",record.humanoid.MaxHealth==1 and record.humanoid.Health==1 and record.humanoid.WalkSpeed==0)
  check("not combat clone and no inherited Sage layer",model:GetAttribute("NativeNarutoClone")~=true and model:GetAttribute("SagePhase")==nil)
 end
 check("normal18 two KCM18 one",#owned==2 and foreign~=nil)
 waitFor(function() return cast.phase=="Active" end,5,"activation")
 check("meditation no direct500 refill",sa.pool.mana<90)
 check("rankIII exact attack armor and explicit HP policy",Stats.Get(a).AttackDamageBonus==50 and Stats.Get(a).Defense==base.Defense+15 and Stats.Get(a).MaxHealth==base.MaxHealth+Sage.Policy.Health[3])
 local first=Clones.GetAll()[owned[1]]; assert(first)
 check("mana accumulated over preparation",first.clone.mana>60 and first.clone.mana<120)
 first.clone.mana=123; first.clone.regen=0
 local beforeA,beforeB=sa.pool.mana,sb.pool.mana
 check("enemy can kill meditation entity",Damage.Apply(other,first.humanoid,1)>0)
 waitFor(function() return Clones.GetAll()[owned[1]]==nil end,1,"death transfer")
 check("current123 credited correct owner once",math.abs(sa.pool.mana-beforeA-123)<2 and sb.pool.mana-beforeB<2)
 Clones.Update(workspace:GetServerTimeNow())
 check("repeat cleanup cannot credit again",math.abs(sa.pool.mana-beforeA-123)<2)
 local second=Clones.GetAll()[owned[2]]; assert(second)
 second.clone.mana=87; second.clone.regen=0; second.clone.expiresAt=workspace:GetServerTimeNow()
 beforeA=sa.pool.mana; Clones.Update(workspace:GetServerTimeNow())
 check("expiration returns current87",math.abs(sa.pool.mana-beforeA-87)<2 and Clones.GetAll()[owned[2]]==nil)
 check("other owner clone untouched",foreign~=nil and Clones.GetAll()[foreign :: Model]~=nil)
 check("recall actual request",Ability.HandleRequest(b,3,other,"MeditationRecall",state.roundId))
 check("recall clears only that owner",next(sb.meditation.clones)==nil and next(Clones.GetAll())==nil)
 -- Exercise direct III with current profile, fixture-only cooldown/expiry adjustments.
 cast.expiresAt=workspace:GetServerTimeNow(); Naruto.Update(workspace:GetServerTimeNow())
 sa.sage.cooldownAt=0; sa.pool.mana=100
 check("toggle back direct",Ability.HandleRequest(a,3,actor,"MeditationToggle",state.roundId))
 task.wait(.4) -- existing request limiter refill
 check("direct III recast",Ability.HandleRequest(a,4,actor,"SageMode",state.roundId))
 local direct=sa.sage.active; assert(direct)
 waitFor(function() return direct.phase=="Active" end,5,"direct III")
 check("direct500 restored once",sa.pool.mana>575 and sa.pool.mana<590)
 local mana=sa.pool.mana; Naruto.Update(workspace:GetServerTimeNow())
 check("repeated activation no second restore",sa.pool.mana-mana<1)
 direct.expiresAt=workspace:GetServerTimeNow(); Naruto.Update(workspace:GetServerTimeNow()); sa.sage.cooldownAt=0
 task.wait(.4)
 check("new meditation toggle",Ability.HandleRequest(a,5,actor,"MeditationToggle",state.roundId))
 check("preparation for owner death",Ability.HandleRequest(a,6,actor,"SageMode",state.roundId))
 waitFor(function() return next(sa.meditation.clones)~=nil end,1,"new clones")
 local hp=actor:FindFirstChildOfClass("Humanoid"); assert(hp); hp.Health=0
 waitFor(function() return next(sa.meditation.clones)==nil end,1,"owner death invalidation")
 check("owner death cancels late work",sa.sage.active==nil)
 state.phase="Finished"; Clones.Update(workspace:GetServerTimeNow())
 check("terminal no orphan entities",next(Clones.GetAll())==nil)
 print("[MeditationTests] ALL PASS: "..count.." checks")
 return "passed"
end,function(message) return debug.traceback(tostring(message),2) end)
if not ok then warn("[MeditationTests] FAILED after "..count..": "..tostring(err)) end
