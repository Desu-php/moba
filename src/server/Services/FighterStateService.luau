--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.CombatConfig)
local State = require(Shared.Combat.CombatState)
local Life = require(script.Parent.CombatLifeService)
local Heroes = require(Shared.Config.HeroConfig)
local Structures = require(Shared.Game.StructureRules)

type Movement = {
	walkSpeed: number, jumpPower: number, jumpHeight: number, autoRotate: boolean,
	ownershipAuto: boolean, owner: Player?, ownershipChanged: boolean,
}
export type Fighter = {
	character: Model, humanoid: Humanoid, root: BasePart, player: Player?,
	logic: State.Fighter, profile: Config.AttackProfile, profileId: string,
	revision: number, connections: { RBXScriptConnection }, movement: Movement?,
}

local FighterStateService = { Changed = Instance.new("BindableEvent") }
local fighters: { [Model]: Fighter } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local started = false

local function restoreMovement(fighter: Fighter)
	local saved = fighter.movement
	if not saved then return end
	fighter.movement = nil
	local humanoid, root = fighter.humanoid, fighter.root
	if humanoid.Parent then
		humanoid.WalkSpeed = if fighter.character:GetAttribute("CombatDisabled") == true then 0 else saved.walkSpeed
		humanoid.JumpPower = saved.jumpPower
		humanoid.JumpHeight = saved.jumpHeight
		humanoid.AutoRotate = saved.autoRotate
	end
	if saved.ownershipChanged and root.Parent and root:CanSetNetworkOwnership() then
		if saved.ownershipAuto then
			root:SetNetworkOwnershipAuto()
		else
			root:SetNetworkOwner(if saved.owner and saved.owner.Parent == Players then saved.owner else nil)
		end
	end
end

function FighterStateService.Snapshot(fighter: Fighter)
	local logic = fighter.logic
	return {
		character = fighter.character, profileId = fighter.profileId, revision = fighter.revision,
		mode = logic.mode, comboStep = logic.comboStep, lastAttackAt = logic.lastAttackAt,
		nextAttackAt = logic.nextAttackAt, stunUntil = logic.stunUntil, attackSerial = logic.attackSerial,
	}
end

function FighterStateService.Publish(fighter: Fighter)
	fighter.revision += 1
	fighter.character:SetAttribute("CombatState", fighter.logic.mode)
	fighter.character:SetAttribute("ComboStep", fighter.logic.comboStep)
	fighter.character:SetAttribute("CombatNextAttackAt", fighter.logic.nextAttackAt)
	fighter.character:SetAttribute("CombatStunUntil", fighter.logic.stunUntil)
	fighter.character:SetAttribute("CombatProfileId", fighter.profileId)
	fighter.character:SetAttribute("CombatLastAttackAt", fighter.logic.lastAttackAt)
	fighter.character:SetAttribute("CombatAttackEndsAt", if fighter.logic.active then fighter.logic.active.endsAt else 0)
	fighter.character:SetAttribute("CombatAttackSerial", fighter.logic.attackSerial)
	FighterStateService.Changed:Fire(fighter)
end

function FighterStateService.Remove(character: Model)
	local fighter = fighters[character]
	if not fighter then return end
	fighters[character] = nil
	State.Kill(fighter.logic)
	for _, connection in fighter.connections do connection:Disconnect() end
	restoreMovement(fighter)
end

function FighterStateService.Get(character: Model): Fighter?
	return fighters[character]
end

function FighterStateService.SetWalkSpeed(character: Model, speed: number)
	local fighter = fighters[character]
	if fighter and fighter.movement then
		fighter.movement.walkSpeed = speed
	else
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.WalkSpeed = if character:GetAttribute("CombatDisabled") == true then 0 else speed end
	end
end

