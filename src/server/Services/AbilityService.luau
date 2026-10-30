--!strict
-- Network/application boundary. Hero mechanics live in NarutoAbilityService/domain.
local Players = game:GetService("Players")
local Storage = game:GetService("ReplicatedStorage")
local Shared = Storage:WaitForChild("Shared")
local Config = require(Shared.Config.AbilityConfig)
local Heroes = require(Shared.Config.HeroConfig)
local Protocol = require(Shared.Game.RoundProtocol)
local Limiter = require(script.Parent.RequestLimiter)
local Teams = require(script.Parent.TeamService)
local Fighters = require(script.Parent.FighterStateService)
local Hitboxes = require(script.Parent.HitboxService)
local Damage = require(script.Parent.DamageService)
local Naruto = require(script.Parent.NarutoAbilityService)
type Session = { bucket: Limiter.Bucket, lastId: number, lastReply: number }
local sessions: {[Player]: Session} = {}
local remote: RemoteEvent? = nil
local started = false
local Ability = {}
local function sendAll(message: any)
	local match = Teams.GetState(); if not remote or not match or match.phase ~= "InProgress" then return end
	message.roundId = match.roundId; remote:FireAllClients(message)
end
function Ability.TryCast(player: Player, ...: any): (boolean,string)
	if player.Parent ~= Players then return false,"Unavailable" end
	local now = workspace:GetServerTimeNow()
	local session = sessions[player]
	if not session then session = {bucket=Limiter.new(Config.Burst,Config.RequestsPerSecond,now),lastId=0,lastReply=0}; sessions[player]=session end
	local allowed = Limiter.Consume(session.bucket,now)
	local id,character,abilityId,target = ...
	if typeof(id) ~= "number" or id ~= id or id%1 ~= 0 or id<1 or id>Config.MaxRequestId then return false,"Malformed" end
	local function result(ok: boolean,reason: string): (boolean,string)
		local match=Teams.GetState()
		if remote and (ok or now-session.lastReply>=Config.ReplyInterval) then
			session.lastReply=now; remote:FireClient(player,{kind="Result",requestId=id,character=player.Character,roundId=if match then match.roundId else nil,accepted=ok,reason=reason,ready=Naruto.Ready(player)})
		end
		return ok,reason
	end
	if not allowed then return result(false,"RateLimited") end
	local arity=select("#",...)
	if (arity~=3 and arity~=4) or (arity==4 and abilityId~="CloneCommand" and abilityId~="ShadowClones")
		or typeof(character)~="Instance"
		or typeof(abilityId)~="string" or #abilityId>32 or not Config.Abilities[abilityId] then return result(false,"Malformed") end
	local instance=character :: Instance
	if not instance:IsA("Model") or instance~=player.Character then return result(false,"Malformed") end
	local model=instance :: Model
	if id<=session.lastId then return result(false,"Replay") end; session.lastId=id
	local hero=Heroes.Heroes[tostring(player:GetAttribute("HeroId"))]
	if not hero or not table.find(hero.Abilities,abilityId) then return result(false,"Unsupported") end
	local match=Teams.GetState(); local fighter=Fighters.GetOrCreate(model)
	if not match or match.phase~="InProgress" or not Teams.IsParticipant(player) or not fighter or not Damage.CanAct(model)
		or player:GetAttribute("Eliminated")==true or fighter.root.Anchored or not fighter.root:IsDescendantOf(model)
		or fighter.humanoid:GetState()==Enum.HumanoidStateType.Dead or not Hitboxes.IsFiniteCFrame(fighter.root.CFrame) then return result(false,"Unavailable") end
	Fighters.Update(fighter,now)
	if not Naruto.IsAbility(abilityId) then return result(false,"Unsupported") end
	return result(Naruto.TryCast(player,abilityId,id,now,target))
end
function Ability.HandleRequest(player: Player,...: any): (boolean,string)
	local args=table.pack(...); local match=Teams.GetState()
	if not match or not Protocol.accepts(match.roundId,args[args.n]) then return false,"StaleRound" end
	return Ability.TryCast(player,table.unpack(args,1,args.n-1))
end
function Ability.Reset() Naruto.Reset() end
function Ability.Start()
	if started then return end; started=true
	Naruto.Start(); Naruto.Visual.Event:Connect(sendAll)
	require(script.Parent.NarutoSummonService).Spawned.Event:Connect(function(model: Model) sendAll({kind="Smoke",position=model:GetPivot().Position}) end)
	local event=Instance.new("RemoteEvent"); event.Name="HeroAbility"; event.Parent=Storage; remote=event
	event.OnServerEvent:Connect(function(player,...: any) Ability.HandleRequest(player,...) end)
	Players.PlayerRemoving:Connect(function(player) sessions[player]=nil end)
	game:GetService("RunService").Heartbeat:Connect(function() Naruto.Update(workspace:GetServerTimeNow()) end)
end
return Ability
