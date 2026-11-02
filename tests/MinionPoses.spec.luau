--!strict
local Poses = require("../src/shared/Combat/MinionPoses")
local count = 0
local function check(condition: boolean, message: string)
	assert(condition, message); count += 1
end
check(Poses.State(false, false, false, 0, 10, nil) == "Idle", "stationary minion idles")
check(Poses.State(false, false, false, 8, 10, nil) == "Run", "actual movement triggers run")
check(Poses.State(false, false, false, 8, 10, 10) == "Attack", "hit timestamp overrides movement")
local state, phase = Poses.State(false, false, false, 0, 10.19, 10)
check(state == "Attack" and math.abs(phase - .5) < .001, "server time determines observed phase")
check(Poses.State(false, false, false, 0, 11, 10) == "Idle", "stale timestamp cannot loop attack")
check(Poses.State(false, false, false, 0, 10, 11) == "Idle", "future timestamp cannot trigger early")
check(Poses.State(false, true, false, 8, 10, 10) == "Stun", "stun suppresses stale attack/run")
check(Poses.State(false, false, true, 8, 10, 10) == "Idle", "match stop suppresses movement/attacks")
check(Poses.State(true, true, true, 8, 10, 10) == "Dead", "death wins all priorities")
check(Poses.Interval(50, true) == 1 / 30, "near animation limited to 30 Hz")
check(Poses.Interval(100, true) == .1, "distant animation limited to 10 Hz")
check(Poses.Interval(221, true) == .25 and Poses.Interval(10, false) == .25, "culled rigs only check four times per second")
for _, zetsu in { false, true } do
	for _, ranged in { false, true } do
		for _, key in { "Idle", "Run", "Attack", "Dead", "Stun" } do
			for _, p in { 0, .5, 1 } do
				local pose = Poses.Sample(key, 123, p, ranged, zetsu)
				local joints = 0
				for _, angles in pose do
					joints += 1
					for _, angle in angles do check(angle == angle and math.abs(angle) < math.pi, "finite bounded joint angle") end
				end
				check(joints == 6, "every pose resets all six motors")
			end
		end
	end
end
local first = Poses.Sample("Attack", 1, 0, false, false)
local recovered = Poses.Sample("Attack", 1, 1, false, false)
check(first["Right Shoulder"][1] > recovered["Right Shoulder"][1], "instant hit recovers rather than anticipates damage")
local fall = Poses.Sample("Dead", 1, 1, false, false)
check(fall.RootJoint[3] > 1, "corpse visibly falls before existing one-second cleanup")
print(string.format("[MinionPoses] PASS %d checks", count))
