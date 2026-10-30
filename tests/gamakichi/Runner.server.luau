--!strict
assert(game:GetService("RunService"):IsStudio())
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local services=game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match=require(services.MatchService)
local Progression=require(services.HeroProgressionService)
local Learning=require(services.AbilityLearningService)
local Ability=require(services.AbilityService)
local Naruto=require(services.NarutoAbilityService)
local Gama=require(services.GamakichiService)
local Fighters=require(services.FighterStateService)
local Damage=require(services.DamageService)
local count=0
local function check(name: string,ok: boolean,_reason: string?) assert(ok,name); count+=1; print("[GamakichiTests] PASS: "..name) end
local function waitFor(fn: () -> boolean,seconds: number,name: string)
 local deadline=os.clock()+seconds; repeat if fn() then return end; task.wait(.02) until os.clock()>=deadline
 error("Timeout: "..name)
end
local ok,err=xpcall(function()
 waitFor(function() return #Players:GetPlayers()==2 and Match.GetState()~=nil end,90,"two clients")
 local state=Match.GetState(); assert(state); state.phase="Preparing"; state.preparationEnds=0
 waitFor(function() return state.phase=="InProgress" end,15,"match")
 state.startedAt=workspace:GetServerTimeNow()+10000; state.nextWaveAt=workspace:GetServerTimeNow()+10000
 require(services.JungleService).Stop(); require(RS.Shared.Config.TowerConfig).Range=0; require(services.TowerService).CancelAll()
 local a,b=table.unpack(Players:GetPlayers())
 waitFor(function() return a.Character~=nil and b.Character~=nil and Naruto.Get(a)~=nil and Naruto.Get(b)~=nil end,20,"heroes")
 local character=a.Character :: Model; local enemy=b.Character :: Model
 character:PivotTo(CFrame.new(0,36,0)); enemy:PivotTo(CFrame.new(40,36,0))
 local session=Naruto.Get(a); assert(session)
 check("unlearned summon blocked",not Ability.HandleRequest(a,1,character,"Gamakichi",state.roundId))
 check("initial learning policy",Learning.HandleRequest(a,1,character,character:GetAttribute("LifeId"),"Gamakichi",state.roundId))
 local mana=session.pool.mana
 check("real ability boundary accepts summon",Ability.HandleRequest(a,2,character,"Gamakichi",state.roundId))
 local r=Gama.Get(a); assert(r)
 check("exact first debit and one summon",session.pool.mana==mana-50 and character:GetAttribute("GamakichiCount")==1)
 check("early profile fixed",r.humanoid.MaxHealth==500 and r.cast.profile.rawDamage==41 and r.model:GetAttribute("SummonArmor")==7)
 check("owner team epoch",r.model:GetAttribute("SummonOwner")==a.UserId and r.model:GetAttribute("RoundId")==state.roundId and r.model:GetAttribute("TeamId")==character:GetAttribute("TeamId"))
 check("second hero isolated",Gama.Get(b)==nil)
 local beforeRepeat=session.pool.mana
 local repeated,repeatReason=Ability.HandleRequest(a,3,character,"Gamakichi",state.roundId)
 check("cooldown cannot debit",not repeated and repeatReason=="Cooldown" and session.pool.mana>=beforeRepeat and session.pool.mana<beforeRepeat+1)
 check("enemies can damage summon with armor",math.abs(Damage.Apply(enemy,r.humanoid,107)-100)<.001)
 check("allies cannot damage summon",Damage.Apply(character,r.humanoid,100)==0)
 local target=Instance.new("Model"); target.Name="GamakichiTarget"
 local root=Instance.new("Part"); root.Name="HumanoidRootPart"; root.Anchored=true; root.Size=Vector3.new(2,4,2); root.Position=Vector3.new(0,36,-8); root.Parent=target
 local hp=Instance.new("Humanoid"); hp.MaxHealth=10000; hp.Health=10000; hp.Parent=target; target.PrimaryPart=root
 target:SetAttribute("MinionType","Melee"); target:SetAttribute("TeamId",enemy:GetAttribute("TeamId")); target:SetAttribute("RoundId",state.roundId); target:SetAttribute("EntityKind","Minion"); target.Parent=workspace; Fighters.GetOrCreate(target)
 r.model:PivotTo(CFrame.new(0,36,-2))
 task.wait(.5) -- refill request bucket; not a cooldown bypass
 check("F command without learning clones",Ability.HandleRequest(a,4,character,"CloneCommand",target,state.roundId))
 waitFor(function() return hp.Health<10000 end,2,"summon attack")
 check("raw base attack, no owner scaling",hp.Health==9959)
 local ownerProfile=Progression.Get(a); assert(ownerProfile)
 local kills=ownerProfile.TotalMinionKills; hp.Health=41
 Damage.Apply(r.model,hp,41)
 waitFor(function() return ownerProfile.TotalMinionKills==kills+1 end,2,"summon owner reward")
 check("summon kill credited once to owner",ownerProfile.TotalMinionKills==kills+1)
 check("second Naruto learns independently",Learning.HandleRequest(b,1,enemy,enemy:GetAttribute("LifeId"),"Gamakichi",state.roundId))
 check("second Naruto summons independently",Ability.HandleRequest(b,1,enemy,"Gamakichi",state.roundId))
 local other=Gama.Get(b); assert(other)
 check("two owned summons isolated",other~=r and other.model:GetAttribute("SummonOwner")==b.UserId)
 local castSerial=4
 Progression.AddXP(a,100000)
 check("learning does not mutate active summon",Gama.Get(a)==r and r.cast.rank==1 and r.humanoid.MaxHealth==500)
 for rank=2,10 do
  task.wait(.55)
  check("learn next rank "..rank,Learning.HandleRequest(a,rank,character,character:GetAttribute("LifeId"),"Gamakichi",state.roundId))
  if rank==5 or rank==6 then
   session.gama.cooldownAt=workspace:GetServerTimeNow(); session.pool.mana=session.pool.maximum; castSerial+=1
   check("rank boundary cast "..rank,Ability.HandleRequest(a,castSerial,character,"Gamakichi",state.roundId))
   local boundary=Gama.Get(a); assert(boundary)
   check("5-to-6 profile boundary "..rank,boundary.cast.profile.adult==(rank==6) and boundary.cast.rank==rank and session.pool.mana==session.pool.maximum-150)
   check("5-to-6 cooldown/lifetime "..rank,math.abs(session.gama.cooldownAt-workspace:GetServerTimeNow()-(if rank==5 then 60 else 150))<.1 and math.abs(boundary.cast.expiresAt-workspace:GetServerTimeNow()-(if rank==5 then 30 else 35))<.1)
  end
 end
 -- Fixture advances the already pure-tested deadline to avoid waiting a full minute.
 session.gama.cooldownAt=workspace:GetServerTimeNow(); session.pool.mana=session.pool.maximum
 castSerial+=1; check("rank10 cast",Ability.HandleRequest(a,castSerial,character,"Gamakichi",state.roundId))
 local adult=Gama.Get(a); assert(adult)
 check("replacement and adult profile",adult~=r and not r.model.Parent and adult.humanoid.MaxHealth==1500 and adult.cast.rank==10 and adult.cast.profile.rawDamage==101)
 check("rank10 mana and lifetime",session.pool.mana==session.pool.maximum-300 and math.abs(adult.cast.expiresAt-workspace:GetServerTimeNow()-55)<.1)
  check("learn clones alongside toad",Learning.HandleRequest(a,11,character,character:GetAttribute("LifeId"),"ShadowClones",state.roundId))
 castSerial+=1; check("clones cast alongside toad",Ability.HandleRequest(a,castSerial,character,"ShadowClones",state.roundId))
 waitFor(function() return character:GetAttribute("NativeCloneCount")==3 end,2,"clone burst")
 check("toad and clones coexist",Gama.Get(a)==adult and character:GetAttribute("NativeCloneCount")==3)
 task.wait(.3)
 local cooldown=session.gama.cooldownAt
 adult.cast.expiresAt=workspace:GetServerTimeNow()
 waitFor(function() return Gama.Get(a)==nil end,1,"expiry")
 check("expiry clears entity and retains cooldown",not adult.model.Parent and session.gama.cooldownAt==cooldown)
 session.gama.cooldownAt=workspace:GetServerTimeNow(); session.pool.mana=session.pool.maximum
 task.wait(.5)
 castSerial+=1; check("new summon before death",Ability.HandleRequest(a,castSerial,character,"Gamakichi",state.roundId))
 local dead=Gama.Get(a); assert(dead);
 (character:FindFirstChildOfClass("Humanoid") :: Humanoid).Health=0
 waitFor(function() return Gama.Get(a)==nil end,1,"owner death cleanup")
 check("owner death cancels delayed hits",not dead.model.Parent and session.gama.active==nil)
 check("other owner unaffected by death",Gama.Get(b)==other)
 waitFor(function() return a.Character~=nil and a.Character~=character end,12,"respawn")
 local learned=Progression.Get(a); assert(learned)
 check("rank survives respawn cooldown not refunded",learned.Learned.Gamakichi==10 and session.gama.cooldownAt>workspace:GetServerTimeNow())
 session.gama.cooldownAt=workspace:GetServerTimeNow(); session.pool.mana=session.pool.maximum; task.wait(.5)
 castSerial+=1; check("respawn summon",Ability.HandleRequest(a,castSerial,a.Character,"Gamakichi",state.roundId))
 local final=Gama.Get(a); assert(final); state.phase="Finished"
 waitFor(function() return Gama.Get(a)==nil end,1,"terminal cleanup")
 check("terminal no entity or orphan damage",not final.model.Parent and session.gama.active==nil and Gama.Get(b)==nil)
 Fighters.Remove(target); target:Destroy()
 print("[GamakichiTests] ALL PASS: "..count.." checks")
return "passed"
end,function(message) return debug.traceback(tostring(message),2) end)
if not ok then warn("[GamakichiTests] FAILED after "..count..": "..tostring(err)) end
