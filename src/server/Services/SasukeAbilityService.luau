--!strict
-- Server-owned casts. Imported assets contain visual data only, never executable code.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local D=require(Shared.Abilities.SasukeDefinitions)
local Presentation=require(Shared.Abilities.SasukePresentation)
local Fire=require(script.Parent.SasukeFireService)
local Advanced=require(script.Parent.SasukeAdvancedService)
local Rules=require(Shared.Abilities.SasukeRules)
local Units=require(Shared.Abilities.WorldUnits)
local Stats=require(script.Parent.CharacterStatsService)
local Progress=require(script.Parent.HeroProgressionService)
local Resource=require(script.Parent.NarutoAbilityService)
local Damage=require(script.Parent.DamageService)
local Fighters=require(script.Parent.FighterStateService)
local Combat=require(script.Parent.CombatService)
local Service={Visual=Instance.new("BindableEvent")}
local sessions:{[Player]:any}={}
local actors:{[Model]:Humanoid}={}
local areas:{any}={}
local shots:{any}={}
local gravityAffected:{[Model]:boolean}={}
local started=false
local shotSerial=0
local areaSerial=0
local function clock():number return workspace:GetServerTimeNow() end
local function root(model:Model):BasePart? local r=model:FindFirstChild("HumanoidRootPart");return if r and r:IsA("BasePart") then r else nil end
local function valid(s:any):boolean return s.model==s.player.Character and s.model.Parent~=nil and Damage.CanAct(s.model) end
local function emit(s:any,id:string,position:Vector3,radius:number,duration:number,extra:any?)
 Service.Visual:Fire({kind="Sasuke",id=id,character=s.model,position=position,radius=radius,duration=duration,extra=extra,at=clock()})
end
local function session(player:Player):any
 local s=sessions[player]
 if not s or s.model~=player.Character then
  s={player=player,model=player.Character,ready={},mode=0,form=0,formUntil=0,held=false,heldUntil=0,readyAt=0,variant="Chidori",kirinAt=0,kirinUntil=0,kirinDamage=0,boosts=0,spheres={},sphereUntil=0,beasts=0,absorbed={},garuda=false,katanaUntil=0,nextTick=clock(),used={},pendingUntil=0}
  sessions[player]=s
 end
 return s
