--!strict
-- Pure choreography, radians. Server hit timestamps are the only attack trigger.
export type Pose = { [string]: { number } }
local Poses = { AttackDuration = .38, DeathDuration = .65, NearDistance = 85, FarDistance = 220 }
function Poses.State(dead: boolean, stunned: boolean, disabled: boolean, speed: number, now: number, attackAt: number?): (string, number)
	if dead then return "Dead", 0 end
	if stunned then return "Stun", 0 end
	if disabled then return "Idle", 0 end
	if attackAt and now >= attackAt and now - attackAt < Poses.AttackDuration then return "Attack", (now - attackAt) / Poses.AttackDuration end
	return if speed > 1.2 then "Run" else "Idle", 0
end
function Poses.Interval(distance: number, visible: boolean): number
	if not visible or distance > Poses.FarDistance then return .25 end
	return if distance > Poses.NearDistance then .1 else 1 / 30
end
function Poses.Sample(state: string, time: number, phase: number, ranged: boolean, zetsu: boolean): Pose
	local breathe = math.sin(time * 2.6) * .025
	local pose: Pose = { RootJoint = { breathe, 0, 0 }, Neck = { -breathe, 0, 0 },
		["Left Shoulder"] = { .1, 0, -.1 }, ["Right Shoulder"] = { .1, 0, .1 },
		["Left Hip"] = { 0, 0, 0 }, ["Right Hip"] = { 0, 0, 0 } }
	if state == "Run" then
		local stride = math.sin(time * 12)
		pose.RootJoint = { -.18, 0, stride * .025 }; pose.Neck = { .15, 0, 0 }
		pose["Left Hip"] = { stride * .65, 0, 0 }; pose["Right Hip"] = { -stride * .65, 0, 0 }
		pose["Left Shoulder"] = { if zetsu then -stride * .45 else -.7, 0, -.16 }
		pose["Right Shoulder"] = { if zetsu then stride * .45 else -.7, 0, .16 }
	elseif state == "Attack" then
		-- Contact starts at phase zero, matching the existing instant server hit; then recover.
		local strike = (1 - math.clamp(phase, 0, 1)) ^ 2
		pose.RootJoint = { -.15 * strike, -.25 * strike, 0 }
		pose["Right Shoulder"] = { (if ranged then 1.25 else 1.65) * strike, -.25 * strike, -.2 * strike }
		pose["Left Shoulder"] = { (if ranged then 1.1 else .3) * strike, 0, .25 * strike }
	elseif state == "Dead" then
		local fall = math.clamp(phase, 0, 1)
		pose.RootJoint = { .15 * fall, 0, 1.45 * fall }; pose.Neck = { .3 * fall, 0, 0 }
		pose["Left Shoulder"] = { .2, 0, -.45 * fall }; pose["Right Shoulder"] = { .2, 0, .45 * fall }
	elseif state == "Stun" then
		pose.RootJoint = { .15, 0, 0 }; pose.Neck = { -.15, 0, 0 }
	end
	return pose
end
return table.freeze(Poses)
