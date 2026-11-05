--!nocheck
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local A=require(S.SasukeAbilityService)
local Match=require(S.MatchService)
local Stats=require(S.CharacterStatsService)
local Fighters=require(S.FighterStateService)
local Combat=require(S.CombatService)
local Dev=require(S.DeveloperCommandService)
local Native=require(S.NarutoAbilityService)
local count=0;local created={};local connection
workspace:SetAttribute("SasukeNextQAStatus",nil);workspace:SetAttribute("SasukeNextQAError",nil)
local function now() return workspace:GetServerTimeNow() end
local function check(name,ok) assert(ok,name);count+=1;print("[SasukeNextQA] PASS "..name);workspace:SetAttribute("SasukeNextQAChecks",count) end
local function waitFor(fn,seconds) local ends=os.clock()+seconds repeat if fn() then return end task.wait(.1) until os.clock()>ends error("Wait timed out") end
local ok,err=xpcall(function()
 waitFor(function() return Match.GetState() and #game.Players:GetPlayers()>0 end,20)
 workspace:SetAttribute("DeveloperSoloMode",true);waitFor(function() return Match.GetState().phase=="InProgress" end,45)
 Match.GetState().nextWaveAt=now()+10000;require(S.MinionAIService).Reset();require(S.JungleService).Stop()
 require(game.ReplicatedStorage.Shared.Config.TowerConfig).Range=0;require(S.TowerService).CancelAll()
 local p=game.Players:GetPlayers()[1];p:SetAttribute("HeroId","Sasuke");p:LoadCharacterAsync()
 waitFor(function() return p.Character and string.find(p.Character:GetAttribute("HeroAppearanceVersion") or "","Sasuke") and Native.Get(p) end,20)
 Dev.Execute(p,"level 30");Dev.Execute(p,"learnall");Dev.Execute(p,"nocd on");task.wait(.3);Dev.Execute(p,"refresh")
 local m=p.Character;local r=m.HumanoidRootPart;local h=m.Humanoid
 for _,v in m:GetChildren() do if v:IsA("ForceField") then v:Destroy() end end
 r:SetNetworkOwner(nil);r.CFrame=CFrame.new(-275,36,0);r.AssemblyLinearVelocity=Vector3.zero;task.wait(.4)
 local home=r.CFrame;local profile=require(S.HeroProgressionService).Get(p)
 local function body(name,offset)
  local target=Instance.new("Model");target.Name=name
  local tr=Instance.new("Part");tr.Name="HumanoidRootPart";tr.Anchored=true;tr.CanCollide=false;tr.Size=Vector3.new(2,4,2);tr.CFrame=home*CFrame.new(offset);tr.Parent=target;target.PrimaryPart=tr
  local hp=Instance.new("Humanoid");hp.RequiresNeck=false;hp.MaxHealth=50000;hp.Health=50000;hp.Parent=target
  target:SetAttribute("TeamId",if p:GetAttribute("TeamId")=="Blue" then "Red" else "Blue");target:SetAttribute("EntityKind","Minion");target:SetAttribute("RoundId",Match.GetState().roundId);target.Parent=workspace;Fighters.GetOrCreate(target);table.insert(created,target);return target
 end
 local target=body("NextQA_Target",Vector3.new(0,0,-18));local other=body("NextQA_Other",Vector3.new(8,0,-18));local tr=target.HumanoidRootPart;local th=target.Humanoid
 local visuals={};local projectiles={};local waveCount=0
 connection=A.Visual.Event:Connect(function(v) visuals[v.id]=v;if v.id=="Projectile" and v.extra.spell=="ChidoriSenbon" then table.insert(projectiles,v) end;if v.id=="SusanooWave" then waveCount+=1 end end)
 local function cast(id,t) Dev.Execute(p,"refresh");return A.TryCast(p,id,1,now(),t) end
 local function attackDamage() local s=Stats.Get(p);return 10*s.AttackDamageMultiplier+s.AttackDamageBonus end
 local baseline=attackDamage();check("Katana cast",cast("ChidoriKatana"));check("Katana multiplies complete attack by 1.6",math.abs(attackDamage()-baseline*1.6)<.001)
 profile.Owned.IronBlade=true;Stats.RecalculateStats(p)
 check("Katana responds to equipment changes",math.abs(attackDamage()-(baseline+1.5)*1.6)<.001)
 local improved=attackDamage();check("Katana recast does not stack",cast("ChidoriKatana") and math.abs(attackDamage()-improved)<.001)
 profile.Owned.SwiftBoots=true;Stats.RecalculateStats(p);local ground=h.WalkSpeed
 check("Garuda starts",cast("Garuda"));check("Garuda scales current speed including boots",math.abs(h.WalkSpeed-ground*1.3)<.001)
 check("Garuda blocks combat techniques",not cast("Chidori"));check("Garuda ends",cast("Garuda"));check("Garuda restores equipment speed",math.abs(h.WalkSpeed-ground)<.001)
 profile.Level=12;check("Garuda requires level thirteen",not cast("Garuda"));profile.Level=30;Stats.RecalculateStats(p)
 check("Chidori charges for needles",cast("Chidori"));task.wait(.85)
 local before=th.Health;local otherBefore=other.Humanoid.Health
 check("Senbon accepted",cast("ChidoriSenbon",tr.Position));task.wait(.7)
 check("eight needles are emitted",#projectiles==8)
 for i,v in projectiles do check("needle "..i.." converges at aim",(v.extra.finish-tr.Position).Magnitude<.01) end
 check("needles begin at varied positions",(projectiles[1].position-projectiles[2].position).Magnitude>.01)
 check("eight needles deal eight single hits",math.abs(before-th.Health-8*(15+.5*Stats.Get(p).Agility))<.1 and other.Humanoid.Health==otherBefore)
 tr.CFrame=home*CFrame.new(0,0,-10);before=th.Health;check("Nagashi starts",cast("ChidoriNagashi"));task.wait(.4)
 check("Nagashi continuously damages and pushes",th.Health<before and tr.Position.Z<(home*CFrame.new(0,0,-10)).Position.Z-.5)
 task.wait(3.7);check("Nagashi armor layer expires",Stats.Get(p).Defense<100)
 r.CFrame=home;tr.CFrame=home*CFrame.new(0,0,-18)
 check("Kirin preparation starts",cast("KirinPrepare"));task.wait(4.6)
 check("Kirin rejects ground",not cast("Kirin",tr.Position))
 before=th.Health;local start=now();check("Kirin accepts enemy",cast("Kirin",target))
 task.wait(.8);tr.CFrame=home*CFrame.new(25,0,-18);check("Kirin has no early hit",th.Health==before)
 task.wait(.9);check("Kirin follows moving target",visuals.Kirin and (visuals.Kirin.position-tr.Position).Magnitude<.1)
 local total=100+30*Stats.Get(p).Level+3*Stats.Get(p).Strength
 check("Kirin delivers initial partial damage",before-th.Health>=total*.49 and before-th.Health<=total*.7)
 task.wait(.95);check("Kirin finishes exact pulse total",math.abs(before-th.Health-total)<.1 and now()-start>=2.5)
 check("Kirin unlocks movement",h.WalkSpeed>0)
 check("second Kirin prepare",cast("KirinPrepare"));task.wait(4.6);before=th.Health;check("second Kirin begins",cast("Kirin",target))
 Fighters.StunSpell(Fighters.Get(m),.3);task.wait(1.8);check("stun prevents delayed Kirin damage",th.Health==before and h.WalkSpeed>0)
 r.CFrame=home;tr.CFrame=home*CFrame.new(0,0,-18)
 check("Sharingan on",cast("Sharingan"));check("Rinnegan on",cast("Mangekyo"))
 check("Garuda rejects active eyes",not cast("Garuda"))
 check("Ameno selects first enemy",cast("Amenotejikara",target));local selectedAt=tr.Position
 local secondAt=other.HumanoidRootPart.Position;local ownAt=r.Position
 check("Ameno swaps with second chosen enemy",cast("Amenotejikara",other))
 check("second enemy swaps with caster, first stays",((r.Position-secondAt)*Vector3.new(1,0,1)).Magnitude<.1 and ((other.HumanoidRootPart.Position-ownAt)*Vector3.new(1,0,1)).Magnitude<.1 and tr.Position==selectedAt)
 r.CFrame=home;other.HumanoidRootPart.CFrame=home*CFrame.new(8,0,-18)
 check("Ameno selects for ground transfer",cast("Amenotejikara",target));local ownBefore=r.Position;local dest=home.Position+Vector3.new(10,0,-25)
 check("Ameno transfers selected target to ground",cast("Amenotejikara",dest) and ((tr.Position-dest)*Vector3.new(1,0,1)).Magnitude<.1 and r.Position==ownBefore)
 r.CFrame=home;local far=home.Position+Vector3.new(65,0,0)
 check("Ameno ground teleport",cast("Amenotejikara",far));check("ground blink is capped at 900",math.abs(((r.Position-home.Position)*Vector3.new(1,0,1)).Magnitude-900/16)<.2)
 r.CFrame=home;tr.CFrame=home*CFrame.new(0,0,-20);before=th.Health
 check("Enton pull starts",cast("EntonPull"));task.wait(.4);check("Enton attracts before damaging",th.Health==before and tr.Position.Z>(home*CFrame.new(0,0,-20)).Position.Z+.5)
 task.wait(.5);check("Enton Rinnegan branch deals 650 plus 3 agility",math.abs(before-th.Health-(650+3*Stats.Get(p).Agility))<.1)
 task.wait(2);check("Enton releases caster",h.WalkSpeed>0)
 check("complete Susanoo starts",cast("CompleteSusanoo"));Fighters.StunSpell(Fighters.Get(m),.3);task.wait(3.1)
 check("control cancels transformation",m:GetAttribute("SusanooForm")==0 and h.WalkSpeed>0)
 check("complete Susanoo retries",cast("CompleteSusanoo"));task.wait(3.1);check("complete Susanoo appears",m:GetAttribute("SusanooForm")==3)
 tr.CFrame=home*CFrame.new(0,0,-20);other.HumanoidRootPart.CFrame=home*CFrame.new(4,0,-20);before=other.Humanoid.Health
 for _=1,150 do Combat.AttackStarted:Fire(Fighters.Get(m),target) end;task.wait(.15)
 check("Susanoo rolls wave once while active",waveCount==1)
 check("Susanoo wave hits nearby bystander",math.abs(before-other.Humanoid.Health-(150+Stats.Get(p).Agility))<.1)
 task.wait(.6);check("Susanoo wave does not damage bystander twice",math.abs(before-other.Humanoid.Health-(150+Stats.Get(p).Agility))<.1)
 check("exit clears form",cast("SasukeModeOff"));Dev.Execute(p,"refresh")
 workspace:SetAttribute("SasukeNextQAStatus","PASS")
end,debug.traceback)
if connection then connection:Disconnect() end
for _,v in created do v:Destroy() end
if not ok then workspace:SetAttribute("SasukeNextQAStatus","FAIL");workspace:SetAttribute("SasukeNextQAError",err);warn(err) end