end
function Service.Ready(player:Player):{[string]:number} local s=sessions[player];return if s then s.ready else {} end
local function publish(s:any)
 local m=s.model;if not m or not m.Parent then return end
 m:SetAttribute("SasukeMode",s.mode);m:SetAttribute("SusanooForm",s.form)
 m:SetAttribute("ChidoriHeld",s.held);m:SetAttribute("ChidoriReadyAt",s.readyAt);m:SetAttribute("ChidoriVariant",s.variant)
 m:SetAttribute("KirinReadyAt",s.kirinAt);m:SetAttribute("KirinUntil",s.kirinUntil)
 m:SetAttribute("ChibakuCount",#s.spheres);m:SetAttribute("SasukeBijuu",s.beasts);m:SetAttribute("GarudaActive",s.garuda)
 m:SetAttribute("SasukeCastUntil",s.pendingUntil);m:SetAttribute("AmenotejikaraSelectingUntil",if s.amenoTarget then s.amenoUntil else 0)
 for id in D.Spells do
  local summon=if id=="AodaBind" or id=="AodaGuardSelf" then require(script.Parent.SasukeSummonService).Get(m) else nil
  m:SetAttribute("Ready_"..id,if summon then summon.constrictAt else s.ready[D.cooldownKey(id)] or 0)
 end
end
local function form(s:any,value:number,untilAt:number)
 if s.form~=value then s.model:SetAttribute("SusanooFormAt",clock()) end
 s.form=value;s.formUntil=untilAt
 local stats=Stats.Get(s.player)
 Stats.SetLayer(s.model,"SasukeForm",if value==0 then nil else {health=if value==3 then 600 elseif value==4 then math.min(2000,200+200*s.beasts) else 0,armor=if value>=3 then 90 else 0,attack=if value>=3 then 300 elseif value==2 then .5*stats.Agility else .2*stats.Agility,speed=if value>=3 then Units.toStuds(100) else 0})
 local f=Fighters.GetOrCreate(s.model);if f then Fighters.SetAttackProfile(f,if value>=3 then "SasukeSusanoo" else "Sasuke") end
 publish(s)
end
local Enton=require(script.Parent.SasukeEntonService)
local Summons=require(script.Parent.SasukeSummonService)
local function off(s:any)
 Enton.Cancel(s);s.amaterasuComboUntil=0
 Advanced.Cancel(s);s.amenoTarget=nil;s.amenoBonusUntil=0
 Fire.Cancel(s,clock());s.model:SetAttribute("AmaterasuCoatingUntil",0)
 if s.blackArea then s.blackArea.controlUntil=0 end;s.model:SetAttribute("AmaterasuControlUntil",0)
 s.mode=0;s.garuda=false;s.model:SetAttribute("GarudaActive",false);s.held=false;s.spheres={};s.sphereGoal=nil
 s.technique=nil;s.pendingUntil=0
 local f=Fighters.Get(s.model);if f then Fighters.LockCast(f,0) end
 emit(s,"ChibakuEnd",s.model:GetPivot().Position,0,.1)
 local humanoid=s.model:FindFirstChildOfClass("Humanoid");if humanoid and s.groundHip then humanoid.HipHeight=s.groundHip end
 Stats.SetLayer(s.model,"SasukeFlight",nil);form(s,0,0)
end
local function hurt(s:any,target:Model,amount:number,stun:number?):number
 local h=actors[target] or target:FindFirstChildOfClass("Humanoid");if not h then return 0 end
 local dealt=Damage.Apply(s.model,h,amount)
 if dealt>0 and stun and stun>0 then local f=Fighters.GetOrCreate(target);if f then Fighters.StunSpell(f,stun) end end
 return dealt
end
local function inArea(s:any,point:Vector3,radius:number,amount:number,stun:number?,seen:{[Model]:boolean}?)
 for model in actors do local r=root(model)
  if r and (r.Position-point).Magnitude<=radius and Damage.CanDamage(s.model,model) and (not seen or not seen[model]) then
   if seen then seen[model]=true end;hurt(s,model,amount,stun)
  end
 end
end
local function area(s:any,id:string,point:Vector3,radius:number,total:number,duration:number,follow:boolean?)
 if id=="Amaterasu" then Fire.Area(s,point,radius,total,clock(),follow);return end
 areaSerial+=1
 table.insert(areas,{s=s,id=id,serial=areaSerial,point=point,radius=radius,damage=total/math.max(1,math.ceil(duration/.5)),ticks=math.max(1,math.ceil(duration/.5)),next=clock()+.5,follow=follow})
 emit(s,id,point,radius,duration,{follow=follow,areaSerial=areaSerial})
end
local function terrain(s:any,ignore:Model?):RaycastParams
 local p=RaycastParams.new();local list:{Instance}={s.model}
 for model in actors do table.insert(list,model) end
 if ignore then table.insert(list,ignore) end
 p.FilterDescendantsInstances=list;p.RespectCanCollide=true;return p
end
local function destination(s:any,point:Vector3,model:Model?):CFrame?
 local m=model or s.model;local r=root(m);local h=m:FindFirstChildOfClass("Humanoid");if not r or not h then return nil end
 local p=terrain(s,m);local hit=workspace:Raycast(point+Vector3.new(0,8,0),Vector3.new(0,-24,0),p)
 if not hit or hit.Normal.Y<.7 then return nil end
 local cf=CFrame.new(hit.Position+Vector3.new(0,h.HipHeight+r.Size.Y/2+.1,0))*r.CFrame.Rotation
 local overlap=OverlapParams.new();overlap.FilterDescendantsInstances=p.FilterDescendantsInstances;overlap.RespectCanCollide=true
 local height=math.min(4.5,2*h.HipHeight+r.Size.Y)
 if #workspace:GetPartBoundsInBox(cf,Vector3.new(3,height,3),overlap)>0 then return nil end
 return cf
end
local function later(s:any,delay:number,callback:()->())
 local model=s.model;task.delay(delay,function() if s.model==model and valid(s) then callback() end end)
end
local function charge(s:any,id:string,now:number)
 s.held=true;s.variant=id;s.readyAt=now+.8;s.heldUntil=now+15
 emit(s,"Charge",s.model:GetPivot().Position,1,.8);publish(s)
end
local function projectile(s:any,id:string,point:Vector3,speed:number,radius:number,amount:number,burn:number?,stun:number?,origin:Vector3?)
 local r=root(s.model);if not r then return end
 local from=origin or r.Position+r.CFrame.LookVector*2;local direction=point-from
 if direction.Magnitude<.1 then direction=r.CFrame.LookVector end
 local distance=math.min(direction.Magnitude,Units.toStuds(D.Spells[id].range))
 local endPoint=from+direction.Unit*distance
 shotSerial+=1
 table.insert(shots,{serial=shotSerial,s=s,id=id,point=from,finish=endPoint,direction=direction.Unit,remaining=distance,speed=speed,radius=radius,damage=amount,burn=burn,stun=stun,single=id=="ChidoriSenbon"})
 emit(s,"Projectile",from,radius,distance/speed,{finish=endPoint,spell=id,serial=shotSerial})
end
Fire.Configure({emit=emit,hurt=hurt,canDamage=Damage.CanDamage,actors=actors,terrain=terrain,root=root,valid=valid,resource=Resource.Get,fighter=Fighters.GetOrCreate})
Advanced.Configure({emit=emit,hurt=hurt,canDamage=Damage.CanDamage,actors=actors,terrain=terrain,root=root,valid=valid,stats=Stats.Get,fighter=Fighters.GetOrCreate,lease=Fighters.LeaseNetworkOwnership,lock=Fighters.LockCast})
Enton.Configure({emit=emit,hurt=hurt,canDamage=Damage.CanDamage,actors=actors,terrain=terrain,root=root,valid=valid,fire=Fire,fighter=Fighters.GetOrCreate,lease=Fighters.LeaseNetworkOwnership,lock=Fighters.LockCast})
function Service.TryCast(player:Player,id:string,_request:number,now:number,target:any):(boolean,string)
 local d=D.Spells[id];local profile=Progress.Get(player);local r=if player.Character then root(player.Character) else nil
 if not d or not profile or not r or player:GetAttribute("HeroId")~="Sasuke" then return false,"Unavailable" end
 local s=session(player);local pool=Resource.Get(player);if not pool or not valid(s) then return false,"Unavailable" end
 local f=Fighters.GetOrCreate(s.model);if not f or f.logic.mode=="Stunned" or (f.sleep and f.sleep.active) then return false,"Контроль" end
 local rank=profile.Learned[d.line] or 0
 local reason=Rules.reason(id,{rank=rank,mode=s.mode,held=s.held,readyAt=s.readyAt,now=now,form=s.form,kirinAt=s.kirinAt,kirinUntil=s.kirinUntil,spheres=#s.spheres,beasts=s.beasts,garuda=s.garuda})
 if reason then return false,reason end
 if id=="AodaBind" or id=="AodaGuardSelf" then
  local chosen=if id=="AodaGuardSelf" then s.model else target
  if typeof(chosen)~="Instance" or not (chosen :: Instance):IsA("Model") then return false,"Выберите союзника или врага" end
  return Summons.Command(s.model,chosen :: Model,now)
 end
 if s.pendingUntil>now and id~="KirinBoost" and id~="SasukeModeOff" then return false,"Подготовка" end
 local steering=id=="Amaterasu" and s.blackArea and now<s.blackArea.controlUntil
 local noCD=Run:IsStudio() and player:GetAttribute("DeveloperNoCooldown")==true
 local secondAmeno=id=="Amenotejikara" and s.amenoTarget~=nil and s.amenoUntil>now
 local toggle=(id=="Sharingan" and s.mode>0) or (id=="Garuda" and s.garuda) or (id=="SusanooRibs" and s.form==1)
 local key=D.cooldownKey(id)
 if not noCD and not steering and not secondAmeno and not toggle and (s.ready[key] or 0)>now then return false,"Способность восстанавливается" end
 if s.used[id] then return false,"Один раз за форму" end
 local point=r.Position;local victim:Model?=nil
 if d.target~="Self" then
  if typeof(target)=="Vector3" and d.target~="Enemy" then point=target
  elseif typeof(target)=="Instance" and (target :: Instance):IsA("Model") and d.target~="Point" and Damage.CanDamage(s.model,target) then
   if (target :: Model):FindFirstChildOfClass("ForceField") then return false,"Цель защищена" end
   victim=target;local tr=root(target);if not tr then return false,"Недоступная цель" end;point=tr.Position
  else return false,"Нужна цель" end
  local range=Units.toStuds(if id=="SasukeGenjutsu" and s.mode==3 then 500 else d.range)
  if point.X~=point.X or point.Y~=point.Y or point.Z~=point.Z or (point-r.Position).Magnitude>range+1 then return false,"Слишком далеко" end
 end
 if steering then Fire.Steer(s,point,now);return true,"Cast" end
 if id=="Kirin" and victim then local kind=(victim :: Model):GetAttribute("EntityKind");if kind=="Tower" or kind=="Core" or kind=="Structure" then return false,"Выберите бойца" end end
 local teleport:CFrame?=nil;local swapOther:CFrame?=nil
 if id=="Amenotejikara" then
  if secondAmeno and victim then
   teleport=destination(s,point);swapOther=destination(s,r.Position,victim)
   if not teleport or not swapOther then return false,"Нет свободной поверхности" end
  elseif secondAmeno then
   local selected=s.amenoTarget;local tr=if selected.Parent then root(selected) else nil
   if not tr or not Damage.CanDamage(s.model,selected) or selected:FindFirstChildOfClass("ForceField") or (tr.Position-r.Position).Magnitude>Units.toStuds(900) or (point-tr.Position).Magnitude>Units.toStuds(900) then return false,"Цель вышла из радиуса переноса" end
   teleport=destination(s,point,selected);if not teleport then return false,"Нет свободной поверхности" end
  elseif not victim then
   local delta=point-r.Position;if delta.Magnitude>Units.toStuds(900) then point=r.Position+delta.Unit*Units.toStuds(900) end
   teleport=destination(s,point);if not teleport then return false,"Нет свободной поверхности" end
  end
 end
 if id=="Garuda" and not s.garuda then
  if profile.Level<13 then return false,"Гаруда доступна с 13 уровня" end
  if s.mode>0 or s.held then return false,"Завершите додзюцу и Чидори перед полётом" end
 end
 if id=="ChidoriEiso" and workspace:Raycast(r.Position,point-r.Position,terrain(s)) then return false,"Цель за препятствием" end
 if id=="ChakraAbsorb" then return false,"В этой версии поля боя нет источников чакры хвостатых" end
 if id=="PerfectSusanoo" then return false,"Сначала нужен источник чакры хвостатого" end
 if id=="KirinBoost" and s.boosts>=2 then return false,"Гроза уже усилена дважды" end
 local cost=if secondAmeno or toggle or id=="SasukeModeOff" then 0 else D.cost(id,rank)
 if id=="CompleteSusanoo" then cost+=pool.pool.maximum*.25 end
 if pool.pool.mana<cost then return false,"Недостаточно чакры" end
 pool.pool.mana-=cost;pool.nextPublish=0
 if not secondAmeno then s.ready[key]=now+(if noCD then 0 else D.cooldown(id,rank)) end
 local stats=Stats.Get(player);local agi,level,strength=stats.Agility,stats.Level,stats.Strength
 local radius=Units.toStuds(d.radius)
 if id=="SasukeModeOff" then off(s)
 elseif id=="Sharingan" then if s.mode>0 then off(s) else s.mode=1 end
 elseif id=="Mangekyo" then s.mode=if s.mode>=2 then 1 elseif rank==5 then 3 else 2;if s.mode==1 then form(s,0,0) end
 elseif id=="SusanooRibs" then form(s,if s.form==1 then 0 else 1,0)
 elseif id=="Susanoo" then form(s,2,now+30)
 elseif id=="CompleteSusanoo" then
  s.pendingUntil=now+3;emit(s,"Transform",r.Position,7,3)
  s.technique={id=id,readyAt=now+3,life=s.model:GetAttribute("LifeId"),round=s.model:GetAttribute("RoundId")};Fighters.LockCast(f,s.pendingUntil)
 elseif id=="Chidori" or id=="SusanooChidori" then charge(s,id,now)
 elseif id=="OnyxChidori" or id=="AmaterasuChidori" then s.variant=id
 elseif id=="ChidoriKatana" then s.katanaUntil=now+20;s.model:SetAttribute("SasukeKatanaUntil",s.katanaUntil);Stats.RecalculateStats(player);emit(s,"Katana",r.Position,1,20)
 elseif id=="ChidoriNagashi" then
  Stats.SetLayer(s.model,"SasukeNagashi",{health=0,armor=100,attack=0,speed=0});s.nagashiUntil=now+4
  s.nagashiTick=now+.05;emit(s,"Nagashi",r.Position,radius,4,{follow=true})
 elseif id=="ChidoriSenbon" then
  s.held=false;local delta=(point-r.Position)*Vector3.new(1,0,1);local aim=if delta.Magnitude>.01 then CFrame.lookAt(r.Position,r.Position+delta) else r.CFrame
  for _=1,8 do
   local dir=(aim*CFrame.Angles(0,math.rad(-80+math.random()*160),0)).LookVector
   local from=r.Position+dir*Units.toStuds(50+math.random()*70)
   if workspace:Raycast(r.Position,from-r.Position,terrain(s)) then from=r.Position end
   projectile(s,id,point,90,.7,15+.5*agi,nil,nil,from)
  end
 elseif id=="ChidoriEiso" then
  s.held=false;s.pendingUntil=now+1.25
  s.technique={id=id,target=victim,hitAt=now+.75,damage=380+3*agi,round=s.model:GetAttribute("RoundId"),life=s.model:GetAttribute("LifeId"),targetLife=(victim :: Model):GetAttribute("LifeId")}
  Fighters.LockCast(f,s.pendingUntil)
  emit(s,"Charge",r.Position,1,.75)
 elseif id=="SasukeFireball" or id=="PhoenixFlowers" then Fire.Cast(s,id,point,rank,agi,now)
 elseif id=="KirinPrepare" then s.kirinAt=now+4.5;s.kirinUntil=now+19.5;s.kirinDamage=100+30*level+3*strength;s.boosts=0;emit(s,"KirinPrepare",r.Position,4,4.5)
 elseif id=="KirinBoost" then s.boosts+=1;s.kirinDamage+=100+strength;emit(s,"KirinPrepare",r.Position,4,1)
 elseif id=="Kirin" then
  local amount=s.kirinDamage;s.kirinUntil=0;Advanced.Kirin(s,victim :: Model,amount,now)
 elseif id=="Amaterasu" then
  Fire.Area(s,point,radius,800+5*agi,now,false,true);s.amaterasuComboUntil=now+1;s.amaterasuPoint=point
  s.model:SetAttribute("EntonComboUntil",now+1)
 elseif id=="AmaterasuWall" then
  if s.form==1 then Fire.Coat(s,now) else Fire.Area(s,point,radius,800+5*agi,now,true) end
 elseif id=="EntonMagatama" then Enton.Cast(s,point,agi,now,true)
 elseif id=="Enton" then
  Enton.Cast(s,point,agi,now)
 elseif id=="Extinguish" then
  Fire.Extinguish(point,radius);emit(s,"Extinguish",point,radius,.4)
 elseif id=="EntonPull" then
  Advanced.Pull(s,now,agi)
 elseif id=="SasukeGenjutsu" and victim then
  local vf=Fighters.GetOrCreate(victim)
  if vf then
   Fighters.Sleep(vf,now)
   if vf.sleep then
    vf.sleep.untilAt=now+(if s.mode>=2 then 4 else 3)
    vf.sleep.wakeSlowDuration=if s.mode==3 then 6 else nil
    (victim :: Model):SetAttribute("SleepUntil",vf.sleep.untilAt);(victim :: Model):SetAttribute("SasukeGenjutsuUntil",vf.sleep.untilAt)
   end
  end
  emit(s,"Genjutsu",point,2,1,{rinnegan=s.mode==3})
 elseif id=="Amenotejikara" then
  if secondAmeno then
   if victim and teleport and swapOther then s.model:PivotTo(teleport);(victim :: Model):PivotTo(swapOther)
   elseif teleport then s.amenoTarget:PivotTo(teleport) end
   s.amenoTarget=nil
  elseif victim then s.amenoTarget=victim;s.amenoUntil=now+4
  elseif teleport then s.model:PivotTo(teleport);s.amenoBonusUntil=now+1 end
  emit(s,"Teleport",point,3,.5)
 elseif id=="ChibakuTensei" then
  s.spheres={};s.sphereGoal=nil;s.sphereUntil=now+30;s.pendingUntil=now+3
  s.technique={id=id,origin=r.Position,spawnAt=now+1,readyAt=now+3,round=s.model:GetAttribute("RoundId"),life=s.model:GetAttribute("LifeId")}
  Fighters.LockCast(f,s.pendingUntil);emit(s,"ChibakuEnd",r.Position,0,.1)
 elseif id=="ChibakuMove" then
  local center=Vector3.zero;for _,p in s.spheres do center+=p end;center/=#s.spheres
  local movement=point-center;s.sphereGoal={};for i,p in s.spheres do s.sphereGoal[i]=p+movement end
  emit(s,"ChibakuMove",point,Units.toStuds(400),movement.Magnitude/Units.toStuds(500),{points=s.sphereGoal})
 elseif id=="ChibakuDrop" then
  local points=s.spheres;s.spheres={};s.sphereGoal=nil;emit(s,"ChibakuDrop",r.Position,radius,.9,{points=points})
  later(s,.9,function() local seen={};for _,p in points do inArea(s,p,radius,400+3*agi,nil,seen);emit(s,"ChibakuImpact",p,radius,.6) end end)
 elseif id=="Aoda" then
  local ok=require(script.Parent.SasukeSummonService).Spawn(s.model,player,rank,point)
  if not ok then pool.pool.mana+=cost;s.ready[key]=now;return false,"Нет места для призыва" end
  emit(s,"Summon",point,3,.7)
 elseif id=="Garuda" then
  s.garuda=not s.garuda;local humanoid=s.model:FindFirstChildOfClass("Humanoid");if humanoid then s.groundHip=s.groundHip or humanoid.HipHeight;humanoid.HipHeight=s.groundHip+(if s.garuda then 4 else 0) end
  s.model:SetAttribute("GarudaActive",s.garuda);Stats.SetLayer(s.model,"SasukeFlight",nil);Stats.RecalculateStats(player)
  emit(s,"Summon",r.Position,3,.7)
 elseif id=="SusanooTriple" or id=="IndraArrow" then
  s.used[id]=true;local amount=if id=="SusanooTriple" then 600+3*agi elseif s.beasts>=7 then 800+5*agi else 700+4*agi
  s.pendingUntil=now+1.5;emit(s,"KirinWarning",point,radius,1.5)
  later(s,1.5,function() projectile(s,id,point,Units.toStuds(750),radius,amount) end)
 end
 local duration=Presentation.Casts[id]
 if s.enton then duration=(s.pendingUntil :: number)-now end
 if duration then s.model:SetAttribute("SasukeCastPose",id);s.model:SetAttribute("SasukeCastPoseAt",now);s.model:SetAttribute("SasukeCastPoseUntil",now+duration) end
 publish(s);return true,"Cast"
end
function Service.Reset()
 Fire.Reset();Advanced.Reset();Enton.Reset()
 for _,s in sessions do if s.model and s.model.Parent then off(s) end end
 table.clear(sessions);table.clear(areas);table.clear(shots)
 require(script.Parent.SasukeSummonService).Reset()
end
function Service.Update(now:number)
 local slowed:{[Model]:boolean}={}
 for player,s in sessions do
  if not valid(s) then
   if s.model and s.model.Parent then off(s);Stats.SetLayer(s.model,"SasukeKatana",nil);Stats.SetLayer(s.model,"SasukeNagashi",nil) end
   sessions[player]=nil;continue
  end
  local dt=math.clamp(now-s.nextTick,0,.5);s.nextTick=now
  local pool=Resource.Get(player)
  if pool then
   local drain=(if s.mode>0 then 10 else 0)+(if s.mode>=2 then 2 else 0)+(if s.form==1 then 4 else 0)+(if s.garuda then pool.pool.maximum*.017 else 0)
   pool.pool.mana=math.max(0,pool.pool.mana-drain*dt)
   if pool.pool.mana<=0 and drain>0 then off(s) end
  end
  Fire.UpdateCast(s,now)
  Enton.UpdateCast(s,now)
  Advanced.UpdateCast(s,now);Advanced.Nagashi(s,now)
  local cast=s.technique
  if cast then
   local f=Fighters.Get(s.model)
   if not f or f.logic.mode=="Stunned" or (f.sleep and f.sleep.active) or cast.life~=s.model:GetAttribute("LifeId") or cast.round~=s.model:GetAttribute("RoundId") then
    s.technique=nil;s.pendingUntil=0;if f then Fighters.LockCast(f,0) end
    if cast.id=="ChibakuTensei" then s.spheres={};s.sphereGoal=nil;emit(s,"ChibakuEnd",cast.origin,0,.1) end
   elseif cast.id=="CompleteSusanoo" and now>=cast.readyAt then
    s.technique=nil;if s.mode>=2 then form(s,3,now+30);s.used={} end
   elseif cast.id=="ChidoriEiso" and now>=cast.hitAt then
    s.technique=nil
    local target=cast.target;local tr=if target.Parent then root(target) else nil;local own=root(s.model)
    if tr and own and Damage.CanDamage(s.model,target) and not target:FindFirstChildOfClass("ForceField") and cast.targetLife==target:GetAttribute("LifeId") then
     local delta=tr.Position-own.Position
     if delta.Magnitude<=Units.toStuds(600)+1 and not workspace:Raycast(own.Position,delta,terrain(s)) then
      hurt(s,target,cast.damage,2);emit(s,"Eiso",own.Position,.3,.5,{finish=tr.Position,target=target})
     end
    end
   elseif cast.id=="ChibakuTensei" then
    if not cast.spawned and now>=cast.spawnAt then
     cast.spawned=true
     for i=1,9 do local angle=i*math.pi*2/9
      table.insert(s.spheres,cast.origin+Vector3.new(math.cos(angle),0,math.sin(angle))*Units.toStuds(400+math.random()*600))
     end
     emit(s,"Chibaku",cast.origin,Units.toStuds(1000),math.max(.1,s.sphereUntil-now),{points=table.clone(s.spheres),rise=2})
    end
    if now>=cast.readyAt then s.technique=nil end
   end
  end
  if s.form~=1 then s.model:SetAttribute("AmaterasuCoatingUntil",0) end
  if s.blackArea then s.model:SetAttribute("AmaterasuControlUntil",s.blackArea.controlUntil) end
  if s.held and now>=s.heldUntil then s.held=false end
  if s.formUntil>0 and now>=s.formUntil then form(s,0,0);s.used={} end
  if s.katanaUntil>0 and now>=s.katanaUntil then s.katanaUntil=0;s.model:SetAttribute("SasukeKatanaUntil",nil);Stats.RecalculateStats(player) end
  if s.nagashiUntil and now>=s.nagashiUntil then s.nagashiUntil=nil;Stats.SetLayer(s.model,"SasukeNagashi",nil) end
  if #s.spheres>0 and now>=s.sphereUntil then s.spheres={};s.sphereGoal=nil;emit(s,"ChibakuEnd",s.model:GetPivot().Position,0,.1) end
  if s.sphereGoal then for i,point in s.spheres do local delta=s.sphereGoal[i]-point;local length=delta.Magnitude;if length>.01 then s.spheres[i]=point+delta.Unit*math.min(length,Units.toStuds(500)*dt) end end end
  if #s.spheres>0 then for target in actors do local tr=root(target)
   if tr and Damage.CanDamage(s.model,target) then for _,point in s.spheres do
    if (tr.Position-point).Magnitude<=Units.toStuds(500) then slowed[target]=true;break end
   end end
  end end
  if s.amenoTarget and now>=s.amenoUntil then s.amenoTarget=nil end
  publish(s)
 end
 for target in slowed do target:SetAttribute("GravitySlowUntil",now+.3);if not gravityAffected[target] then Fighters.SetWalkSpeed(target,Fighters.GetWalkSpeed(target)) end end
 for target in gravityAffected do if not slowed[target] and target.Parent then target:SetAttribute("GravitySlowUntil",nil);Fighters.SetWalkSpeed(target,Fighters.GetWalkSpeed(target)) end end
 gravityAffected=slowed
 for i=#areas,1,-1 do local a=areas[i]
  if not valid(a.s) or a.ticks<=0 then emit(a.s,"AreaEnd",a.point,a.radius,.1,{areaSerial=a.serial});table.remove(areas,i);continue end
  if now>=a.next then a.next+=.5;a.ticks-=1;if a.follow and root(a.s.model) then a.point=a.s.model:GetPivot().Position end;inArea(a.s,a.point,a.radius,a.damage) end
 end
 Fire.Update(now);Advanced.Update(now);Enton.Update(now)
 local dt=math.clamp(now-(Service :: any).lastUpdate,0,.1);(Service :: any).lastUpdate=now
 for i=#shots,1,-1 do local shot=shots[i]
  if not valid(shot.s) then table.remove(shots,i);continue end
  local step=math.min(shot.remaining,shot.speed*dt);local travel=shot.direction*step
  local params=terrain(shot.s);local wall=workspace:Raycast(shot.point,travel,params)
  local finish=if wall then wall.Position else shot.point+travel
  local contact:Model?=nil;local firstT=math.huge
  for model in actors do local tr=root(model)
   if tr and Damage.CanDamage(shot.s.model,model) then
    local delta=finish-shot.point;local t=if delta.Magnitude>.001 then math.clamp((tr.Position-shot.point):Dot(delta)/delta:Dot(delta),0,1) else 0
    if (tr.Position-shot.point-delta*t).Magnitude<=math.min(shot.radius,2)+1.5 and t<firstT then contact=model;firstT=t end
   end
  end
  if contact then finish=shot.point+(finish-shot.point)*firstT end
  shot.point=finish;shot.remaining-=step
  if contact or wall or shot.remaining<=.01 then
   local seen={};if contact then seen[contact]=true;hurt(shot.s,contact,shot.damage,shot.stun) end
   if not shot.single then inArea(shot.s,finish,shot.radius,shot.damage,shot.stun,seen) end
   emit(shot.s,"Impact",finish,shot.radius,.5,{spell=shot.id,serial=shot.serial})
   if shot.burn then area(shot.s,"Fire",finish,shot.radius,shot.burn,3) end
   table.remove(shots,i)
  end
 end
 require(script.Parent.SasukeSummonService).Update(now,dt)
end
function Service.Start()
 if started then return end;started=true;(Service :: any).lastUpdate=clock()
 local function add(item:Instance) if item:IsA("Humanoid") and item.Parent and item.Parent:IsA("Model") then actors[item.Parent]=item end end
 for _,item in workspace:GetDescendants() do add(item) end
 workspace.DescendantAdded:Connect(add);workspace.DescendantRemoving:Connect(function(item) if item:IsA("Humanoid") and item.Parent and item.Parent:IsA("Model") then actors[item.Parent]=nil end end)
 Players.PlayerRemoving:Connect(function(player) sessions[player]=nil end)
 Combat.AttackStarted.Event:Connect(function(f:Fighters.Fighter,target:Model?)
  local p=f.player;local s=if p then sessions[p] else nil
  if not p or not s or not target or not Damage.CanDamage(s.model,target) or target:FindFirstChildOfClass("ForceField") then return end
  local kind=target:GetAttribute("EntityKind");local unit=kind~="Tower" and kind~="Core" and kind~="Structure";local now=clock();local stats=Stats.Get(p)
  if unit then
   if (s.amenoBonusUntil or 0)>now then s.amenoBonusUntil=0;hurt(s,target,(if s.katanaUntil>now then 200 else 50)+stats.Agility) end
   if s.katanaUntil>now and (s.katanaProcAt or 0)<=now and math.random()<.14 then s.katanaProcAt=now+.3;local tf=Fighters.GetOrCreate(target);if tf then Fighters.StunSpell(tf,1) end end
   if s.form>=3 then hurt(s,target,stats.Agility);Advanced.Wave(s,target,now);return end
  end
  if s.mode==0 then return end
  local data=Progress.Get(p);local rank=if data then data.Learned.SasukeEyes or 0 else 0
  if rank<1 or math.random(1,100)>15+3*rank then return end
  local tr=root(target);if not tr then return end
  local from=f.root.Position;local start=math.random()*math.pi*2
  for i=0,7 do
   local angle=start+i*math.pi/4
   local cf=destination(s,tr.Position+Vector3.new(math.cos(angle),0,math.sin(angle))*Units.toStuds(70))
   if cf then
    s.model:PivotTo(CFrame.lookAt(cf.Position,Vector3.new(tr.Position.X,cf.Position.Y,tr.Position.Z)))
    f.root.AssemblyLinearVelocity=Vector3.zero
    emit(s,"Teleport",from,2,.3);emit(s,"Teleport",cf.Position,2,.3);break
   end
  end
  hurt(s,target,1.5*Stats.Get(p).Agility);emit(s,"Counter",tr.Position,2,.4)
 end)
 Combat.SetHeroHandlers("Sasuke",function(f,target)
  local p=f.player;if not p then return false end;local s=sessions[p];if not s then return false end;local now=clock();local stats=Stats.Get(p)
  if s.held and now>=s.readyAt and now<s.heldUntil then
   local variant=s.variant;local dealt=hurt(s,target,D.chidoriDamage(stats.Level,stats.Agility,variant),3)
   if dealt>0 then
    s.held=false;s.model:SetAttribute("ChidoriImpactAt",now);s.model:SetAttribute("ChidoriStrikeUntil",now+.3)
    local direction=target:GetPivot().Position-s.model:GetPivot().Position
    direction=if direction.Magnitude>.01 then direction.Unit else s.model:GetPivot().LookVector
    target:SetAttribute("ChidoriHitAt",now);target:SetAttribute("ChidoriHitDirection",direction)
    publish(s);emit(s,"ChidoriHit",target:GetPivot().Position,2,.55,{direction=direction,target=target,variant=variant})
    if variant=="AmaterasuChidori" then Fire.Ignite(s,target,800+5*stats.Agility,now) end
   end
   return true
  end
  return false
 end,function(f) local s=if f.player then sessions[f.player] else nil;return not s or (not s.garuda and s.pendingUntil<=clock() and (not s.held or clock()>=s.readyAt)) end)
 Damage.AttackAttempt.Event:Connect(function(attacker:Model,target:Model)
  local p=Players:GetPlayerFromCharacter(target);local s=if p then sessions[p] else nil
  if p and s and s.form==1 and ((s.model:GetAttribute("AmaterasuCoatingUntil") or 0) :: number)>clock() then Fire.Ignite(s,attacker,800+5*Stats.Get(p).Agility,clock()) end
 end)
 Damage.RegisterIncoming("Sasuke",function(target:Model,amount:number,kind:string?):number
  local p=Players:GetPlayerFromCharacter(target);local s=if p then sessions[p] else nil
  if not p or not s then return amount end
  if s.nagashiUntil and s.nagashiUntil>clock() and kind~="Attack" and kind~="Pure" then amount*=.6 end
  if s.form==0 or s.form>=3 then return amount end
  local pool=Resource.Get(p);if not pool or pool.pool.mana<amount*.2 then off(s);return amount end
  pool.pool.mana-=amount*.2
  local threshold=60+Stats.Get(p).Level
  return amount*(if amount<=threshold then (if s.form==1 then .6 else .1) else (if s.form==1 then .75 else .7))
 end)
end
return Service
