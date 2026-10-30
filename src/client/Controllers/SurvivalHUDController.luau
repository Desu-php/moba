--!strict
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Shared=RS:WaitForChild("Shared")
local Minions=require(Shared.Config.MinionConfig)
local VFX=require(script.Parent.VFXController)
local Rounds=require(script.Parent.RoundController)
local View=require(script.Parent.MobaHUDView)
local HUD={}
local started=false
function HUD.Start()
	if started then return end; started=true
	task.spawn(function()
		local state=RS:WaitForChild("SurvivalState",30); if not state then return end
		local player=Players.LocalPlayer
		local gui=Instance.new("ScreenGui"); gui.Name="SurvivalHUD"; gui.ResetOnSpawn=false; gui.DisplayOrder=5
		gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets; gui.Parent=player:WaitForChild("PlayerGui")
		local panel=View.frame(gui,"MatchPanel",UDim2.fromOffset(760,74),UDim2.new(.5,0,0,4)); panel.AnchorPoint=Vector2.new(.5,0)
		local scale=Instance.new("UIScale"); scale.Parent=panel
		local clock=View.label(panel,"Clock",UDim2.fromOffset(100,26),UDim2.fromOffset(330,7),18)
		local score=View.label(panel,"Score",UDim2.fromOffset(100,23),UDim2.fromOffset(330,35),18); score.TextColor3=View.Gold
		local status=View.label(gui,"Status",UDim2.fromOffset(460,25),UDim2.new(.5,0,0,82),14); status.AnchorPoint=Vector2.new(.5,0); status.TextColor3=View.Gold
		local slots: { {frame: Frame,portrait: View.Portrait,name: TextLabel,condition: TextLabel,shade: Frame,team: string,index: number} }={}
		for side,team in {"Blue","Red"} do
			for index=1,5 do
				local x=if side==1 then (index-1)*64+6 else 434+(index-1)*64
				local cell=View.frame(panel,team..index,UDim2.fromOffset(60,68),UDim2.fromOffset(x,3)); View.border(cell,if side==1 then Color3.fromRGB(81,151,112) else Color3.fromRGB(186,82,74))
				local portrait=View.portrait(cell,UDim2.fromOffset(58,46),UDim2.fromOffset(1,1))
				local shade=View.frame(cell,"Dead",UDim2.fromOffset(58,46),UDim2.fromOffset(1,1)); shade.BackgroundTransparency=.35; shade.Visible=false
				local condition=View.label(cell,"Condition",UDim2.fromOffset(58,22),UDim2.fromOffset(1,13),11); condition.ZIndex=3
				local name=View.label(cell,"Player",UDim2.fromOffset(58,18),UDim2.fromOffset(1,47),10)
				table.insert(slots,{frame=cell,portrait=portrait,name=name,condition=condition,shade=shade,team=team,index=index})
			end
		end
		local ending=View.frame(gui,"Result",UDim2.fromOffset(420,140),UDim2.fromScale(.5,.38)); ending.AnchorPoint=Vector2.new(.5,.5); ending.Visible=false; View.border(ending,View.Gold)
		local endingScale=Instance.new("UIScale"); endingScale.Parent=ending
		local result=View.label(ending,"ResultText",UDim2.new(1,-24,0,58),UDim2.fromOffset(12,16),30)
		local explanation=View.label(ending,"Explanation",UDim2.new(1,-24,0,42),UDim2.fromOffset(12,80),14); explanation.TextWrapped=true
		local notice=View.label(gui,"TowerNotice",UDim2.fromOffset(500,28),UDim2.new(.5,0,0,112),14); notice.AnchorPoint=Vector2.new(.5,0); notice.TextColor3=View.Gold
		local noticeUntil=0
		Rounds.Watch(function() noticeUntil=0; notice.Visible=false end)
		local towerEvents=state:WaitForChild("TowerEvent") :: RemoteEvent
		towerEvents.OnClientEvent:Connect(function(kind: string,_model: Model,_origin: Vector3,_destination: Vector3,id: string,_lane: string,epoch: number)
			if not Rounds.Accepts(epoch) then return end
			if kind=="Destroyed" then notice.Text=if id==player:GetAttribute("TeamId") then "Ваша башня разрушена" else "Вражеская башня разрушена"; noticeUntil=os.clock()+4 end
		end)
		local nextUpdate=0
		RunService.Heartbeat:Connect(function()
			local now=workspace:GetServerTimeNow(); if now<nextUpdate then return end; nextUpdate=now+.2
			local phase=state:GetAttribute("Phase"); local finished=phase=="Finished"
			local start=state:GetAttribute("StartedAt"); local finish=state:GetAttribute("FinishedAt")
			local elapsed=if typeof(start)=="number" and start>0 then math.max(0,(if finished and typeof(finish)=="number" then finish else now)-start) else 0
			clock.Text=string.format("%02d:%02d",math.floor(elapsed/60),math.floor(elapsed%60))
			local members: {[string]: {Player}}={Blue={},Red={}}
			for _,member in Players:GetPlayers() do
				local id=member:GetAttribute("TeamId")
				if typeof(id)=="string" and members[id] and member:GetAttribute("Spectating")~=true then
					table.insert(members[id],member)
				end
			end
			for _,team in members do table.sort(team,function(a: Player,b: Player) return a.UserId<b.UserId end) end
			local blue=state:FindFirstChild("Blue"); local red=state:FindFirstChild("Red")
			score.Text=string.format("%d   :   %d",if blue then (blue:GetAttribute("Kills") or 0) :: number else 0,if red then (red:GetAttribute("Kills") or 0) :: number else 0)
			for _,slot in slots do
				local member=members[slot.team][slot.index]; local model=if member then member.Character else nil
				View.updatePortrait(slot.portrait,model)
				slot.name.Text=if member then member.DisplayName else "Пусто"
				local humanoid=if model then model:FindFirstChildOfClass("Humanoid") else nil
				local dead=member~=nil and (not humanoid or humanoid.Health<=0)
				slot.shade.Visible=dead; slot.condition.Text=if not member then "—" elseif dead then "Погиб" else ""
			end
			status.Text=if phase=="WaitingForPlayers" then "Ожидание игроков" elseif phase=="Preparing" then "Начало через "..math.max(0,math.ceil((state:GetAttribute("PreparationEnds") :: number)-now)) elseif not finished and player:GetAttribute("Spectating")==true then "Наблюдение" else ""
			ending.Visible=finished
			local winner=state:GetAttribute("Winner"); local team=player:GetAttribute("TeamId")
			result.Text=if winner==team then "ПОБЕДА" elseif typeof(team)=="string" then "ПОРАЖЕНИЕ" else "МАТЧ ЗАВЕРШЁН"
			result.TextColor3=if winner==team then Color3.fromRGB(127,192,111) else View.Gold
			local winningTeam=if typeof(winner)=="string" then state:FindFirstChild(winner) else nil
			explanation.Text=if winningTeam then tostring(winningTeam:GetAttribute("DisplayName")).."\n"..(if winner==team then "Вражеский трон разрушен" elseif typeof(team)=="string" then "Ваш трон разрушен" else "Трон разрушен") else "Трон разрушен"
			notice.Visible=not finished and os.clock()<noticeUntil
			local camera=workspace.CurrentCamera
			if camera then
				local width=camera.ViewportSize.X; scale.Scale=math.min(1,(width-16)/760); endingScale.Scale=math.min(1,(width-24)/420)
				status.Position=UDim2.new(.5,0,0,78*scale.Scale+7); status.Size=UDim2.fromOffset(math.min(460,width-16),25)
				notice.Position=UDim2.new(.5,0,0,78*scale.Scale+35); notice.Size=UDim2.fromOffset(math.min(500,width-16),28)
			end
		end)
		local shots=state:WaitForChild("MinionShot") :: RemoteEvent
		shots.OnClientEvent:Connect(function(origin: Vector3,destination: Vector3,kind: string,id: string,target: Model,epoch: number)
			if not Rounds.Accepts(epoch) then return end
			local team=state:FindFirstChild(id); local color=if team then team:GetAttribute("Color") else Color3.new(1,1,1)
			if kind=="Ranged" then VFX.Projectile(origin,destination,color :: Color3,Minions.ProjectileDuration) end
			if target and target.Parent then VFX.Hit(target,destination,false) end
		end)
	end)
end
return HUD
