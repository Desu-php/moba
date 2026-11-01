--!strict
local State = require("../src/shared/Combat/CombatState")
local Config = require("../src/shared/Config/CombatConfig")
local Rate = require("../src/shared/Combat/BasicAttackRules")
local Progression = require("../src/shared/Game/ProgressionRules").configure(require("../src/shared/Config/ProgressionConfig"), {})
local profile = Config.Profiles.Default
local passed = 0
local function check(name: string, value: boolean)
 assert(value, name); passed += 1; print("PASS BasicAttack: " .. name)
end
local function near(a: number, b: number): boolean return math.abs(a-b) < 0.00001 end
local state = State.new()
for index = 1, 8 do
 local at = 10 + (index-1) * profile.AttackCooldown
 check("repeat starts " .. index, State.Request(state, profile, at, index) == "Started")
 local attack = state.active; assert(attack)
 check("same directed attack without escalation " .. index, attack.step == 1 and near(attack.hitAt-at,profile.HitDelay) and near(attack.endsAt-at,profile.AttackDuration))
 check("no hit during windup " .. index, State.ClaimHit(state,at+profile.HitDelay-0.001)==nil)
 check("one impact after windup " .. index, State.ClaimHit(state,at+profile.HitDelay) == attack and State.ClaimHit(state,at+profile.HitDelay+0.001)==nil)
end
check("single target, no finisher configuration",profile.MaxTargets==1 and profile.AnimationKey=="Punch1")
local stats1=Progression.stats(Progression.new())
local leveled=Progression.new(); leveled.Level=30
local stats30=Progression.stats(leveled)
local speed1=Rate.speed(profile,stats1.Agility); local speed30=Rate.speed(profile,stats30.Agility)
check("rate uses actual growing AGI",stats30.Agility>stats1.Agility and speed30>speed1)
check("rate cap",near(Rate.speed(profile,10000)/profile.AttackCooldown,profile.MaxAttacksPerSecond))
check("invalid AGI cannot poison clock",Rate.speed(profile,0/0)==1 and Rate.speed(profile,math.huge)==1 and Rate.speed(profile,-100)==1)
state=State.new(); check("speed admission",State.Request(state,profile,20,100,speed1)=="Started")
local attack=state.active; assert(attack)
check("speed scales windup, recovery and interval together",near(attack.hitAt-20,profile.HitDelay/speed1) and near(attack.endsAt-20,profile.AttackDuration/speed1) and near(state.nextAttackAt-20,profile.AttackCooldown/speed1))
for id=101,200 do State.Request(state,profile,20.01,id,speed1) end
check("spam cannot add attacks or future hits",state.attackSerial==1 and state.buffered==nil)
local nextAt=state.nextAttackAt
check("real early click buffers once",State.Request(state,profile,nextAt-0.05,201,speed1)=="Buffered" and State.Request(state,profile,nextAt-0.04,202,speed1)=="Rejected")
check("buffer does not fire early",State.TakeBuffer(state,nextAt-0.01)==nil)
State.Update(state,nextAt); local id,valid=State.TakeBuffer(state,nextAt); assert(id and valid)
check("buffer repeats same attack",State.Request(state,profile,nextAt,id,speed1)=="Started" and (state.active :: State.Attack).step==1)
State.Stun(state,nextAt+0.01,0.5,false)
check("stun cancels windup and buffer",State.ClaimHit(state,nextAt+0.2)==nil and state.active==nil and state.buffered==nil and State.Request(state,profile,nextAt+0.2,203)=="Rejected")
State.Stun(state,nextAt+0.4,0.5,false); State.Update(state,nextAt+0.6)
check("overlapping stun preserves later deadline",state.mode=="Stunned")
State.Update(state,nextAt+1); check("stun recovers",state.mode=="Idle")
State.Request(state,profile,nextAt+1,204); State.Kill(state)
check("death invalidates pending impact",State.ClaimHit(state,nextAt+1.3)==nil and state.active==nil and state.buffered==nil)
check("dead state cannot revive through clock",not State.Update(state,1000) and State.Request(state,profile,1000,205)=="Rejected")
state=State.new(); State.Request(state,profile,30,300); State.Request(state,profile,30.45,301); State.Update(state,31)
local expired,timely=State.TakeBuffer(state,31)
check("stale buffer and late impact discarded",expired==301 and not timely and State.ClaimHit(state,31)==nil)
check("invalid speed rejected before mutation",State.Request(State.new(),profile,40,400,0)=="Rejected" and State.Request(State.new(),profile,40,401,math.huge)=="Rejected")
check("physical armor retained",near(Progression.mitigate(100,0),100) and near(Progression.mitigate(100,100),50) and near(Progression.mitigate(100,50),100*100/150))
print(string.format("ALL PASS: %d basic attack/state checks",passed))
