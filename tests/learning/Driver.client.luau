--!strict
assert(game:GetService("RunService"):IsStudio())
local player=game:GetService("Players").LocalPlayer
local remote=game:GetService("ReplicatedStorage"):WaitForChild("LearningTestDriver") :: RemoteEvent
local controllers=player.PlayerScripts:WaitForChild("Client"):WaitForChild("Controllers")
local Learning=require(controllers.LearningController)
local Abilities=require(controllers.AbilityController)
remote.OnClientEvent:Connect(function(id: number,mode: string,line: string?)
	local state=player:WaitForChild("HeroState")
	if mode=="learn" and line then
		local before=state:GetAttribute("Rank_"..line)
		Learning.TryLearn(line)
		local limit=os.clock()+2
		repeat task.wait(.03) until state:GetAttribute("Rank_"..line)~=before or os.clock()>=limit
	end
	local gui=player.PlayerGui:FindFirstChild("AbilityHUD")
	local panel=if gui then gui:FindFirstChild("Abilities") else nil
	local cloneButton=if panel then panel:FindFirstChild("ShadowClones") else nil
	local plus=if cloneButton then cloneButton:FindFirstChild("Learn") else nil
	local stats=if gui then gui:FindFirstChild("CharacterStats") else nil
	local values=if stats then stats:FindFirstChild("Values") else nil
	remote:FireServer(id,{cloneRank=state:GetAttribute("Rank_ShadowClones"),qRank=state:GetAttribute("Rank_Rasengan"),points=state:GetAttribute("SkillPoints"),
		plus=plus~=nil and (plus :: GuiObject).Visible,stats=values~=nil and (values :: TextLabel).Text or "",unlearned=Abilities.AbilityUnavailable("ShadowClones")})
end)
