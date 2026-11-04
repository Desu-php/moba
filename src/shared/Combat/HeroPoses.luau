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
	elseif key=="Meditation" then
        local breath=math.sin(time*2)*.025
        pose.Waist=angles(.05+breath); pose.Neck=angles(-.1-breath)
        pose.LeftHip=angles(1.2,0,-.6); pose.RightHip=angles(1.2,0,.6)
        pose.LeftKnee=angles(-1.7); pose.RightKnee=angles(-1.7)
        pose.LeftShoulder=angles(.4,0,.3); pose.RightShoulder=angles(.4,0,-.3)
        pose.LeftElbow=angles(.9); pose.RightElbow=angles(.9)
    elseif key=="SagePrepare" then
        pose.Waist=angles(.08); pose.Neck=angles(-.08)
        pose.LeftShoulder=angles(.9,-.15,.6); pose.RightShoulder=angles(.9,.15,-.6)
        pose.LeftElbow=angles(1.6); pose.RightElbow=angles(1.6)
        pose.LeftWrist=angles(0,0,.3); pose.RightWrist=angles(0,0,-.3)
    elseif key == "ShadowClones" then
		local seal = math.clamp(phase / 0.16, 0, 1) * (1 - math.clamp((phase - 0.62) / 0.38, 0, 1))
		local sign = math.sin(phase * math.pi * 6) * 0.2 * seal
		pose.LeftShoulder = angles(1.05 * seal, -0.15, 0.7 * seal); pose.RightShoulder = angles(1.05 * seal, 0.15, -0.7 * seal)
		pose.LeftElbow = angles((1.45 + sign) * seal); pose.RightElbow = angles((1.45 - sign) * seal)
		pose.LeftWrist = angles(0, sign, 0.55 * seal); pose.RightWrist = angles(0, -sign, -0.55 * seal)
		pose.Waist = angles(-0.18 * seal); pose.Neck = angles(0.12 * seal)
	elseif key == "RasenganPrepare" or key == "RasenganHelper" or key == "OdamaPrepare" or key == "RasenshurikenPrepare" then
		local circle = time * 13
		local gather = math.clamp(phase / .6, 0, 1)
		gather = gather * gather * (3 - 2 * gather)
		pose.Waist = angles(-.08, -.18); pose.Neck = angles(.1)
		pose.RightShoulder = angles(.65,-.2,-.18); pose.RightElbow = angles(1.25)
		pose.LeftShoulder = angles(1.05,-.2,.65); pose.LeftElbow = angles(1.5)
		pose.RightWrist = angles(-.12,0,-.1)
		pose.LeftWrist = angles(math.sin(circle)*.2,math.cos(circle)*.25,.2)
		if key == "OdamaPrepare" then
			-- The support hand moves outward as the sphere grows, rather than
			-- repeating the small-ball stirring gesture throughout the upgrade.
			pose.Waist = angles(-.12,-.24); pose.Neck = angles(.05)
			pose.RightShoulder = angles(.65+.45*gather,-.1,-.4)
			pose.RightElbow = angles(1.25-.8*gather)
			pose.LeftShoulder = angles(1.1,.45,.35)
			pose.LeftElbow = angles(1.5-.8*gather)
			pose.LeftWrist = angles(-.15,0,.45)
		elseif key == "RasenshurikenPrepare" then
			-- Lift the wind blade above the right shoulder: readable in the
			-- third-person silhouette without turning it into a thrown attack.
			pose.Waist = angles(-.05,-.18); pose.Neck = angles(-.12*gather)
			pose.RightShoulder = angles(.65+2.05*gather,-.12,-.32)
			pose.RightElbow = angles(1.25-1.05*gather)
			pose.RightWrist = angles(-.1,0,-.1)
			pose.LeftShoulder = angles(.9,-.15,.55)
			pose.LeftElbow = angles(1.3)
		end
	elseif key == "RasenshurikenThrow" then
        local wind=math.clamp(phase/.4375,0,1)
        local release=math.clamp((phase-.4375)/.23,0,1)
        pose.Waist=angles(-.1-.25*release,-.5*wind+.95*release)
        pose.Neck=angles(.1)
        pose.RightShoulder=angles(2.7+.35*wind-1.7*release,-.15,-.35)
        pose.RightElbow=angles(.25+.65*wind-.85*release)
        pose.LeftShoulder=angles(.7-.4*release,0,.7);pose.LeftElbow=angles(1.1)
        pose.RightHip=angles(.3*release);pose.LeftHip=angles(-.25*release)
    elseif key == "RasenganStrike" or key == "OdamaStrike" or key == "RasenshurikenStrike" then
		local extend = math.clamp(phase/.2,0,1)
		pose.Waist = angles(-.2,.35*extend); pose.Neck = angles(.08)
		pose.RightShoulder = angles(.6+1.1*extend,-.1,-.15); pose.RightElbow = angles(.9*(1-extend))
		pose.RightWrist = angles(-.1,0,-.1)
		pose.LeftShoulder = angles(.45,0,.35); pose.LeftElbow = angles(1.2)
		if key == "OdamaStrike" then
			pose.Waist = angles(-.32,.18*extend)
			pose.RightShoulder = angles(1.1+.5*extend,-.1,-.32); pose.RightElbow = angles(.45*(1-extend))
			pose.LeftShoulder = angles(1.15+.3*extend,.45,.3); pose.LeftElbow = angles(.65*(1-extend))
			pose.LeftWrist = angles(-.15,0,.45)
		elseif key == "RasenshurikenStrike" then
			pose.Waist = angles(-.24,.4*extend)
			pose.RightShoulder = angles(2.7-1.05*extend,-.12,-.32); pose.RightElbow = angles(.2*(1-extend))
			pose.LeftShoulder = angles(.6,0,.65); pose.LeftElbow = angles(1.25)
		end
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
function Poses.holdRasengan(pose: Pose, time: number, variant: string?): Pose
	-- Upper-body overlay deliberately leaves hips/knees/ankles untouched so all
	-- three techniques can be carried while moving under existing server rules.
	pose.RightShoulder = angles(.55,-.25,-.22)
	pose.RightElbow = angles(1.15 + math.sin(time*3)*.025)
	pose.RightWrist = angles(-.15,0,-.1)
	if variant == "Odama" then
		pose.Waist = angles(-.12,-.24)
		pose.RightShoulder = angles(1.1,-.1,-.4); pose.RightElbow = angles(.45)
		pose.LeftShoulder = angles(1.1,.45,.35); pose.LeftElbow = angles(.7)
		pose.LeftWrist = angles(-.15,0,.45)
	elseif variant == "Rasenshuriken" then
		pose.Waist = angles(-.07,-.18); pose.Neck = angles(-.1)
		pose.RightShoulder = angles(2.7,-.12,-.32); pose.RightElbow = angles(.2)
		pose.LeftShoulder = angles(.9,-.15,.55); pose.LeftElbow = angles(1.3)
	end
	return pose
end
return Poses
