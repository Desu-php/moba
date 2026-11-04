-- One-player Studio integration fixture. Run combat-ux.project.json with Play,
-- leave input idle, then read CombatUXRegressionReport. Real-key input/camera QA
-- remains separate. This test resets casts and kills the hero in its last case.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
assert(workspace:GetAttribute("CombatUXTestFixture") == true, "Use combat-ux.project.json")
task.spawn(function()
 local started=os.clock()
 local checks={}
 local metrics={}
 workspace:SetAttribute("CombatUXRegressionState","WaitingForSetup")
 local function check(name, condition)
  assert(condition,name)
  table.insert(checks,name)
  print("[CombatUXQA] PASS "..name)
 end
 local function waitFor(predicate,seconds,name)
  local untilAt=math.min(os.clock()+seconds,started+45)
  repeat if predicate() then return end; task.wait(.03) until os.clock()>untilAt
  error("Timeout: "..name)
 end
 local ok,failure=xpcall(function()
  local startupDeadline=os.clock()+35
  while workspace:GetAttribute("CombatUXQAReady")~=true do
   assert(os.clock()<startupDeadline,"Combat UX runner timed out waiting for setup")
   task.wait(.05)
  end
  started=os.clock()
  workspace:SetAttribute("CombatUXRegressionState","Running")
  local Players=game:GetService("Players")
  local S=game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
  local Ability=require(S.AbilityService)
  local Native=require(S.NarutoAbilityService)
  local Summons=require(S.NarutoSummonService)
  local Gama=require(S.GamakichiService)
  local Fighters=require(S.FighterStateService)
  local Physics=game:GetService("PhysicsService")
  local Progression=require(S.HeroProgressionService)
  assert(#Players:GetPlayers()==1,"Use isolated one-player QA Play session")
  local player=Players:GetPlayers()[1]
  local character=player.Character
  assert(character,"Character not ready")
  local humanoid=character:FindFirstChildOfClass("Humanoid")
  local root=character:FindFirstChild("HumanoidRootPart")
  local deck=workspace:FindFirstChild("CombatUXQA")
  assert(humanoid and root and deck,"Run ux-qa-setup first")
  local target=deck:FindFirstChild("NearTarget")
  assert(target,"Missing test target")
  local victim=target:FindFirstChildOfClass("Humanoid")
  local victimRoot=target:FindFirstChild("HumanoidRootPart")
  assert(victim and victimRoot,"Target incomplete")
  local session=Native.Get(player)
  assert(session,"Live Script session unavailable")
  local serial=math.max(session.q.lastRequest,session.clones.lastRequest,session.commands.lastRequest,session.sage.lastRequest,session.gama.lastRequest)+1
  local function cast(id,aim)
   serial+=1
   return Native.TryCast(player,id,serial,workspace:GetServerTimeNow(),aim)
  end
  local function refill()
   session.pool.mana=session.pool.maximum
   session.nextPublish=0
   Native.Update(workspace:GetServerTimeNow())
  end
  local function reset()
   Ability.Reset(); Fighters.Reset()
   Fighters.GetOrCreate(character)
   for _,item in deck:GetChildren() do if item:IsA("Model") and item:FindFirstChildOfClass("Humanoid") then Fighters.GetOrCreate(item) end end
   session=Native.Get(player); assert(session)
   root.Anchored=false; root:SetNetworkOwner(nil)
   humanoid.AutoRotate=false
   character:PivotTo(CFrame.new(0,1000+humanoid.HipHeight+root.Size.Y/2,30))
   root.AssemblyLinearVelocity=Vector3.zero
   humanoid.Health=humanoid.MaxHealth
   refill()
  end
  local function checkGroup(model)
   for _,item in model:GetDescendants() do
    if item:IsA("BasePart") then
     assert(item.CollisionGroup=="SurvivalSummons",model.Name.." part outside summon collision group: "..item.Name)
     assert(not Physics:CollisionGroupsAreCollidable(item.CollisionGroup,root.CollisionGroup),"Summon can collide with owner")
     assert(not Physics:CollisionGroupsAreCollidable(item.CollisionGroup,"SurvivalSummons"),"Summon can collide with peer")
    end
   end
  end
  reset()
  check("production rank unlocks exist",Progression.Get(player).Learned.Rasengan==3 and Progression.Get(player).Learned.ShadowClones==4)
  session.pool.mana=0
  local accepted,reason=cast("Rasengan")
  check("Rasengan zero chakra rejected",not accepted and reason=="Mana")
  refill(); local mana=session.pool.mana
  check("Rasengan accepted",cast("Rasengan"))
  check("Rasengan one 100 chakra debit",math.abs(session.pool.mana-(mana-100))<1)
  local afterFirst=session.pool.mana
  accepted,reason=cast("Rasengan")
  check("duplicate prepared Rasengan rejected without second debit",not accepted and reason=="Busy" and math.abs(session.pool.mana-afterFirst)<1)
  check("Odama selection accepted in source window",cast("Odama"))
  check("Rasenshuriken selection accepted in next window",cast("Rasenshuriken"))
  check("variant stays one active cast",session.q.active.variant=="Rasenshuriken")
  Fighters.StunSpell(Fighters.Get(character),.2)
  waitFor(function()return session.q.active==nil end,.5,"external stun cancels held technique")
  check("external stun cancels variant without refunding cooldown",session.q.active==nil and session.q.cooldownAt>workspace:GetServerTimeNow())

  reset(); mana=session.pool.mana
  check("Sage III accepted",cast("SageMode"))
  check("Sage exact initial cost",math.abs(session.pool.mana-(mana-25))<1)
  check("Sage preparation remains explicit",session.sage.active.phase=="Preparing")
  waitFor(function()return session.sage.active and session.sage.active.phase=="Active" end,5,"Sage preparation")
  check("Sage activates and movement resumes",humanoid.WalkSpeed>0 and character:GetAttribute("SagePhase")=="Active")

  reset()
  check("mass clones accepted",cast("ShadowClones"))
  waitFor(function()return Summons.GetCount()==30 end,2,"thirty clones")
  check("thirty clones spawned",Summons.GetCount()==30)
  check("Hold command accepted",cast("CloneCommand","Hold"))
  task.wait(.1)
  local positions={}
  for model,record in Summons.GetAll() do checkGroup(model); positions[model]=record.root.Position end
  check("every clone part ignores owner and peers",true)
  character:PivotTo(character:GetPivot()+Vector3.new(20,0,0)); root.AssemblyLinearVelocity=Vector3.zero
  task.wait(.3)
  local held=true
  for model,position in positions do if (Summons.GetAll()[model].root.Position-position).Magnitude>.03 then held=false end end
  check("Hold physically keeps all thirty clones still",held)
  check("Follow command accepted",cast("CloneCommand","Follow"))
  waitFor(function()
   for model,position in positions do local record=Summons.GetAll()[model]; if record and (record.root.Position-position).Magnitude>1 then return true end end
   return false
  end,3,"clone follow movement")
  check("Follow resumes physical movement",true)
  check("Attack command accepts server-valid enemy",cast("CloneCommand",target))
  accepted,reason=cast("CloneCommand",character)
  check("Attack rejects owner as friendly target",not accepted and reason=="Target")
  check("Hold after Attack accepted",cast("CloneCommand","Hold"))

  refill(); mana=session.pool.mana
  check("adult Gamakichi accepted",cast("Gamakichi"))
  local toad=Gama.Get(player); assert(toad)
  check("adult profile and 300 chakra debit",toad.cast.profile.adult and math.abs(session.pool.mana-(mana-300))<1)
  checkGroup(toad.model); check("toad parts ignore owner and peers",true)
  afterFirst=session.pool.mana
  accepted,reason=cast("Gamakichi")
  check("summon cooldown rejects repeated cast without debit",not accepted and reason=="Cooldown" and math.abs(session.pool.mana-afterFirst)<1)
  check("Follow shared by toad and clones",cast("CloneCommand","Follow"))
  local toadStart=toad.root.Position
  character:PivotTo(character:GetPivot()+Vector3.new(0,0,20)); root.AssemblyLinearVelocity=Vector3.zero
  waitFor(function()return (toad.root.Position-toadStart).Magnitude>1 end,3,"toad grounded follow")
  check("toad follows physically after spawn grounding",true)
  check("Hold shared by toad and clones",cast("CloneCommand","Hold"))
  task.wait(.1); toadStart=toad.root.Position; task.wait(.25)
  check("toad Hold physically stops movement",(toad.root.Position-toadStart).Magnitude<.03)

  -- Explicit spell requests work while the autonomous group is holding.
  toad.model:PivotTo(CFrame.new(0,1002.15,-8))
  victim.Health=victim.MaxHealth
  victimRoot.Position=Vector3.new(0,1002,-4)
  check("Gamakichi oil accepted",cast("GamakichiOil",target))
  check("oil waits for projectile arrival",target:GetAttribute("OilUntil")==nil)
  waitFor(function()return (target:GetAttribute("OilUntil") or 0)>workspace:GetServerTimeNow() end,1,"oil arrival")
  check("oil applies slow after arrival",target:GetAttribute("OilMoveMultiplier")==.6)
  accepted,reason=cast("GamakichiOil",target)
  check("oil cooldown rejects repeated spell",not accepted and reason=="Cooldown")
  local beforeWaves=victim.Health
  check("adult chopping accepted",cast("GamakichiChop",victimRoot.Position))
  task.wait(.2)
  check("chopping has no premature damage",victim.Health==beforeWaves)
  waitFor(function()return toad.model:GetAttribute("ChannelWave")==4 and toad.spells.channel==nil end,4.2,"four chopping waves")
  check("four chopping waves deal expected damage",math.abs(beforeWaves-victim.Health-480)<.01)
  metrics.choppingDamage=beforeWaves-victim.Health
  accepted,reason=cast("GamakichiChop",victimRoot.Position)
  check("chopping cooldown rejects repeat",not accepted and reason=="Cooldown")
  check("late clone collision groups remain intact",Summons.GetCount()>0)
  for model in Summons.GetAll() do checkGroup(model) end

  refill()
  check("held cast starts before death",cast("Rasengan"))
  root:SetNetworkOwner(nil); humanoid.Health=0
  waitFor(function()return Gama.Get(player)==nil and session.q.active==nil and not session.commands.active end,1,"death cleanup")
  check("death removes toad and cancels held cast and commands",Gama.Get(player)==nil and session.q.active==nil and not session.commands.active)
  positions={}
  for model,record in Summons.GetAll() do positions[model]=record.root.Position end
  task.wait(.25)
  held=true
  for model,position in positions do local record=Summons.GetAll()[model]; if record and (record.root.Position-position).Magnitude>.03 then held=false end end
  check("surviving source-lifetime clones stop on owner death",held)
  metrics.elapsed=os.clock()-started
  metrics.checkCount=#checks
 end,function(err)return debug.traceback(tostring(err),2)end)
 local report={ok=ok,checks=checks,metrics=metrics,elapsed=os.clock()-started,error=if ok then nil else failure,
  scope="Single-player server integration only; real-key M1/contact/camera are separate manual QA. Stop Play to discard state."}
 workspace:SetAttribute("CombatUXRegressionReport",game:GetService("HttpService"):JSONEncode(report))
 workspace:SetAttribute("CombatUXRegressionState",if ok then "PASS" else "FAIL")
 print("[CombatUXQA] "..(if ok then "PASS "..tostring(#checks).." checks" else "FAIL "..tostring(failure)))
end)
