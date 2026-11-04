--!nocheck
-- Run as a normal server Script in a disposable, single-player Studio Play session.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Players=game:GetService("Players")
local Dev=require(S.DeveloperCommandService)
local Match=require(S.MatchService)
local Kcm=require(S.NarutoKcmService)
local Kurama=require(S.NarutoKuramaService)
local Fighters=require(S.FighterStateService)
local Hitboxes=require(S.HitboxService)
local Combat=require(S.CombatService)
local Damage=require(S.DamageService)
local Stats=require(S.CharacterStatsService)
local Teams=require(S.TeamService)
local Config=require(game.ReplicatedStorage.Shared.Config.CombatConfig)
local Http=game:GetService("HttpService")
local checks={}
local function check(name,ok) assert(ok,name);table.insert(checks,name);workspace:SetAttribute("KuramaQAResults",Http:JSONEncode(checks)) end
local function waitFor(test,seconds,name)
 local deadline=os.clock()+seconds
 repeat if test() then return end;task.wait(.02) until os.clock()>deadline
 error("Timeout: "..name)
end
local ok,err=xpcall(function()
 waitFor(function() return #Players:GetPlayers()==1 and Match.GetState()~=nil end,30,"player")
 local p=Players:GetPlayers()[1]
 Dev.Execute(p,"solo")
 waitFor(function() return Match.GetState().phase=="InProgress" and p.Character and Fighters.Get(p.Character) end,30,"match")
 local match=Match.GetState();match.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(S.JungleService).Stop()
 local c=p.Character;local f=Fighters.Get(c);local h=f.humanoid;local root=f.root
 local floor=Instance.new("Part");floor.Name="KuramaQAFloor";floor.Anchored=true;floor.Size=Vector3.new(150,2,150);floor.Position=Vector3.new(600,34,600);floor.Parent=workspace
 c:PivotTo(CFrame.new(600,38,600));task.wait(.5)
 local force=c:FindFirstChildOfClass("ForceField");if force then force:Destroy() end
 assert(Dev.Execute(p,"level 30"));assert(Dev.Execute(p,"learnall"));assert(Dev.Execute(p,"rikudo"))
 assert(Kcm.TryCast(p,"KcmCancel",1001,workspace:GetServerTimeNow(),nil))
 waitFor(function() return c:GetAttribute("KcmActive")~=true end,5,"KCM exit")
 local prior=f.profile;local baseline=Stats.Get(p)
 local admitted,reason=Kurama.TryCast(p,1002,workspace:GetServerTimeNow(),nil);assert(admitted,reason)
 assert(Kurama.ObserveBuff(p,c:GetAttribute("LifeId"),match.roundId,c:GetAttribute("KuramaCastId"),true))
 check("Kurama profile and body applied",f.profileId=="Kurama" and c.KuramaCombatBody.CanCollide and c.KuramaCombatBody.CanQuery)
 check("form damage bonus applied once",Stats.Get(p).AttackDamageBonus==baseline.AttackDamageBonus+90)
 local function dummy(name,offset,team)
  local m=Instance.new("Model");m.Name=name;m:SetAttribute("TeamId",team or "Red");m:SetAttribute("RoundId",match.roundId);m:SetAttribute("EntityKind","Minion")
  local r=Instance.new("Part");r.Name="HumanoidRootPart";r.Size=Vector3.new(2,4,2);r.Anchored=true;r.CanCollide=false;r.CFrame=root.CFrame*CFrame.new(offset);r.Parent=m
  local hu=Instance.new("Humanoid");hu.MaxHealth=10000;hu.Health=10000;hu.Parent=m;m.PrimaryPart=r;m.Parent=workspace;Fighters.GetOrCreate(m)
  return m,hu,r
 end
 local target,th,tr=dummy("KuramaQATarget",Vector3.new(0,0,-14))
 local target2,h2,r2=dummy("KuramaQASecond",Vector3.new(3,0,-15))
 check("front target admitted",Hitboxes.GetTargets(c,root,f.profile)[1]==th)
 tr.CFrame=root.CFrame*CFrame.new(0,0,-17);r2.CFrame=root.CFrame*CFrame.new(0,0,20)
 check("outside reach rejected",#Hitboxes.GetTargets(c,root,f.profile)==0)
 tr.CFrame=root.CFrame*CFrame.new(0,0,10)
 check("behind rejected",#Hitboxes.GetTargets(c,root,f.profile)==0)
 tr.CFrame=root.CFrame*CFrame.new(0,0,-14);r2.CFrame=root.CFrame*CFrame.new(3,0,-15)
 local shield=Instance.new("ForceField");shield.Parent=target
 check("forcefield rejects giant strike",Hitboxes.GetTargets(c,root,f.profile)[1]~=th);shield:Destroy()
 local wall=Instance.new("Part");wall.Size=Vector3.new(30,30,1);wall.Anchored=true;wall.CFrame=root.CFrame*CFrame.new(0,0,-9);wall.Parent=workspace
 check("wall rejects giant strike",#Hitboxes.GetTargets(c,root,f.profile)==0);wall:Destroy()
 local hits={};local expected=f.profile.Damage*Stats.Get(p).AttackDamageMultiplier+Stats.Get(p).AttackDamageBonus
 local conn=Damage.Applied.Event:Connect(function(a,v,amount) if a==c then table.insert(hits,{victim=v,amount=amount,at=workspace:GetServerTimeNow()}) end end)
 check("heavy attack started",Combat.TryAttack(p,9001,c)=="Started")
 local at=f.logic.active.hitAt;workspace:SetAttribute("KuramaQAHitAt",at)
 task.wait(.1)
 local early=0;for _,hit in hits do if math.abs(hit.amount-expected)<.1 then early+=1 end end
 check("no M1 damage before contact",early==0)
 waitFor(function() return workspace:GetServerTimeNow()>at+.15 end,3,"impact")
 local basic={};for _,hit in hits do if math.abs(hit.amount-expected)<.1 then table.insert(basic,hit) end end
 check("one victim receives exactly one M1",#basic==1 and basic[1].victim==target)
 check("M1 matches authoritative contact time",basic[1].at>=at and basic[1].at-at<.15)
 workspace:SetAttribute("KuramaQAM1Damage",expected)
 waitFor(function() return f.logic.mode=="Idle" end,3,"recovery")
 local flank,fh,fr=dummy("KuramaQAFlank",Vector3.new(9,0,0));fr.CFrame=CFrame.lookAt(fr.Position,root.Position)
 check("normal melee reaches giant flank",table.find(Hitboxes.GetTargets(flank,fr,Config.Profiles.OrangeNinja),h)~=nil)
 local wall2=Instance.new("Part");wall2.Size=Vector3.new(.5,20,20);wall2.Anchored=true;wall2.CFrame=root.CFrame*CFrame.new(7,0,0);wall2.Parent=workspace
 check("flank still respects walls",table.find(Hitboxes.GetTargets(flank,fr,Config.Profiles.OrangeNinja),h)==nil);wall2:Destroy();flank:Destroy()
 tr.CFrame=root.CFrame*CFrame.new(0,0,-18.5);r2.CFrame=root.CFrame*CFrame.new(0,0,-19.2)
 local ally,ah=dummy("KuramaQAAlly",Vector3.new(0,0,-12),Teams.GetId(c))
 task.wait(.8);th.Health=10000;h2.Health=10000;ah.Health=10000
 local wave=nil;local vc=Kurama.Visual.Event:Connect(function(e) if e.character==c then wave=e end end)
 for _=1,1000 do Kurama.AttackStarted(p,true);task.wait(.01);if wave then break end end
 assert(wave,"proc roll did not succeed");task.wait(.1)
 check("proc visual uses exact 300 Warcraft radius",wave.radius==18.75)
 check("proc damage is caster max HP /25",math.abs((10000-th.Health)-h.MaxHealth/25)<.01)
 check("proc excludes beyond radius and allies",h2.Health==10000 and ah.Health==10000)
 workspace:SetAttribute("KuramaQAProcDamage",h.MaxHealth/25);vc:Disconnect();conn:Disconnect()
 target:Destroy();target2:Destroy();ally:Destroy()
 -- Keep the form available for manual camera and attack review, then trigger exit by attribute.
 workspace:SetAttribute("KuramaQAStatus","VisualReady")
 waitFor(function() return workspace:GetAttribute("KuramaQAFinish")==true end,600,"visual review")
 check("second swing starts",Combat.TryAttack(p,9002,c)=="Started")
 local nextAt=f.logic.nextAttackAt
 assert(Kurama.ObserveBuffRemoved(p,c:GetAttribute("LifeId"),match.roundId,c:GetAttribute("KuramaCastId")))
 waitFor(function() return c:GetAttribute("KuramaActive")==false end,3,"exit")
 check("exit restores original combat profile",f.profile==prior and f.profileId=="OrangeNinja")
 check("exit removes body and stat layer",not c:FindFirstChild("KuramaCombatBody") and c:GetAttribute("CombatBodyRadius")==nil and Stats.Get(p).AttackDamageBonus==baseline.AttackDamageBonus)
 check("exit cancels old swing and preserves cooldown",f.logic.active==nil and f.logic.buffered==nil and f.logic.nextAttackAt==nextAt)
 workspace:SetAttribute("KuramaQAStatus","PASS")
end,debug.traceback)
if not ok then workspace:SetAttribute("KuramaQAStatus","FAIL");workspace:SetAttribute("KuramaQAError",tostring(err));warn(err) end
