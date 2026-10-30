--!strict
-- Roblox terrain adapter. Distances arrive in Warcraft units; timing stays in seconds.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Units = require(Shared.Abilities.WorldUnits)
type Push = { caster: Model, target: Model, startedAt: number, nextTick: number, totalTicks: number, switchAfter: number,
	first: number, second: number, interval: number, valid: () -> boolean, finished: (() -> ())?, trail: (() -> ())? }
local Service = {}
local pushes: { Push } = {}
function Service.Begin(caster: Model, target: Model, now: number, duration: number, switchAfter: number,
	firstStepWarcraft: number, secondStepWarcraft: number, interval: number, valid: () -> boolean, finished: (() -> ())?, trail: (() -> ())?)
	table.insert(pushes, { caster = caster, target = target, startedAt = now, nextTick = 1,
		totalTicks = math.floor(duration / interval + 1e-9), switchAfter = switchAfter,
		first = firstStepWarcraft, second = secondStepWarcraft, interval = interval, valid = valid, finished = finished, trail = trail })
end
function Service.Reset() table.clear(pushes) end
function Service.Update(now: number)
	for index = #pushes, 1, -1 do
		local push = pushes[index]
		local root = push.target:FindFirstChild("HumanoidRootPart")
		local origin = push.caster:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not origin or not origin:IsA("BasePart") or not push.valid() then
			table.remove(pushes, index); continue
		end
		while push.nextTick <= push.totalTicks and push.startedAt + push.nextTick * push.interval <= now do
			local delta = (root.Position - origin.Position) * Vector3.new(1, 0, 1)
			if delta.Magnitude > 0.001 then
				local step = if push.nextTick * push.interval < push.switchAfter then push.first else push.second
				local move = delta.Unit * Units.toStuds(step)
				local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { push.caster, push.target }; params.RespectCanCollide = true
				local hit = workspace:Blockcast(root.CFrame, root.Size, move, params)
				if hit then move = move.Unit * math.max(0, hit.Distance - 0.01) end
				push.target:PivotTo(push.target:GetPivot() + move)
				if push.trail and push.nextTick * push.interval >= push.switchAfter then
					-- Spin rate is original Roblox choreography, not a certified WC animation rate.
					root.CFrame *= CFrame.Angles(0,math.pi*4*push.interval,0)
					if push.nextTick % 6 == 0 then push.trail() end
				end
			end
			push.nextTick += 1
		end
		if push.nextTick > push.totalTicks then table.remove(pushes, index); if push.finished then push.finished() end end
	end
end
return Service
