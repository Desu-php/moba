--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Learning = require(Shared.Abilities.SkillLearning)
local Protocol = require(Shared.Game.RoundProtocol)
local Progression = require(script.Parent.HeroProgressionService)
local Teams = require(script.Parent.TeamService)
local Limiter = require(script.Parent.RequestLimiter)
type Session = { bucket: Limiter.Bucket, lastId: number, lastReply: number }
local sessions: { [Player]: Session } = {}
local Service = {}
local started = false
function Service.HandleRequest(player: Player, ...: any): (boolean, string)
	if player.Parent ~= Players then return false,"Unavailable" end
	local now = workspace:GetServerTimeNow()
	local session = sessions[player]
	if not session then session={bucket=Limiter.new(4,2,now),lastId=0,lastReply=0}; sessions[player]=session end
	if not Limiter.Consume(session.bucket,now) then return false,"RateLimited" end
	local id, character, life, ability, epoch = ...
	if select("#",...)~=5 or typeof(id)~="number" or id~=id or id%1~=0 or id<1 or id>2147483647
		or typeof(ability)~="string" or #ability>32 or typeof(character)~="Instance" or typeof(life)~="number" then return false,"Malformed" end
	if id<=session.lastId then return false,"Replay" end; session.lastId=id
	local model = character :: Instance
	local match=Teams.GetState()
	if not match or not Protocol.accepts(match.roundId,epoch) or not model:IsA("Model") or model~=player.Character
		or model:GetAttribute("RoundId")~=match.roundId or model:GetAttribute("LifeId")~=life then return false,"StaleLife" end
	if match.phase~="InProgress" or not Teams.IsParticipant(player) or not Teams.IsActive(Teams.GetId(model)) then return false,"Unavailable" end
	local profile=Progression.Get(player); if not profile then return false,"Unavailable" end
	-- Pure validation and point debit are non-yielding; no client ranks/points/stats accepted.
	local ok,reason=Learning.learn(profile,ability)
	if ok then Progression.Publish(player) end
	return ok,reason
end
function Service.Start()
	if started then return end; started=true
	local remote=Instance.new("RemoteEvent"); remote.Name="AbilityLearning"; remote.Parent=game:GetService("ReplicatedStorage")
	remote.OnServerEvent:Connect(function(player: Player,...: any)
		local args=table.pack(...); local ok,reason=Service.HandleRequest(player,table.unpack(args,1,args.n))
		local session=sessions[player]; local now=workspace:GetServerTimeNow()
		if session and (ok or now-session.lastReply>=0.25) then session.lastReply=now; remote:FireClient(player,ok,reason) end
	end)
	Players.PlayerRemoving:Connect(function(player) sessions[player]=nil end)
end
return Service
