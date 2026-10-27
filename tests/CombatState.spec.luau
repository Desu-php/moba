--!strict

local State = require("../src/shared/Combat/CombatState")
local Config = require("../src/shared/Config/CombatConfig")
local profile = Config.Profiles.Default
local passed = 0
local function check(name: string, predicate: boolean)
	assert(predicate, name)
	passed += 1
	print("PASS CombatState: " .. name)
end

local state = State.new()
local damage = 0
for step = 1, 4 do
	local time = 10 + (step - 1) * 0.36
	check("start step " .. step, State.Request(state, profile, time, step) == "Started" and state.comboStep == step)
	check("windup prevents early damage " .. step, State.ClaimHit(state, time + 0.01) == nil)
	local hit = State.ClaimHit(state, time + profile.HitDelayByComboStep[step] + 0.01)
	assert(hit)
	damage += profile.DamageByComboStep[hit.step]
	check("one impact only " .. step, State.ClaimHit(state, time + 0.2) == nil)
end
check("full combo damage is 27", damage == 27)
check("finisher recovery", math.abs(state.nextAttackAt - (11.08 + 0.8)) < 0.00001)
check("finisher resets next step", State.Request(state, profile, 11.9, 5) == "Started" and state.comboStep == 1)
check("idle timeout resets combo", State.Request(state, profile, 13.2, 6) == "Started" and state.comboStep == 1)

state = State.new()
State.Request(state, profile, 20, 1)
for id = 2, 100 do State.Request(state, profile, 20.05, id) end
check("spam cannot advance step", state.comboStep == 1 and state.attackSerial == 1 and state.buffered == nil)
check("early input buffered", State.Request(state, profile, 20.25, 101) == "Buffered")
check("one buffer slot", State.Request(state, profile, 20.26, 102) == "Rejected")
check("buffer cannot fire early", State.TakeBuffer(state, 20.34) == nil)
State.Update(state, 20.36)
local id, valid = State.TakeBuffer(state, 20.36)
assert(id and valid)
check("buffer starts exactly next step", State.Request(state, profile, 20.36, id) == "Started" and state.comboStep == 2)

State.Stun(state, 20.4, 0.25, false)
check("stun interrupts pending impact", State.ClaimHit(state, 20.5) == nil and state.active == nil)
check("stunned cannot attack", State.Request(state, profile, 20.5, 103) == "Rejected")
State.Stun(state, 20.55, 0.25, false)
State.Update(state, 20.66)
check("old stun deadline cannot release new stun", state.mode == "Stunned")
State.Update(state, 20.81)
check("stun always expires", state.mode == "Idle")
State.Stun(state, 20.9, 0.65, true)
check("finisher resets victim combo", state.comboStep == 0 and state.buffered == nil)
State.Update(state, 21.56)
check("attack after stun starts at first step", State.Request(state, profile, 21.56, 104) == "Started" and state.comboStep == 1)
State.Request(state, profile, 21.81, 105)
State.Kill(state)
check("death clears queued and active attacks", state.active == nil and state.buffered == nil and state.comboStep == 0)
check("dead never recovers through clock", not State.Update(state, 100) and State.Request(state, profile, 100, 106) == "Rejected")
local respawn = State.new()
check("fresh character has fresh state", State.Request(respawn, profile, 100, 107) == "Started" and respawn.comboStep == 1)
check("other fighters remain independent", state.mode == "Dead")

state = State.new()
State.Request(state, profile, 30, 1)
State.Request(state, profile, 30.25, 2)
State.Update(state, 31)
local expiredId, timely = State.TakeBuffer(state, 31)
check("lag cannot retain stale buffered inputs", expiredId == 2 and not timely and state.buffered == nil)
check("late impact is discarded", State.ClaimHit(state, 31) == nil)
print(string.format("ALL PASS: %d pure combo/state checks", passed))
