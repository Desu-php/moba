assert(game:GetService("RunService"):IsStudio(), "Manual fixture is Studio-only")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local Match = require(services.MatchService)
repeat task.wait(.1) until Match.GetState() and Match.GetState().phase == "InProgress"
local state = Match.GetState(); state.startedAt = workspace:GetServerTimeNow()+10000; state.nextWaveAt = workspace:GetServerTimeNow()+10000
require(RS.Shared.Config.TowerConfig).Range = 0
require(services.TowerService).CancelAll()
local AI = require(services.MinionAIService); AI.SetRunning(false); for model in AI.GetAll() do AI.Remove(model) end
for index,p in Players:GetPlayers() do
 repeat task.wait(.1) until p.Character and p.Character:GetAttribute("HeroAppearanceVersion")
 local native=require(services.NarutoAbilityService).Get(p); assert(native)
 for _,child in p.Character:GetChildren() do if child:IsA("Script") and child.Name=="Health" then child:Destroy() end end -- Isolate level healing from default passive regeneration.
 local beforeMana=native.pool.mana; local beforeHealth=p.Character.Humanoid.Health
 require(services.HeroProgressionService).AddXP(p,450)
 local deadline=os.clock()+1; repeat task.wait(.01) until native.pool.maximum==1555 or os.clock()>=deadline
 assert(math.abs(native.pool.mana-beforeMana)<1 and native.pool.maximum==1555,"Level-up unexpectedly refilled mana")
 assert(p.Character.Humanoid.Health==math.min(p.Character.Humanoid.MaxHealth,beforeHealth+30),"Unexpected HP level-up healing")
 print("[LearningGrowth] PASS HP/MP capacity update without refill",p.Name,beforeMana,native.pool.mana,p.Character.Humanoid.Health,p.Character.Humanoid.MaxHealth)
 local c=p.Character; c:PivotTo(CFrame.new((index-1)*12,36,0)); c.HumanoidRootPart:SetNetworkOwner(p)
 local t=Instance.new("Model"); t.Name="ManualEnemy"..p.Name
 local r=Instance.new("Part"); r.Name="HumanoidRootPart"; r.Size=Vector3.new(4,5,3); r.Anchored=true; r.Color=Color3.new(1,.2,.2); r.CFrame=CFrame.new((index-1)*12,36,-5); r.Parent=t
 local h=Instance.new("Humanoid"); h.MaxHealth=10000; h.Health=10000; h.Parent=t; t.PrimaryPart=r
 t:SetAttribute("TeamId",if p:GetAttribute("TeamId")=="Blue" then "Red" else "Blue"); t:SetAttribute("EntityKind","Minion"); t:SetAttribute("RoundId",state.roundId); t.Parent=workspace
 require(services.FighterStateService).GetOrCreate(t)
end
local participants=Players:GetPlayers()
local a,b=participants[1],participants[2]
assert(a and b)
local learning=require(services.AbilityLearningService)
local profile=require(services.HeroProgressionService).Get(b); assert(profile)
local before=profile.SkillPoints
local c=b.Character; local life=c:GetAttribute("LifeId")
local ok,reason=learning.HandleRequest(b,1,c,life,"Rasengan",state.roundId,9999)
assert(not ok and reason=="Malformed","Client extra fields must fail")
ok,reason=learning.HandleRequest(b,2,a.Character,a.Character:GetAttribute("LifeId"),"ShadowClones",state.roundId)
assert(not ok and reason=="StaleLife","Other hero must fail")
ok,reason=learning.HandleRequest(b,3,c,life,"ShadowClones",state.roundId-1)
assert(not ok and reason=="StaleLife","Stale epoch must fail")
ok,reason=learning.HandleRequest(b,4,c,life,"Fake",state.roundId)
assert(not ok and reason=="UnknownAbility","Unknown line must fail")
ok,reason=learning.HandleRequest(b,5,c,life,"ShadowClones",state.roundId)
assert(not ok and reason=="RateLimited" and profile.SkillPoints==before and next(profile.Learned)==nil,"Flood cannot mutate progression")
print("[LearningAdmission] ALL PASS: 5 boundary checks; use Player1 for physical learning controls")
print("[ManualUI] Ready: press Q/1, walk with W, use2 for clones and F/HUD command")

