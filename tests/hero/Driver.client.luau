--!strict
assert(game:GetService("RunService"):IsStudio())
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local driver = ReplicatedStorage:WaitForChild("HeroTestDriver") :: RemoteEvent
local ability = ReplicatedStorage:WaitForChild("HeroAbility") :: RemoteEvent
local controllers = player.PlayerScripts:WaitForChild("Client"):WaitForChild("Controllers")
local motion = require(controllers:WaitForChild("HeroMotionController"))
local RigJoints = require(ReplicatedStorage:WaitForChild("Shared").Combat.RigJoints)
local replies: { [number]: any } = {}
ability.OnClientEvent:Connect(function(message: any) if message.kind == "Result" then replies[message.requestId] = message end end)
driver.OnClientEvent:Connect(function(id: number, mode: string, data: any)
	local result: any = {}
	if mode == "cast" then
		-- RemoteEvent array serialization does not retain the mixed table's `n` key.
		local count = #data + 1
		data[count] = ReplicatedStorage:WaitForChild("SurvivalState"):GetAttribute("RoundId")
		ability:FireServer(table.unpack(data, 1, count))
		local deadline = os.clock() + 2
		repeat task.wait(0.02) until replies[data[1]] or os.clock() >= deadline
		result = replies[data[1]] or { reason = "NoReply", accepted = false }
	elseif mode == "flood" then
		for i = 1, 30 do ability:FireServer(data + i, player.Character, "Unknown", ReplicatedStorage:WaitForChild("SurvivalState"):GetAttribute("RoundId")) end
		task.wait(0.25); local replyCount = 0
		for requestId in replies do if requestId > data and requestId <= data + 30 then replyCount += 1 end end
		result.replies = replyCount
	elseif mode == "motion" then
		local model = data :: Model; local first: { [RigJoints.Joint]: CFrame } = {}
		for _, entry in RigJoints.Collect(model) do first[entry.joint] = entry.joint.Transform end
		for _ = 1, 5 do RunService.PreRender:Wait() end
		local changed = 0
		for motor, transform in first do
			local x, y, z = transform:ToObjectSpace(motor.Transform):ToOrientation()
			if math.abs(x) + math.abs(y) + math.abs(z) > 0.015 then changed += 1 end
		end
		local key, moved = motion.GetDiagnostics(model)
		result = { key = key, moved = moved, changed = changed, appearance = model:FindFirstChild("HeroAppearance") ~= nil }
	elseif mode == "targetPicker" then
		local controller = require(controllers.AbilityController)
		local target = data :: Model
		local root = target:FindFirstChild("HumanoidRootPart") :: BasePart
		local camera = workspace.CurrentCamera :: Camera
		local oldType, oldFrame = camera.CameraType, camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0,0,12), root.Position)
		local clone = Instance.new("Model"); clone.Name = "FriendlyCloneSelectionFixture"
		clone:SetAttribute("NativeNarutoClone",true); clone:SetAttribute("TeamId",player:GetAttribute("TeamId"))
		local part = Instance.new("Part"); part.Anchored = true; part.CanCollide = false
		part.Size = Vector3.new(4,4,2); part.Position = root.Position + Vector3.new(0,0,6); part.Parent = clone
		Instance.new("Humanoid").Parent = clone
		clone.Parent = workspace:WaitForChild("HeroSummons")
		local screen = camera:WorldToScreenPoint(root.Position)
		local point = Vector2.new(screen.X,screen.Y)
		local ray = camera:ScreenPointToRay(point.X,point.Y)
		local raw = RaycastParams.new(); raw.FilterType = Enum.RaycastFilterType.Exclude
		raw.FilterDescendantsInstances = {player.Character :: Model}
		local hit = workspace:Raycast(ray.Origin,ray.Direction*500,raw)
		local intercepted = if hit then hit.Instance:FindFirstAncestorOfClass("Model") else nil
		result.originalHit = if hit then hit.Instance:GetFullName() else "none"
		result.originalRayHitsFriendly = intercepted ~= nil and intercepted:GetAttribute("NativeNarutoClone") == true
			and intercepted:GetAttribute("TeamId") == player:GetAttribute("TeamId")
		result.enemySelected = controller.PickCloneTarget(point) == target
		local wall = Instance.new("Part"); wall.Anchored = true; wall.Size = Vector3.new(6,6,1)
		wall.Position = root.Position + Vector3.new(0,0,3); wall.Parent = workspace
		result.wallBlocks = controller.PickCloneTarget(point) == nil
		wall:Destroy()
		clone:SetAttribute("TeamId",target:GetAttribute("TeamId"))
		result.enemyCloneSelectable = controller.PickCloneTarget(point) == clone
		result.commandGuard = controller.BeginCloneCommand() and controller.IsSelectingCloneTarget()
			and player:GetAttribute("SelectingCloneTarget") == true
		controller.CancelCloneCommand(); clone:Destroy(); camera.CameraType = oldType; camera.CFrame = oldFrame
	elseif mode == "presentation" then
		-- Sample against the client's synchronized clock and a rendered frame, not
		-- merely the server's send time (the helper-only window is just 0.5 seconds).
		local model = player.Character :: Model
		if data.offset then
			local deadline = os.clock()+2
			repeat RunService.PreRender:Wait() until workspace:GetServerTimeNow() >= (model:GetAttribute("RasenganStartedAt") :: number)+data.offset or os.clock()>=deadline
		end
		RunService.PreRender:Wait()
		local helper,orb = require(controllers.AbilityVFXController).GetDiagnostics(player.Character :: Model)
		local key,moved = motion.GetDiagnostics(player.Character :: Model)
		result={helper=helper,orb=orb,key=key,moved=moved,elapsed=workspace:GetServerTimeNow()-(model:GetAttribute("RasenganStartedAt") :: number)}
	elseif mode == "hud" then
		local gui = player.PlayerGui:FindFirstChild("AbilityHUD")
		local function active(name: string): boolean?
			local button = if gui then gui:FindFirstChild(name, true) else nil
			return if button and button:IsA("TextButton") then button.Active else nil
		end
		result = { hero = player.PlayerGui:FindFirstChild("HeroHUD") ~= nil, abilities = player.PlayerGui:FindFirstChild("AbilityHUD") ~= nil,
			match = player.PlayerGui:FindFirstChild("SurvivalHUD") ~= nil, gamakichi = active("Gamakichi"), sage = active("SageMode"), kcm = active("KCM") }
	elseif mode == "prediction" then
		local combat = require(controllers.CombatController)
		local animation = require(controllers.AnimationController)
		local before = animation.GetLogicalPlayCount()
		local accepted = combat.TryAttack(); task.wait(0.6)
		result = { accepted = accepted, plays = animation.GetLogicalPlayCount() - before }
	end
	driver:FireServer(id, result)
end)
