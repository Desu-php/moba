--!nocheck
-- Temporary Studio server script: uses the same module cache as live gameplay.
assert(game:GetService("RunService"):IsStudio())
workspace:SetAttribute("SasukeFourQAStatus",nil);workspace:SetAttribute("SasukeFourQAError",nil);workspace:SetAttribute("SasukeFourQAChecks",0)
local run=(workspace:GetAttribute("SasukeFourQARun") or 0)+1;workspace:SetAttribute("SasukeFourQARun",run)
local S=game.ServerScriptService.Server.Services
local Match=require(S.MatchService)
local Sasuke=require(S.SasukeAbilityService)
local Ability=require(S.AbilityService)
local Combat=require(S.CombatService)
local Fighters=require(S.FighterStateService)
local Damage=require(S.DamageService)
local Sleep=require(S.NarutoSleepService)
local Dev=require(S.DeveloperCommandService)
local Native=require(S.NarutoAbilityService)
local Stats=require(S.CharacterStatsService)
local count=0
local created={}
local connection
local function check(name,condition)
 assert(condition,name);count+=1;print("[SasukeFourQA] PASS "..name)
 workspace:SetAttribute("SasukeFourQAChecks",count)
end
local function waitFor(fn,seconds)
 local deadline=os.clock()+seconds
 repeat if fn() then return end;task.wait(.05) until os.clock()>deadline
 error("Timed out waiting for game state")
