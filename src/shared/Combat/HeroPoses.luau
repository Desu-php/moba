--!strict
-- Original joint-angle choreography. Pure math; radians, R15 Motor6D names.
export type Pose = { [string]: { number } }
local Poses = {}
local function angles(x: number, y: number?, z: number?): { number } return { x, y or 0, z or 0 } end
function Poses.sample(key: string, time: number, phase: number): Pose
	local breathe = math.sin(time * 2.4)
	local pose: Pose = { Waist = angles(-0.05 + breathe * 0.025), Neck = angles(0.02),
		LeftShoulder = angles(0.12, 0, -0.12), RightShoulder = angles(0.12, 0, 0.12),
		LeftElbow = angles(0.14), RightElbow = angles(0.14) }
	if key == "Run" then
		local stride = math.sin(time * 13)
		pose.Waist = angles(-0.43, stride * 0.035); pose.Neck = angles(0.3)
		pose.LeftShoulder = angles(-1.05, 0, -0.13); pose.RightShoulder = angles(-1.05, 0, 0.13)
		pose.LeftElbow = angles(0.12); pose.RightElbow = angles(0.12)
		pose.LeftHip = angles(stride * 0.9); pose.RightHip = angles(-stride * 0.9)
		pose.LeftKnee = angles(-math.max(0, -stride) * 1.05); pose.RightKnee = angles(-math.max(0, stride) * 1.05)
	elseif key == "Stun" then
		pose.Waist = angles(0.23, 0, math.sin(time * 32) * 0.035); pose.Neck = angles(-0.25)
		pose.LeftShoulder = angles(-0.3, 0, -0.35); pose.RightShoulder = angles(-0.3, 0, 0.35)
		pose.LeftKnee = angles(-0.22); pose.RightKnee = angles(-0.22)
	elseif key == "ShadowClones" then
		local seal = math.clamp(phase / 0.16, 0, 1) * (1 - math.clamp((phase - 0.62) / 0.38, 0, 1))
		local sign = math.sin(phase * math.pi * 6) * 0.2 * seal
		pose.LeftShoulder = angles(1.05 * seal, -0.15, 0.7 * seal); pose.RightShoulder = angles(1.05 * seal, 0.15, -0.7 * seal)
		pose.LeftElbow = angles((1.45 + sign) * seal); pose.RightElbow = angles((1.45 - sign) * seal)
		pose.LeftWrist = angles(0, sign, 0.55 * seal); pose.RightWrist = angles(0, -sign, -0.55 * seal)
		pose.Waist = angles(-0.18 * seal); pose.Neck = angles(0.12 * seal)
	elseif key == "RasenganPrepare" or key == "RasenganHelper" then
		local circle = time * 16
		pose.Waist = angles(-.12, -.18); pose.Neck = angles(.12)
		pose.RightShoulder = angles(.65,-.25,-.15); pose.RightElbow = angles(1.25)
		pose.LeftShoulder = angles(1.05,-.2,.65); pose.LeftElbow = angles(1.5)
		pose.LeftWrist = angles(math.sin(circle)*.22,math.cos(circle)*.25,.2)
	elseif key == "RasenganStrike" then
		local extend = math.clamp(phase/.12,0,1)
		pose.Waist = angles(-.2,.35*extend); pose.Neck = angles(.08)
		pose.RightShoulder = angles(.6+1.1*extend,-.1,-.15); pose.RightElbow = angles(.9*(1-extend))
		pose.LeftShoulder = angles(.45,0,.35); pose.LeftElbow = angles(1.2)
		pose.RightHip = angles(.25); pose.LeftHip = angles(-.2)
	elseif string.match(key, "^Punch%d$") or key == "HeavyPunch" then
		local heavy = key == "HeavyPunch"
		local contact = if heavy then 0.327 else if key == "Punch3" then 0.4 else 0.357
		local thrust = if phase < contact * 0.4 then -0.25 * phase / (contact * 0.4)
			elseif phase <= contact then -0.25 + 1.25 * math.clamp((phase - contact * 0.4) / (contact * 0.6), 0, 1)
			else 1 - math.clamp((phase - contact) / (1 - contact), 0, 1)
		local left = key == "Punch2"
		local sign = if left then -1 else 1
		pose.Waist = angles(if heavy then -0.3 * thrust else -0.08, sign * (-0.35 + thrust * (if heavy then 1.2 else 0.7)))
		pose[left and "LeftShoulder" or "RightShoulder"] = angles((if key == "Punch3" then 2.1 else 1.6) * thrust, sign * 0.18, sign * 0.16)
		pose[left and "LeftElbow" or "RightElbow"] = angles(1.35 * (1 - thrust))
		pose[left and "RightShoulder" or "LeftShoulder"] = angles(0.65, 0, sign * 0.2)
		pose[left and "RightElbow" or "LeftElbow"] = angles(1.3)
		if heavy then pose.RightHip = angles(0.55 * thrust); pose.LeftHip = angles(-0.35 * thrust)
		elseif key == "Punch3" then pose.RightHip = angles(0.3 * thrust); pose.RightKnee = angles(-0.4 * thrust) end
	end
	return pose
end
function Poses.holdRasengan(pose: Pose, time: number): Pose
	pose.RightShoulder = angles(.55,-.25,-.22)
	pose.RightElbow = angles(1.15 + math.sin(time*3)*.025)
	pose.RightWrist = angles(-.15,0,-.1)
	return pose
end
return Poses
