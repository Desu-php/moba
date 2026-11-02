--!strict
-- Standalone integration fixture. Only the Hagoromo360s wait is shortened here.
assert(game:GetService("RunService"):IsStudio())
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local services=game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match=require(services.MatchService)
local Teams=require(services.TeamService)
local Naruto=require(services.NarutoAbilityService)
local Ranged=require(services.NarutoRangedService)
local Ability=require(services.AbilityService)
local Progression=require(services.HeroProgressionService)
local Learning=require(RS.Shared.Abilities.SkillLearning)
local Gameplay=require(RS.Shared.Abilities.NarutoKcmGameplay)
local Fighters=require(services.FighterStateService)
local Damage=require(services.DamageService)
local originalHagoromo=Gameplay.updateHagoromo
local count=0
local function check(name:string,ok:boolean) assert(ok,name);count+=1;print("[RangedRuntimeTests] PASS "..name) end
local function waitFor(test:()->boolean,seconds:number,name:string)
 local deadline=os.clock()+seconds;repeat if test() then return end;task.wait(.02) until os.clock()>=deadline;error("Timeout "..name)
end
local bus=Instance.new("RemoteEvent");bus.Name="RangedQABus";bus.Parent=RS
local ready:{[Player]:boolean}={}
local replies:{[Player]:{serial:number,active:number,parts:number,counters:{number},panel:boolean}}={}
bus.OnServerEvent:Connect(function(p:Player,id:any,active:number,parts:number,counters:{number},panel:boolean)
 if id=="Ready" then ready[p]=true;return end
 replies[p]={serial=id,active=active,parts=parts,counters=counters,panel=panel}
end)
local ok,err=xpcall(function():string
 waitFor(function() return #Players:GetPlayers()==2 and Match.GetState()~=nil end,90,"clients")
 local match=Match.GetState();assert(match);match.phase="Preparing";match.preparationEnds=0
 waitFor(function() return match.phase=="InProgress" end,15,"match")
 match.startedAt=workspace:GetServerTimeNow()+10000;match.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(services.JungleService).Stop();require(RS.Shared.Config.TowerConfig).Range=0;require(services.TowerService).CancelAll()
 local a,b=table.unpack(Players:GetPlayers())
 waitFor(function() return ready[a]==true and ready[b]==true and a.Character~=nil and b.Character~=nil and Naruto.Get(a)~=nil and Naruto.Get(b)~=nil end,25,"runtime and VFX clients")
 local actor,other=a.Character :: Model,b.Character :: Model
 -- Actual engine regression: overlap orders share the original network baseline.
 local fighter=Fighters.Get(actor);assert(fighter)
 local networkRoot=fighter.root;assert(networkRoot:CanSetNetworkOwnership())
 local wasAuto,wasOwner=networkRoot:GetNetworkOwnershipAuto(),networkRoot:GetNetworkOwner()
 networkRoot:SetNetworkOwner(a)
 Fighters.LeaseNetworkOwnership(fighter,workspace:GetServerTimeNow()+.2)
 Fighters.StunSpell(fighter,.4)
 Fighters.ReleaseNetworkOwnership(fighter)
 check("lease-first release leaves stunned root server-owned",networkRoot:GetNetworkOwner()==nil)
 waitFor(function()return fighter.movement==nil end,1,"lease-first stun release")
 check("lease-first stun restores original owner",networkRoot:GetNetworkOwner()==a and not networkRoot:GetNetworkOwnershipAuto())
 Fighters.StunSpell(fighter,.1)
 Fighters.LeaseNetworkOwnership(fighter,workspace:GetServerTimeNow()+.5)
 waitFor(function()return fighter.movement==nil end,.4,"stun-first control release")
 check("stun ending cannot preempt active ranged lease",fighter.networkLease~=nil and networkRoot:GetNetworkOwner()==nil)
 waitFor(function()return fighter.networkLease==nil end,1,"shared lease expiry")
 check("last lease restores original owner once",networkRoot:GetNetworkOwner()==a and not networkRoot:GetNetworkOwnershipAuto())
 if wasAuto then networkRoot:SetNetworkOwnershipAuto() else networkRoot:SetNetworkOwner(wasOwner) end
 local floor=Instance.new("Part");floor.Name="RangedQAFloor";floor.Anchored=true;floor.Size=Vector3.new(300,2,300);floor.Position=Vector3.new(600,30,600);floor.Parent=workspace
 actor:PivotTo(CFrame.new(680,35,600));other:PivotTo(CFrame.new(520,35,600))
 for _,model in {actor,other} do local ff=model:FindFirstChildOfClass("ForceField");if ff then ff:Destroy() end end
 Progression.AddXP(a,100000);Progression.AddXP(b,100000)
 local pa,pb=Progression.Get(a),Progression.Get(b);assert(pa and pb)
 for _=1,3 do assert(Learning.learn(pa,"KCM"));assert(Learning.learn(pb,"KCM")) end
 Progression.Publish(a);Progression.Publish(b);task.wait(.4)
 local sa,sb=Naruto.Get(a),Naruto.Get(b);assert(sa and sb)
 local ids:{[Player]:number}={[a]=0,[b]=0}
 local function cast(p:Player,id:string,target:any):(boolean,string)
  ids[p]+=1;local model=p.Character;assert(model)
  if target~=nil then return Ability.HandleRequest(p,ids[p],model,id,target,match.roundId) end
  return Ability.HandleRequest(p,ids[p],model,id,match.roundId)
 end
 local point=Vector3.new(600,31,600)
 sa.pool.mana=sa.pool.maximum
 actor:SetAttribute("KcmActive",true);actor:SetAttribute("KcmRank",3);actor:SetAttribute("HagoromoUnlocked",true);actor:SetAttribute("RikudoRangedGranted",true)
 local accepted,reason=cast(a,"RikudoHY",point)
 check("replicated attributes cannot forge Rikudo grant",not accepted and reason=="Rikudo")
 actor:SetAttribute("KcmActive",false);actor:SetAttribute("KcmRank",0);actor:SetAttribute("HagoromoUnlocked",false)
 task.wait(.4)
 check("KCM3 still requires actual Hagoromo",not cast(a,"KCM",nil))
 -- Only fixture code shortens the existing360s deadline. Real alive1s cutscene remains.
 Gameplay.updateHagoromo=function(s:Gameplay.Hagoromo,now:number,level:number,alive:boolean):string?
  if level>=25 and not s.granted then s.deadline=math.min(s.deadline or now,now) end
  return originalHagoromo(s,now,level,alive)
 end
 waitFor(function() return actor:GetAttribute("HagoromoUnlocked")==true and other:GetAttribute("HagoromoUnlocked")==true end,4,"actual grant")
 Gameplay.updateHagoromo=originalHagoromo;task.wait(.2)
 check("rank3 A enters KCM",cast(a,"KCM",nil));check("rank3 B enters KCM",cast(b,"KCM",nil));task.wait(.6)
 waitFor(function() return actor:GetAttribute("RikudoRangedGranted")==true and other:GetAttribute("RikudoRangedGranted")==true end,2,"temporary grants")
 sa.pool.mana=1790
 accepted,reason=cast(a,"RikudoHY",point)
 check("insufficient ordinary mana denies without cooldown",not accepted and reason=="Mana" and (Ranged.Inspect(a) :: any).cooldowns.A0HY==nil)
 sa.pool.mana=sa.pool.maximum;sb.pool.mana=sb.pool.maximum;task.wait(.35)
 accepted,reason=cast(a,"RikudoHY",Vector3.new(1000,31,600))
 check("point range guard",not accepted and reason=="Range")
 task.wait(.35)
 local target=Instance.new("Model");target.Name="RangedNeutralVictim"
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Size=Vector3.new(2,3,2);root.Anchored=true;root.Position=Vector3.new(600,34,600);root.Parent=target;target.PrimaryPart=root
 local hp=Instance.new("Humanoid");hp.RequiresNeck=false;hp.MaxHealth=100000;hp.Health=100000;hp.Parent=target
 target:SetAttribute("EntityKind","Minion");target:SetAttribute("RoundId",match.roundId);target.Parent=workspace;Teams.RegisterNeutral(target);Fighters.GetOrCreate(target)
 local movable=target:Clone();movable.Name="RangedMovingNeutral";movable:PivotTo(CFrame.new(620,34,600))
 local movingRoot=movable:FindFirstChild("HumanoidRootPart") :: BasePart;movingRoot.Anchored=false;movable.Parent=workspace;movingRoot:SetNetworkOwner(nil);Teams.RegisterNeutral(movable);Fighters.GetOrCreate(movable)
 local beforeMotion=movingRoot.Position
 local damageCounts:{[Player]:number}={[a]=0,[b]=0};local events:{[Player]:number}={[a]=0,[b]=0};local motion=0;local initialDamage:number?=nil;local laterDamage:number?=nil
 local conn=Damage.Applied.Event:Connect(function(attacker:Model,victim:Model)
  if victim==target then local p=Players:GetPlayerFromCharacter(attacker);if p then damageCounts[p]=(damageCounts[p] or 0)+1 end end
 end)
 local eventConn=Ranged.Event.Event:Connect(function(p:Player,e:any)
  if e.kind=="Motion" then motion+=1 end
  if e.kind=="DamagePulse" then
   events[p]=(events[p] or 0)+1
   if p==a then if e.pulse==1 then initialDamage=e.damage elseif e.pulse==5 then actor:SetAttribute("StrengthBonus",40) elseif e.pulse==40 then laterDamage=e.damage end end
  end
 end)
 local manaA,manaB=sa.pool.mana,sb.pool.mana
 check("HY real network boundary",cast(a,"RikudoHY",point));check("HZ real network boundary",cast(b,"RikudoHZ",point))
 check("two separate1800 transactions",math.abs(sa.pool.mana-(manaA-1800))<.2 and math.abs(sb.pool.mana-(manaB-1800))<.2)
 accepted,reason=Ability.HandleRequest(a,ids[a],actor,"RikudoHY",point,match.roundId)
 check("replay rejected",not accepted and reason=="Replay")
 waitFor(function() return events[a]>=1 and events[b]>=1 end,4,"arrivals and real damage")
 bus:FireClient(a,1);bus:FireClient(b,1)
 waitFor(function() return replies[a]~=nil and replies[b]~=nil and replies[a].serial==1 and replies[b].serial==1 end,3,"VFX observations")
 check("both clients receive live procedural effects",replies[a].active>=2 and replies[b].active>=2 and replies[a].parts>0 and replies[b].parts>0)
 check("Rikudo panel visible",replies[a].panel and replies[b].panel)
 waitFor(function() return events[a]==58 and events[b]==7 end,6,"complete pulse sequences")
 check("seven or nine visuals never multiply victim damage",damageCounts[a]==58 and damageCounts[b]==7)
 check("HZ extra movement separately scheduled",motion==70)
 check("server displaces an unanchored neutral",((movingRoot.Position-beforeMotion)*Vector3.new(1,0,1)).Magnitude>.1)
 check("current STR changes later HY damage",initialDamage~=nil and laterDamage~=nil and laterDamage>initialDamage)
 task.wait(.3);bus:FireClient(a,2);bus:FireClient(b,2)
 waitFor(function() return replies[a].serial==2 and replies[b].serial==2 end,3,"completion VFX observations")
 check("client cleanup after completion",replies[a].active==0 and replies[a].parts==0 and replies[b].active==0 and replies[b].parts==0)
 local ra,rb=Ranged.Inspect(a),Ranged.Inspect(b);assert(ra and rb)
 check("completed states empty",next(ra.casts)==nil and next(rb.casts)==nil)
 -- Only fixture deadlines are advanced to test cancellation without waiting60s.
 ra.cooldowns.A0HY=0;rb.cooldowns.A0HY=0;sa.pool.mana=sa.pool.maximum;sb.pool.mana=sb.pool.maximum
 check("A cancellation cast admitted",cast(a,"RikudoHY",point));check("B death cast admitted",cast(b,"RikudoHY",point))
 check("manual KCM cancel admitted during preparation",cast(a,"KcmCancel",nil))
 local otherHp=other:FindFirstChildOfClass("Humanoid");assert(otherHp);otherHp.Health=0
 waitFor(function() return next(ra.casts)==nil and next(rb.casts)==nil end,2,"form exit and death cancellation")
 check("cooldown survives cancellation",(ra.cooldowns.A0HY or 0)>workspace:GetServerTimeNow()+55)
 Naruto.Reset();check("reset clears ranged cooldowns and casts",next(ra.cooldowns)==nil and next(rb.cooldowns)==nil and next(ra.casts)==nil)
 conn:Disconnect();eventConn:Disconnect();Teams.RemoveNeutral(movable);Fighters.Remove(movable);movable:Destroy();Teams.RemoveNeutral(target);Fighters.Remove(target);target:Destroy()
 print("[RangedRuntimeTests] ALL PASS "..count);return "passed"
end,function(message) return debug.traceback(tostring(message),2) end)
Gameplay.updateHagoromo=originalHagoromo
if not ok then warn("[RangedRuntimeTests] FAILED "..tostring(err)) end
