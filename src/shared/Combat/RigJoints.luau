--!strict
-- Both Roblox avatar joint generations use Transform. Never rewrite RigAttachments.
export type Joint = Motor6D | AnimationConstraint
export type Entry = { joint: Joint, key: string }
local Rig = {}
local names: { [string]: string } = {
	LowerTorso = "Root", UpperTorso = "Waist", Head = "Neck",
	LeftUpperArm = "LeftShoulder", LeftLowerArm = "LeftElbow", LeftHand = "LeftWrist",
	RightUpperArm = "RightShoulder", RightLowerArm = "RightElbow", RightHand = "RightWrist",
	LeftUpperLeg = "LeftHip", LeftLowerLeg = "LeftKnee", LeftFoot = "LeftAnkle",
	RightUpperLeg = "RightHip", RightLowerLeg = "RightKnee", RightFoot = "RightAnkle",
}
function Rig.Collect(model: Model): { Entry }
	local entries: { Entry } = {}; local seen: { [Instance]: boolean } = {}
	local descendants = model:GetDescendants()
	-- Prefer modern constraints if a migration rig happens to contain both types.
	for _, class in { "AnimationConstraint", "Motor6D" } do
		for _, item in descendants do
			if item.ClassName ~= class then continue end
			local joint: Joint; local child: Instance?
			if item:IsA("AnimationConstraint") then
				joint = item; child = if item.Attachment1 then item.Attachment1.Parent else nil
			elseif item:IsA("Motor6D") then joint = item; child = item.Part1
			else continue end
			if not child or not child:IsA("BasePart") or child.Parent ~= model or not names[child.Name] or seen[child] then continue end
			seen[child] = true; table.insert(entries, { joint = joint, key = names[child.Name] })
		end
	end
	return entries
end
return Rig