end
local function now() return workspace:GetServerTimeNow() end
local ok,err=xpcall(function()
 waitFor(function() return Match.GetState() and #game.Players:GetPlayers()>0 end,20)
 local player=game.Players:GetPlayers()[1]
 workspace:SetAttribute("DeveloperSoloMode",true)
 waitFor(function() return Match.GetState().phase=="InProgress" end,45)
 Match.GetState().nextWaveAt=now()+10000
 require(S.MinionAIService).Reset();require(S.JungleService).Stop()
 require(game.ReplicatedStorage.Shared.Config.TowerConfig).Range=0;require(S.TowerService).CancelAll()
 player:SetAttribute("HeroId","Sasuke");player:LoadCharacterAsync()
 waitFor(function() return player.Character and string.find(player.Character:GetAttribute("HeroAppearanceVersion") or "","Sasuke") and Native.Get(player) end,20)
 Dev.Execute(player,"level 30");Dev.Execute(player,"learnall");Dev.Execute(player,"nocd on");task.wait(.3);Dev.Execute(player,"refresh")
 local model=player.Character;local r=model.HumanoidRootPart;local h=model.Humanoid
 for _,v in model:GetChildren() do if v:IsA("ForceField") then v:Destroy() end end
 r:SetNetworkOwner(nil);r.CFrame=CFrame.new(-275,36,0);r.AssemblyLinearVelocity=Vector3.zero
 task.wait(.4)
 local home=r.CFrame
 local f=Fighters.GetOrCreate(model)
 local function dummy(name,offset,ally)
  local m=Instance.new("Model");m.Name=name
  local part=Instance.new("Part");part.Name="HumanoidRootPart";part.Size=Vector3.new(2,4,2);part.Anchored=true;part.CanCollide=false;part.CFrame=home*CFrame.new(offset);part.Parent=m
  local hp=Instance.new("Humanoid");hp.RequiresNeck=false;hp.MaxHealth=100000;hp.Health=100000;hp.WalkSpeed=20;hp.Parent=m;m.PrimaryPart=part
  m:SetAttribute("TeamId",if ally then player:GetAttribute("TeamId") else if player:GetAttribute("TeamId")=="Blue" then "Red" else "Blue")
  m:SetAttribute("EntityKind","Minion");m:SetAttribute("RoundId",Match.GetState().roundId);m.Parent=workspace
  Fighters.GetOrCreate(m);Fighters.SetWalkSpeed(m,20);table.insert(created,m);return m
 end
 local target=dummy("FourQA_Target",Vector3.new(0,0,-18))
 local bystander=dummy("FourQA_Bystander",Vector3.new(0,0,-9))
 local friend=dummy("FourQA_Ally",Vector3.new(8,0,-18),true)
 local th=target.Humanoid;local tr=target.HumanoidRootPart
 local visuals={};local procCount=0
 connection=Sasuke.Visual.Event:Connect(function(m) visuals[m.id]=m;if m.id=="Counter" then procCount+=1 end end)
 local serial=50000
 local function cast(id,targetValue)
  serial+=1;Dev.Execute(player,"refresh")
  local accepted,reason=Sasuke.TryCast(player,id,serial,now(),targetValue)
  return accepted,reason
 end
 local function prepared()
  check("prepare Chidori",cast("Chidori"));task.wait(.85)
 end
 prepared()
 local mana=Native.Get(player).pool.mana
 local accepted=Sasuke.TryCast(player,"ChidoriEiso",serial+1,now(),tr.Position)
 check("Eiso rejects ground without consuming charge or mana",not accepted and model:GetAttribute("ChidoriHeld")==true and Native.Get(player).pool.mana==mana)
 local before,other=th.Health,bystander.Humanoid.Health
 check("Eiso accepts chosen enemy",cast("ChidoriEiso",target))
 check("Eiso locks movement and consumes charge",h.WalkSpeed==0 and model:GetAttribute("ChidoriHeld")==false)
 task.wait(.45);check("Eiso has no early hit",th.Health==before)
 task.wait(.4)
 check("Eiso damages exactly one enemy",math.abs(before-th.Health-(380+3*Stats.Get(player).Agility))<.01 and bystander.Humanoid.Health==other)
 check("Eiso holds victim two seconds",target:GetAttribute("CombatStunUntil")>now()+1.75)
 check("Eiso visual ends at chosen target",visuals.Eiso and visuals.Eiso.extra.finish==tr.Position)
 task.wait(.5);check("Eiso releases caster",h.WalkSpeed>0)
 prepared();before=th.Health;check("second Eiso starts",cast("ChidoriEiso",target))
 Fighters.StunSpell(f,.3);task.wait(.85);check("stun cancels pending Eiso",th.Health==before and h.WalkSpeed>0)
 prepared();before=th.Health;check("third Eiso starts",cast("ChidoriEiso",target))
 local wall=Instance.new("Part");wall.Size=Vector3.new(8,12,1);wall.Anchored=true;wall.CFrame=home*CFrame.new(0,0,-12);wall.Parent=workspace;table.insert(created,wall)
 task.wait(.85);check("Eiso rechecks obstacles at impact",th.Health==before);wall:Destroy();task.wait(.45)
 check("Sharingan enabled",cast("Sharingan"))
 before=th.Health
 for _=1,30 do Damage.NotifyAttackAttempt(target,model) end
 task.wait(.05);check("incoming attacks do not proc Sharingan",th.Health==before and procCount==0)
 -- Exercise real M1 once, then its public committed-start event repeatedly.
 tr.CFrame=home*CFrame.new(0,0,-4);bystander.HumanoidRootPart.CFrame=home*CFrame.new(20,0,-20)
 check("normal M1 starts",Combat.TryAttack(player,50000+run*100000,model)=="Started");task.wait(.3)
 local initial=procCount;before=th.Health
 for _=1,100 do Combat.AttackStarted:Fire(f,target) end
 task.wait(.15)
 check("own attack procs Sharingan",procCount>initial)
 check("Sharingan adds exactly 1.5 agility per proc",math.abs(before-th.Health-(procCount-initial)*1.5*Stats.Get(player).Agility)<.05)
 check("Sharingan relocates near victim",math.abs(((r.Position-tr.Position)*Vector3.new(1,0,1)).Magnitude-70/16)<.2)
 local facing=(tr.Position-r.Position)*Vector3.new(1,0,1)
 check("Sharingan faces victim",r.CFrame.LookVector:Dot(facing.Unit)>.98)
 task.wait(1.1);r.CFrame=home
 check("Rinnegan enabled",cast("Mangekyo") and model:GetAttribute("SasukeMode")==3)
 tr.CFrame=home*CFrame.new(0,0,-18)
 check("Rinnegan sleeps four seconds",cast("SasukeGenjutsu",target) and math.abs(target:GetAttribute("SleepUntil")-now()-4)<.1)
 before=th.Health;Damage.NotifyAttackAttempt(model,target);task.wait(.05)
 check("attack-start wake gives fifty pure damage",math.abs(before-th.Health-50)<.01 and target:GetAttribute("SleepUntil")==nil)
 check("Rinnegan wake applies forty percent slow",th.WalkSpeed==12 and target:GetAttribute("RinneganSlowUntil")>now()+5.8)
 Damage.ApplyAttack(model,th,10);task.wait(.05);check("contact does not duplicate wake bonus",math.abs(before-th.Health-60)<.01)
 target:SetAttribute("RinneganSlowUntil",now()-.01);task.wait(.1);check("slow expiry restores original speed",th.WalkSpeed==20)
 check("Rinnegan sleep for allied wake",cast("SasukeGenjutsu",target));before=th.Health
 check("allied attack can wake",Sleep.TryWakeAlly(bystander,target));task.wait(.05)
 check("allied wake slows without damage",th.Health==before and th.WalkSpeed==12)
 target:SetAttribute("RinneganSlowUntil",nil);Fighters.SetWalkSpeed(target,20)
 check("Rinnegan sleep for natural expiry",cast("SasukeGenjutsu",target));task.wait(4.1)
 check("natural wake also slows",target:GetAttribute("SleepUntil")==nil and th.WalkSpeed==12)
 check("downgrade to Sharingan",cast("Mangekyo") and model:GetAttribute("SasukeMode")==1)
 tr.CFrame=home*CFrame.new(0,0,-14)
 target:SetAttribute("RinneganSlowUntil",nil);Fighters.SetWalkSpeed(target,20)
 check("ordinary genjutsu starts",cast("SasukeGenjutsu",target));Sleep.TryWakeAlly(bystander,target)
 check("ordinary genjutsu has no Rinnegan slow",target:GetAttribute("RinneganSlowUntil")==nil and th.WalkSpeed==20)
 check("Rinnegan restored",cast("Mangekyo"))
 r.CFrame=home;local origin=r.Position
 check("Chibaku self cast through public boundary",Ability.TryCast(player,60000+run*100000,model,"ChibakuTensei"))
 check("Chibaku preparation starts empty and locks movement",model:GetAttribute("ChibakuCount")==0 and h.WalkSpeed==0)
 task.wait(.55);check("no spheres before one second",model:GetAttribute("ChibakuCount")==0)
 task.wait(.6);check("nine spheres after one second",model:GetAttribute("ChibakuCount")==9)
 local event=visuals.Chibaku;check("Chibaku centered on caster",event and (event.position-origin).Magnitude<.2)
 local distances={}
 for i,point in event.extra.points do
  local delta=point-origin;distances[i]=delta.Magnitude
  check("sphere "..i.." in 400 to 1000 ring",delta.Magnitude>=25 and delta.Magnitude<=62.5)
  local expected=Vector3.new(math.cos(i*math.pi*2/9),0,math.sin(i*math.pi*2/9))
  check("sphere "..i.." occupies its angular sector",delta.Unit:Dot(expected)>.999)
 end
 check("sphere radii are varied",math.abs(distances[1]-distances[2])>.001)
 check("cannot move spheres during preparation",not cast("ChibakuMove",origin))
 task.wait(2);check("Chibaku releases movement after three seconds",h.WalkSpeed>0)
 local goal=origin+Vector3.new(80,0,0)
 check("move spheres command",cast("ChibakuMove",goal));local move=visuals.ChibakuMove;task.wait(.05);move=visuals.ChibakuMove
 check("move timing reflects full travel",move.duration>0)
 task.wait(move.duration+.2)
 tr.CFrame=CFrame.new(move.extra.points[1]);before=th.Health
 check("drop spheres command",cast("ChibakuDrop"));task.wait(.45);check("drop has no early damage",th.Health==before)
 task.wait(.6);check("drop hits once across overlaps",math.abs(before-th.Health-(400+3*Stats.Get(player).Agility))<.02)
 check("drop removes sphere state",model:GetAttribute("ChibakuCount")==0)
 r.CFrame=home;check("Chibaku can prepare again",cast("ChibakuTensei"));Fighters.StunSpell(f,.3);task.wait(1.1)
 check("stun cancels Chibaku creation and releases movement",model:GetAttribute("ChibakuCount")==0 and h.WalkSpeed>0)
 check("final Chibaku starts",cast("ChibakuTensei"));task.wait(1.1);check("mode exit cancels spheres",cast("SasukeModeOff") and model:GetAttribute("ChibakuCount")==0)
 -- Leave the player healthy; tests themselves are removed after observing the result.
 r.CFrame=home;Dev.Execute(player,"refresh")
 workspace:SetAttribute("SasukeFourQAStatus","PASS")
end,debug.traceback)
if connection then connection:Disconnect() end
for _,item in created do item:Destroy() end
if not ok then workspace:SetAttribute("SasukeFourQAStatus","FAIL");workspace:SetAttribute("SasukeFourQAError",err);warn(err) end
