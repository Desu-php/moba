--!nocheck
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local A=require(S.SasukeAbilityService);local Summons=require(S.SasukeSummonService)
local D=require(S.DamageService);local F=require(S.FighterStateService);local Dev=require(S.DeveloperCommandService)
local Match=require(S.MatchService);local Stats=require(S.CharacterStatsService)
local created={};local count=0;local connection
workspace:SetAttribute("AodaEntonQA",nil)
local function now()return workspace:GetServerTimeNow()end
local function check(name,value)assert(value,name);count+=1;print("[AodaEntonQA] PASS "..name)end
local function waitFor(fn,seconds)local untilAt=os.clock()+seconds;repeat if fn()then return end;task.wait(.1)until os.clock()>untilAt;error("Wait timed out")end
local ok,err=xpcall(function()
 waitFor(function()return Match.GetState() and #game.Players:GetPlayers()>0 end,20)
 workspace:SetAttribute("DeveloperSoloMode",true);waitFor(function()return Match.GetState().phase=="InProgress" end,45)
 Match.GetState().nextWaveAt=now()+10000;require(S.MinionAIService).Reset();require(S.JungleService).Stop()
 require(game.ReplicatedStorage.Shared.Config.TowerConfig).Range=0;require(S.TowerService).CancelAll()
 local p=game.Players:GetPlayers()[1];p:SetAttribute("HeroId","Sasuke");p:LoadCharacterAsync()
 waitFor(function()return p.Character and string.find(p.Character:GetAttribute("HeroAppearanceVersion") or "","Sasuke") and require(S.NarutoAbilityService).Get(p) end,20)
 Dev.Execute(p,"level 30");Dev.Execute(p,"learnall");Dev.Execute(p,"nocd on");task.wait(.3);Dev.Execute(p,"refresh")
 local m=p.Character;local r=m.HumanoidRootPart
 for _,v in m:GetChildren()do if v:IsA("ForceField")then v:Destroy()end end
 r:SetNetworkOwner(nil);r.CFrame=CFrame.new(-275,36,0);r.AssemblyLinearVelocity=Vector3.zero;task.wait(.4)
 local home=r.CFrame
 local function body(name,offset,allied)
  local t=Instance.new("Model");t.Name=name
  local tr=Instance.new("Part");tr.Name="HumanoidRootPart";tr.Anchored=true;tr.CanCollide=false;tr.Size=Vector3.new(2,4,2);tr.CFrame=home*CFrame.new(offset);tr.Parent=t;t.PrimaryPart=tr
  local h=Instance.new("Humanoid");h.RequiresNeck=false;h.MaxHealth=50000;h.Health=50000;h.Parent=t
  t:SetAttribute("TeamId",if allied then p:GetAttribute("TeamId") else if p:GetAttribute("TeamId")=="Blue" then "Red" else "Blue")
  t:SetAttribute("EntityKind","Minion");t:SetAttribute("RoundId",Match.GetState().roundId);t.Parent=workspace;F.GetOrCreate(t);table.insert(created,t);return t
 end
 local ally=body("AodaQA_Ally",Vector3.new(8,0,0),true);local enemy=body("AodaQA_Enemy",Vector3.new(8,0,-8),false)
 local function cast(id,target)Dev.Execute(p,"refresh");return A.TryCast(p,id,1,now(),target)end
 check("bind requires adult summon",not cast("AodaBind",enemy))
 check("Aoda summoned",cast("Aoda",r.Position+Vector3.new(8,0,0)))
 local snake=Summons.Get(m);snake.attackAt=now()+10000;snake.poisonAt=now()+10000;snake.root.CFrame=ally.PrimaryPart.CFrame
 check("adult health",snake.h.MaxHealth==1500);check("adult source attack",snake.damage==101)
 check("adult armor fifteen",snake.model:GetAttribute("SummonArmor")==15)
 local scale=require(game.ReplicatedStorage.Shared.Config.ProgressionConfig).DefenseScale
 check("adult armor mitigates damage",math.abs(D.Apply(enemy,snake.h,100)-100*scale/(scale+15))<.001)
 snake.root.CFrame=ally.PrimaryPart.CFrame*CFrame.new(100,0,0)
 check("guard range measured from snake",not cast("AodaBind",ally) and snake.constrictAt==0)
 snake.root.CFrame=ally.PrimaryPart.CFrame
 check("ally guard command",cast("AodaBind",ally));local health=ally.Humanoid.Health
 check("guard reduces technique damage",math.abs(D.Apply(enemy,ally.Humanoid,100)-70)<.001)
 check("guard does not reduce attack",math.abs(D.Apply(enemy,ally.Humanoid,100,"Attack")-100)<.001)
 check("guard does not reduce pure",math.abs(D.Apply(enemy,ally.Humanoid,100,"Pure")-100)<.001)
 check("shared bind cooldown enforced",not cast("AodaBind",enemy) and not cast("AodaGuardSelf"))
 task.wait(.2);check("snake coils during guard",snake.channel~=nil and snake.model:GetAttribute("AodaConstrictUntil")>now())
 task.wait(3);check("guard expires",math.abs(D.Apply(enemy,ally.Humanoid,100)-100)<.001 and snake.channel==nil)
 snake.constrictAt=0;snake.root.CFrame=enemy.PrimaryPart.CFrame*CFrame.new(0,0,3);health=enemy.Humanoid.Health
 check("enemy constriction command",cast("AodaBind",enemy));task.wait(.7)
 check("constriction no immediate damage",enemy.Humanoid.Health==health)
 task.wait(.4);check("first constriction tick fifty",math.abs(health-enemy.Humanoid.Health-50)<.001)
 task.wait(2);check("five ticks total 250",math.abs(health-enemy.Humanoid.Health-250)<.001)
 check("constriction ends coil at three seconds",snake.channel==nil)
 task.wait(1);snake.constrictAt=0;snake.root.CFrame=ally.PrimaryPart.CFrame
 check("guard restart",cast("AodaBind",ally));F.StunSpell(F.GetOrCreate(snake.model),.4);task.wait(.2)
 check("stunning snake cancels guard",snake.channel==nil and math.abs(D.Apply(enemy,ally.Humanoid,100)-100)<.001)
 task.wait(.5);snake.constrictAt=0;snake.root.CFrame=ally.PrimaryPart.CFrame
 check("guard before despawn",cast("AodaBind",ally));Summons.Reset()
 check("despawn removes protection",math.abs(D.Apply(enemy,ally.Humanoid,100)-100)<.001)
 check("young Aoda spawn",Summons.Spawn(m,p,1,r.Position+Vector3.new(8,0,0)))
 snake=Summons.Get(m);check("young cannot constrict",not cast("AodaBind",enemy));check("young health and attack",snake.h.MaxHealth==500 and snake.damage==41)
 check("young armor ten",snake.model:GetAttribute("SummonArmor")==10);Summons.Reset()
 check("adult respawn",cast("Aoda",r.Position+Vector3.new(8,0,0)));snake=Summons.Get(m);snake.attackAt=now()+10000
 snake.root.CFrame=r.CFrame*CFrame.new(3,0,0);check("self guard command",cast("AodaGuardSelf"));check("self guard active",(m:GetAttribute("AodaGuardUntil") or 0)>now());Summons.Reset()
 local visuals={};connection=A.Visual.Event:Connect(function(e)table.insert(visuals,e)end)
 local function latest(id)for i=#visuals,1,-1 do if visuals[i].id==id then return visuals[i]end end end
 enemy.PrimaryPart.CFrame=home*CFrame.new(0,0,-25);r.CFrame=home
 check("Sharingan starts",cast("Sharingan"));check("Rinnegan starts",cast("Mangekyo"))
 health=enemy.Humanoid.Health;check("Enton accepted",cast("Enton",enemy.PrimaryPart.Position))
 check("Enton has no instant hit",enemy.Humanoid.Health==health);task.wait(.9)
 check("Enton uses moving weapon",latest("Projectile") and latest("Projectile").extra.spell=="EntonWeapon")
 check("Enton hits and burns",enemy.Humanoid.Health<health and latest("BlackBurn")~=nil)
 cast("Extinguish",enemy.PrimaryPart.Position);task.wait(.5)
 table.clear(visuals);health=enemy.Humanoid.Health
 check("Amaterasu starts combo",cast("Amaterasu",enemy.PrimaryPart.Position));task.wait(.1)
 check("Amaterasu warns before burning",enemy.Humanoid.Health==health and latest("AmaterasuWarning")~=nil)
 check("combo accepted",cast("Enton",enemy.PrimaryPart.Position));task.wait(.8)
 check("combo warning has no damage",enemy.Humanoid.Health==health and latest("EntonComboWarning")~=nil)
 task.wait(1.8);local expected=30*(26+.17*Stats.Get(p).Agility)
 check("combo source pulse total",math.abs(health-enemy.Humanoid.Health-expected)<.1)
 check("combo consumes ordinary area",latest("AreaEnd")~=nil)
 table.clear(visuals);check("Susanoo starts",cast("Susanoo"));task.wait(.3)
 r.CFrame=home;enemy.PrimaryPart.CFrame=home*CFrame.new(0,0,-25);health=enemy.Humanoid.Health
 check("Susanoo Enton accepted",cast("Enton",enemy.PrimaryPart.Position));task.wait(.9)
 check("Susanoo emits arrow",latest("Projectile") and latest("Projectile").extra.spell=="EntonArrow")
 check("arrow displaces enemy",enemy.PrimaryPart.Position.Z<home.Position.Z-25)
 check("arrow applies direct damage",health-enemy.Humanoid.Health>=300+3*Stats.Get(p).Agility)
 task.wait(1);table.clear(visuals);check("magatama accepted",cast("EntonMagatama",r.Position+r.CFrame.LookVector*40));task.wait(.2)
 local n=0;for _,v in visuals do if v.id=="Projectile" and v.extra.spell=="EntonMagatama"then n+=1 end end
 check("eight live magatama",n==8);task.wait(2);check("magatama leave patches",latest("Amaterasu")~=nil)
end,debug.traceback)
if connection then connection:Disconnect()end
Summons.Reset();for _,m in created do m:Destroy()end
workspace:SetAttribute("AodaEntonQA",if ok then "PASS" else tostring(err));workspace:SetAttribute("AodaEntonChecks",count)
print("[AodaEntonQA]",if ok then "PASS" else "FAIL",count,err);script:Destroy()