function FighterStateService.GetOrCreate(character: Model): Fighter?
	if Structures.isStructure(character:GetAttribute("EntityKind")) then return nil end
	if fighters[character] then return fighters[character] end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not character:IsDescendantOf(Workspace) or not humanoid or not root or not root:IsA("BasePart") then return nil end
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	local fighter: Fighter = {
		character = character, humanoid = humanoid, root = root, player = Players:GetPlayerFromCharacter(character),
		logic = State.new(), profileId = Config.DefaultProfile, profile = Config.Profiles[Config.DefaultProfile],
		revision = 0, connections = {}, movement = nil,
	}
	local heroId = character:GetAttribute("HeroId")
	local hero = if typeof(heroId) == "string" then Heroes.Heroes[heroId] else nil
	if fighter.player and hero then
		fighter.profileId = hero.Profile
		fighter.profile = Config.Profiles[hero.Profile] or Config.Profiles[Config.DefaultProfile]
	end
	fighters[character] = fighter
	Life.Register(character)
	table.insert(fighter.connections, humanoid.Died:Connect(function()
		State.Kill(fighter.logic)
		restoreMovement(fighter)
		FighterStateService.Publish(fighter)
	end))
	table.insert(fighter.connections, character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(Workspace) then FighterStateService.Remove(character) end
	end))
	if humanoid.Health <= 0 then State.Kill(fighter.logic) end
	FighterStateService.Publish(fighter)
	return fighter
end

function FighterStateService.Stun(fighter: Fighter, duration: number, resetCombo: boolean)
	if fighter.humanoid.Health <= 0 or fighter.logic.mode == "Dead" then return end
	local now = Workspace:GetServerTimeNow()
	State.Stun(fighter.logic, now, math.clamp(duration, 0, fighter.profile.MaxStunDuration), resetCombo)
	local humanoid, root = fighter.humanoid, fighter.root
	if not fighter.movement then
		local canOwn = root:CanSetNetworkOwnership()
		fighter.movement = {
			walkSpeed = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower,
			jumpHeight = humanoid.JumpHeight, autoRotate = humanoid.AutoRotate,
			ownershipAuto = if canOwn then root:GetNetworkOwnershipAuto() else true,
			owner = if canOwn then root:GetNetworkOwner() else nil, ownershipChanged = canOwn,
		}
		if canOwn then root:SetNetworkOwner(nil) end
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.Jump = false
	humanoid.AutoRotate = false
	if not root.Anchored then
		local vertical = root.AssemblyLinearVelocity.Y
		if vertical ~= vertical or math.abs(vertical) == math.huge then vertical = 0 end
		root.AssemblyLinearVelocity = Vector3.new(0, math.clamp(vertical, -fighter.profile.MaxKnockbackSpeed, fighter.profile.MaxKnockbackSpeed), 0)
	end
	FighterStateService.Publish(fighter)
end

function FighterStateService.Update(fighter: Fighter, now: number)
	if fighter.humanoid.Health <= 0 then
		if fighter.logic.mode ~= "Dead" then
			State.Kill(fighter.logic)
			restoreMovement(fighter)
			FighterStateService.Publish(fighter)
		end
		return
	end
	if State.Update(fighter.logic, now) then
		if fighter.logic.mode ~= "Stunned" then restoreMovement(fighter) end
		FighterStateService.Publish(fighter)
	end
end

function FighterStateService.GetAll(): { [Model]: Fighter }
	return fighters
end

local function bindPlayer(player: Player)
	if playerConnections[player] then return end
	local function bindCharacter(character: Model)
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", Config.CharacterReadyTimeout)
			local root = character:WaitForChild("HumanoidRootPart", Config.CharacterReadyTimeout)
			if humanoid and root and player.Parent == Players and player.Character == character then
				FighterStateService.GetOrCreate(character)
			end
		end)
	end
	playerConnections[player] = {
		player.CharacterAdded:Connect(bindCharacter),
		player.CharacterRemoving:Connect(FighterStateService.Remove),
	}
	if player.Character then bindCharacter(player.Character) end
end

function FighterStateService.Start()
	if started then return end
	started = true
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		if player.Character then FighterStateService.Remove(player.Character) end
		for character, fighter in fighters do
			if fighter.player == player then FighterStateService.Remove(character) end
		end
		local connections = playerConnections[player]
		if connections then
			for _, connection in connections do connection:Disconnect() end
		end
		playerConnections[player] = nil
	end)
	for _, player in Players:GetPlayers() do bindPlayer(player) end
end

return FighterStateService