if workspace:GetAttribute("GamakichiManual")==true then
 local progression=require(services.HeroProgressionService)
 progression.AddXP(a,100000)
 local profile=progression.Get(a); assert(profile)
 local rules=require(RS.Shared.Abilities.SkillLearning)
 for _=1,9 do assert(rules.learn(profile,"Gamakichi")) end
 assert(rules.learn(profile,"ShadowClones")); progression.Publish(a)
 local native=require(services.NarutoAbilityService).Get(a); assert(native)
 local fighter=require(services.FighterStateService).Get(a.Character); assert(fighter)
 local initialAttacks=fighter.logic.attackSerial
 print("[GamakichiManual] READY Player1: Ctrl+3 learn10;3 summon;2 clones;F then enemy. Physical M1 must remain",initialAttacks)
 task.spawn(function()
  local deadline=os.clock()+180; local lastTarget: string?=nil
  repeat
   task.wait(.05)
   local command=native.commands.commandedTarget
   if command and command~=lastTarget then
    lastTarget=command
    assert(fighter.logic.attackSerial==initialAttacks,"Command click leaked M1")
    print("[GamakichiManual] Command accepted; M1 unchanged",fighter.logic.attackSerial,command)
   end
  until os.clock()>=deadline or not a.Parent
 end)
end
if workspace:GetAttribute("GamakichiSpellsManual")==true then
 local Gama=require(services.GamakichiService)
 task.spawn(function()
  local deadline=os.clock()+240; local lastSerial=0; local lastWave=0
  while os.clock()<deadline and a.Parent do
   task.wait(.02)
   local r=Gama.Get(a)
   if r then
    local serial=r.spells.serial
    if serial~=lastSerial then
     lastSerial=serial
     local f=require(services.FighterStateService).Get(a.Character); assert(f and f.logic.attackSerial==0,"G/H click leaked M1")
     print("[GamaSpellsManual] ACCEPTED",serial,"oil",r.spells.flight~=nil,"channel",r.spells.channel~=nil,"M1",f.logic.attackSerial)
    end
    local wave=r.model:GetAttribute("ChannelWave")
    if typeof(wave)=="number" and wave~=lastWave then lastWave=wave; print("[GamaSpellsManual] WAVE",wave) end
   end
  end
 end)
 print("[GamaSpellsManual] READY:3 summon, G enemy, H ground; M1 must remain0")
end
if workspace:GetAttribute("SageManual")==true then
 local progression=require(services.HeroProgressionService)
 local rules=require(RS.Shared.Abilities.SkillLearning)
 local xp=require(RS.Shared.Game.ProgressionRules).configure(require(RS.Shared.Config.ProgressionConfig),require(RS.Shared.Config.ItemConfig).Items)
 local pa,pb=progression.Get(a),progression.Get(b); assert(pa and pb)
 while pa.Level<10 do progression.AddXP(a,xp.required(pa.Level)) end
 while pb.Level<6 do progression.AddXP(b,xp.required(pb.Level)) end
 assert(rules.learn(pa,"SageMode")); progression.Publish(a); progression.Publish(b)
 for _,p in {a,b} do
  task.spawn(function()
   local deadline=os.clock()+180; local previous=""
   while os.clock()<deadline and p.Parent do
    task.wait(.05)
    local n=require(services.NarutoAbilityService).Get(p)
    local c=n and n.sage.active
    local phase=if c then c.phase else ""
    if phase~=previous then
     previous=phase
     print("[SageManual]",p.Name,phase,"rank",if c then c.rank else 0,"mana",if n then n.pool.mana else 0,"M1",if p.Character and require(services.FighterStateService).Get(p.Character) then require(services.FighterStateService).Get(p.Character).logic.attackSerial else -1)
    end
   end
  end)
 end
 print("[SageManual] READY: Player1 Ctrl+4 rank2 then4; Player2 Ctrl+4 rank1 then4; compare preparation7/10, HUD, aura and movement")
end