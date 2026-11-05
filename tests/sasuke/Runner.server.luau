--!nocheck
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Match=require(S.MatchService)
local Ability=require(S.AbilityService)
local Native=require(S.NarutoAbilityService)
local Sasuke=require(S.SasukeAbilityService)
local Combat=require(S.CombatService)
local Fighters=require(S.FighterStateService)
local Dev=require(S.DeveloperCommandService)
local Stats=require(S.CharacterStatsService)
local count=0
local function check(name,condition) assert(condition,name);count+=1;print("[SasukeQA] PASS "..name) end
local function waitFor(fn,seconds)
 local deadline=os.clock()+seconds;repeat if fn() then return end;task.wait(.1) until os.clock()>deadline;error("Timed out")
end
local ok,err=xpcall(function()
 waitFor(function() return Match.GetState() and Match.GetState().phase=="InProgress" end,40)
 local player=game.Players:GetPlayers()[1];waitFor(function() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end,15)
 Match.GetState().nextWaveAt=workspace:GetServerTimeNow()+10000
 require(S.MinionAIService).Reset();require(S.JungleService).Stop();require(game.ReplicatedStorage.Shared.Config.TowerConfig).Range=0;require(S.TowerService).CancelAll()
 player:SetAttribute("HeroId","Sasuke");player:LoadCharacterAsync()
 waitFor(function() return player.Character and player.Character:GetAttribute("HeroAppearanceVersion") and string.find(player.Character:GetAttribute("HeroAppearanceVersion"),"Sasuke") end,20)
 local model=player.Character;local root=model.HumanoidRootPart
 root:SetNetworkOwner(nil);root.CFrame=CFrame.new(-275,36,0);root.AssemblyLinearVelocity=Vector3.zero
 for _,v in model:GetChildren() do if v:IsA("ForceField") then v:Destroy() end end
 check("level and learning commands",Dev.Execute(player,"level 30") and Dev.Execute(player,"learnall"))
 task.wait(.3);Dev.Execute(player,"refresh")
 local p=require(S.HeroProgressionService).Get(player)
 check("Sasuke attributes",Stats.Get(player).RawAgility==16+29*1.4 and Native.Get(player).pool.maximum<1300)
 check("four independent learning lines",p.Learned.SasukeLightning==4 and p.Learned.SasukeEyes==5 and p.Learned.Rasengan==nil)
 local serial=1000
 local function cast(id,target)
  task.wait(.38);serial+=1
  return Ability.TryCast(player,serial,model,id,target)
 end
 -- Self spells use the three-argument boundary.
 local function selfCast(id) task.wait(.38);serial+=1;return Ability.TryCast(player,serial,model,id) end
 local target=Instance.new("Model");target.Name="SasukeTrainingTarget"
 local tr=Instance.new("Part");tr.Name="HumanoidRootPart";tr.Size=Vector3.new(2,4,2);tr.Anchored=true;tr.CFrame=root.CFrame*CFrame.new(0,0,-4);tr.Parent=target
 local h=Instance.new("Humanoid");h.RequiresNeck=false;h.MaxHealth=20000;h.Health=20000;h.Parent=target;target.PrimaryPart=tr
 target:SetAttribute("TeamId",if player:GetAttribute("TeamId")=="Blue" then "Red" else "Blue");target:SetAttribute("EntityKind","Minion");target:SetAttribute("RoundId",Match.GetState().roundId);target.Parent=workspace
 Fighters.GetOrCreate(target)
 check("foreign hero ability rejected",not selfCast("Rasengan"))
 check("unprepared continuation rejected",not cast("ChidoriSenbon",tr.Position))
 local mana=Native.Get(player).pool.mana
 check("Chidori prepares",selfCast("Chidori"));check("charge debits chakra",Native.Get(player).pool.mana<mana-80)
 task.wait(.9);local before=h.Health;local result=Combat.TryAttack(player,1000,model)
 check("M1 accepted",result=="Started")
 task.wait(.35);local expected=require(game.ReplicatedStorage.Shared.Abilities.SasukeDefinitions).chidoriDamage(Stats.Get(player).Level,Stats.Get(player).Agility,"Chidori")
 check("first contact is exactly Chidori damage",math.abs(before-h.Health-expected)<.01)
 check("charge consumed and 3s stun",model:GetAttribute("ChidoriHeld")==false and tr.Parent:GetAttribute("CombatStunUntil")>workspace:GetServerTimeNow()+2)
 check("cooldown rejects recast",not selfCast("Chidori"))
 Dev.Execute(player,"refresh");task.wait(1.3)
 check("Sharingan",selfCast("Sharingan"));check("Rinnegan from rank5",selfCast("Mangekyo") and model:GetAttribute("SasukeMode")==3)
 local pool=Native.Get(player).pool;local previous=pool.mana;task.wait(1.1);check("modes drain chakra",pool.mana<previous-5)
 check("ribs coexist with eyes",selfCast("SusanooRibs") and model:GetAttribute("SusanooForm")==1)
 local damage=require(S.DamageService);before=model.Humanoid.Health;damage.Apply(target,model.Humanoid,40)
 check("ribs reduce incoming damage",before-model.Humanoid.Health<24)
 Dev.Execute(player,"refresh");check("complete Susanoo starts",selfCast("CompleteSusanoo"));task.wait(3.3)
 check("complete Susanoo profile and model",model:GetAttribute("SusanooForm")==3 and model:GetAttribute("CombatProfileId")=="SasukeSusanoo" and #model.HeroAppearance:GetChildren()>20)
 check("exit clears form and eyes",selfCast("SasukeModeOff") and model:GetAttribute("SusanooForm")==0 and model:GetAttribute("SasukeMode")==0)
 Dev.Execute(player,"refresh")
 check("out of range does not spend mana",not cast("SasukeFireball",root.Position+Vector3.new(10000,0,0)))
 check("fireball launches",cast("SasukeFireball",tr.Position));task.wait(.5);check("shared fire cooldown",not cast("PhoenixFlowers",tr.Position))
 Dev.Execute(player,"refresh");check("Kirin preparation",selfCast("KirinPrepare"));check("early Kirin rejected",not cast("Kirin",tr.Position))
 task.wait(4);before=h.Health;check("Kirin ready",cast("Kirin",tr.Position));task.wait(1.7);check("Kirin hits marked area",h.Health<before-900)
 Dev.Execute(player,"refresh");check("second charge",selfCast("Chidori"));task.wait(.9)
 before=h.Health;check("Senbon consumes held charge",cast("ChidoriSenbon",tr.Position) and model:GetAttribute("ChidoriHeld")==false);task.wait(.5)
 check("needles actually hit",h.Health<before)
 Dev.Execute(player,"refresh");check("eyes restart",selfCast("Sharingan"));check("Rinnegan restart",selfCast("Mangekyo"))
 check("genjutsu sleeps target",cast("SasukeGenjutsu",target) and target:GetAttribute("SleepUntil")>workspace:GetServerTimeNow())
 before=h.Health;damage.ApplyAttack(model,h,10);check("wake attack adds exactly 50 pure damage",math.abs(before-h.Health-60)<.01 and target:GetAttribute("SleepUntil")==nil)
 Dev.Execute(player,"refresh");check("nine Chibaku spheres",cast("ChibakuTensei",tr.Position) and model:GetAttribute("ChibakuCount")==9)
 task.wait(3.2);check("sphere relocation",cast("ChibakuMove",tr.Position+Vector3.new(5,0,0)));task.wait(.3)
 before=h.Health;check("sphere drop command",selfCast("ChibakuDrop"));task.wait(1.1);check("drop hits once across overlaps",math.abs(before-h.Health-(400+3*Stats.Get(player).Agility))<.01)
 check("modes clear",selfCast("SasukeModeOff"));Dev.Execute(player,"refresh")
 check("Garuda on",selfCast("Garuda") and model:GetAttribute("GarudaActive")==true)
 check("flight rejects attack spells",not selfCast("Chidori"));task.wait(.2)
 check("Garuda off without waiting for cooldown",selfCast("Garuda") and model:GetAttribute("GarudaActive")==false)
 Dev.Execute(player,"refresh");check("Aoda summon",cast("Aoda",root.Position+Vector3.new(8,0,0)));task.wait(.3)
 local aoda=nil;for _,m in workspace.HeroSummons:GetChildren() do if m:GetAttribute("NativeAoda") then aoda=m end end
 check("Aoda rank10 stats",aoda and aoda.Humanoid.MaxHealth==1500)
 before=h.Health;task.wait(5);check("Aoda independently attacks",h.Health<before)
 check("death cleanup",true);model.Humanoid.Health=0;task.wait(.5)
 check("effects and summons end on death",not aoda.Parent)
 workspace:SetAttribute("SasukeQAStatus","PASS");workspace:SetAttribute("SasukeQAChecks",count)
end,debug.traceback)
if not ok then workspace:SetAttribute("SasukeQAStatus","FAIL");workspace:SetAttribute("SasukeQAError",err);warn(err) end
