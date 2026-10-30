--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.AbilityConfig)
local Items = require(Shared.Config.ItemConfig)
local Controller = require(script.Parent.AbilityController)
local View = require(script.Parent.MobaHUDView)
local Learning = require(script.Parent.LearningController)
local HUD = {}
local started = false
function HUD.Start()
	if started then return end; started = true; Controller.Start(); Learning.Start()
	local player = Players.LocalPlayer
	local starterGui = game:GetService("StarterGui")
	starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	local gui = Instance.new("ScreenGui"); gui.Name = "AbilityHUD"; gui.ResetOnSpawn = false; gui.DisplayOrder = 8
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets; gui.Parent = player:WaitForChild("PlayerGui")
	local panel = View.frame(gui,"Abilities",UDim2.fromOffset(950,150),UDim2.new(.5,0,1,-8)); panel.AnchorPoint = Vector2.new(.5,1)
	View.border(panel,View.Gold); local scale = Instance.new("UIScale"); scale.Parent = panel
	local portrait = View.portrait(panel,UDim2.fromOffset(112,112),UDim2.fromOffset(8,8))
	local hero = View.label(panel,"HeroName",UDim2.fromOffset(112,20),UDim2.fromOffset(8,120),13); hero.Text = "НАРУТО"
	local level = View.label(panel,"Level",UDim2.fromOffset(34,27),UDim2.fromOffset(86,93),17); level.BackgroundTransparency=0; level.BackgroundColor3=View.Background; level.TextColor3=View.Gold
	local kda = View.label(panel,"KDA",UDim2.fromOffset(160,22),UDim2.fromOffset(130,8),12)
	local gold = View.label(panel,"Gold",UDim2.fromOffset(160,22),UDim2.fromOffset(766,115),14); gold.TextColor3=View.Gold
	local points=View.label(panel,"SkillPoints",UDim2.fromOffset(280,20),UDim2.fromOffset(300,8),12); points.TextColor3=View.Gold
 local statsToggle=Instance.new("TextButton"); statsToggle.Name="StatsToggle"; statsToggle.Text="C · Характеристики"; statsToggle.Size=UDim2.fromOffset(190,24); statsToggle.Position=UDim2.new(0,18,1,-180); statsToggle.BackgroundColor3=View.Card; statsToggle.TextColor3=View.Gold; statsToggle.Parent=gui
 local statsPanel=View.frame(gui,"CharacterStats",UDim2.fromOffset(260,226),UDim2.new(0,18,1,-214)); statsPanel.Position=UDim2.new(0,18,.5,0); statsPanel.AnchorPoint=Vector2.new(0,.5); statsPanel.Visible=false; View.border(statsPanel,View.Gold); local statsScale=Instance.new("UIScale"); statsScale.Parent=statsPanel
 local statsText=View.label(statsPanel,"Values",UDim2.new(1,-16,1,-16),UDim2.fromOffset(8,8),14); statsText.TextXAlignment=Enum.TextXAlignment.Left; statsText.TextYAlignment=Enum.TextYAlignment.Top
 statsToggle.Activated:Connect(function() statsPanel.Visible=not statsPanel.Visible end)
 game:GetService("UserInputService").InputBegan:Connect(function(input,processed)
  if not processed and not game:GetService("UserInputService"):GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.C then statsPanel.Visible=not statsPanel.Visible end
 end)
 local buttons: { [string]: TextButton } = {}
 local learnButtons: { [string]: TextButton } = {}
	for index,id in Config.Order do
		local main = index <= 5; local slot = if main then index-1 else index-6
		local button = Instance.new("TextButton"); button.Name=id; button.Size=UDim2.fromOffset(if main then 78 else 64,if main then 66 else 31)
		button.Position=UDim2.fromOffset(if main then 130+slot*82 else 546,if main then 32 else 32+slot*35)
		button.BackgroundColor3=View.Card; button.BorderSizePixel=0; button.Text=""; button.Parent=panel; View.border(button,View.Gold)
		local key=View.label(button,"Key",UDim2.fromOffset(42,16),UDim2.fromOffset(2,1),11); key.Text=Config.Abilities[id].KeyLabel; key.TextColor3=View.Gold
		local name=View.label(button,"Name",UDim2.new(1,-6,0,if main then 27 else 14),UDim2.fromOffset(3,if main then 17 else 14),if main then 12 else 10)
		name.Text=if id=="CloneCommand" then "Цель" else Config.Abilities[id].Name; name.TextWrapped=true; name.TextTruncate=Enum.TextTruncate.None
		local status=View.label(button,"Status",UDim2.new(1,-4,0,18),UDim2.fromOffset(2,46),11); status.Visible=main
		button.Activated:Connect(function() if id=="CloneCommand" then Controller.BeginCloneCommand() else Controller.TryCast(id) end end)
		buttons[id]=button
  if main then
   local plus=Instance.new("TextButton"); plus.Name="Learn"; plus.Text="+"; plus.Size=UDim2.fromOffset(22,18); plus.Position=UDim2.new(1,-23,0,1); plus.BackgroundColor3=Color3.fromRGB(152,112,33); plus.TextColor3=Color3.new(1,1,1); plus.Parent=button
   plus.Activated:Connect(function() Learning.TryLearn(id) end); learnButtons[id]=plus
  end
	end
	local function bar(name: string,y: number,color: Color3): (Frame,TextLabel)
		local track=View.frame(panel,name,UDim2.fromOffset(480,17),UDim2.fromOffset(130,y)); track.BackgroundColor3=View.Card
		local fill=View.frame(track,"Fill",UDim2.fromScale(1,1),UDim2.new()); fill.BackgroundColor3=color
		local text=View.label(track,"Value",UDim2.fromScale(1,1),UDim2.new(),12); text.TextStrokeTransparency=.45; return fill,text
	end
	local hpFill,hpText=bar("Health",103,Color3.fromRGB(73,145,62))
	local mpFill,mpText=bar("Mana",122,Color3.fromRGB(49,108,176))
	local xpTrack=View.frame(panel,"XP",UDim2.fromOffset(112,3),UDim2.fromOffset(8,144)); xpTrack.BackgroundColor3=View.Card
	local xpFill=View.frame(xpTrack,"Fill",UDim2.fromScale(0,1),UDim2.new()); xpFill.BackgroundColor3=View.Gold
	local inventory: {TextLabel}={}
	for index=1,6 do
		local slot=View.label(panel,"Item"..index,UDim2.fromOffset(92,43),UDim2.fromOffset(642+((index-1)%3)*98,13+math.floor((index-1)/3)*49),11)
		slot.BackgroundTransparency=0; slot.BackgroundColor3=View.Card; slot.TextWrapped=true; View.border(slot,Color3.fromRGB(100,108,111)); table.insert(inventory,slot)
	end
	local message=View.label(gui,"AbilityMessage",UDim2.fromOffset(600,26),UDim2.new(.5,0,1,-166),13); message.AnchorPoint=Vector2.new(.5,1); message.TextColor3=View.Gold
	local nextUpdate=0
	RunService.Heartbeat:Connect(function()
		local now=workspace:GetServerTimeNow(); if now<nextUpdate then return end; nextUpdate=now+.1
		local camera=workspace.CurrentCamera
		if camera then
			local compact=camera.ViewportSize.X<650; local width=if compact then 420 else 950; local height=if compact then 214 else 150
			panel.Size=UDim2.fromOffset(width,height)
			scale.Scale=math.min(1,(camera.ViewportSize.X-16)/width,(camera.ViewportSize.Y-80)/(height+90))
   statsScale.Scale=math.min(1,(camera.ViewportSize.X-36)/260,(camera.ViewportSize.Y-50)/226)
   statsToggle.Position=UDim2.new(0,18,1,-((height+8)*scale.Scale+30))
			portrait.viewport.Size=UDim2.fromOffset(if compact then 80 else 112,if compact then 96 else 112)
			hero.Size=UDim2.fromOffset(if compact then 80 else 112,20); hero.Position=UDim2.fromOffset(8,if compact then 105 else 120)
			level.Position=UDim2.fromOffset(if compact then 54 else 86,if compact then 78 else 93)
			kda.Position=UDim2.fromOffset(if compact then 8 else 130,if compact then 126 else 8); kda.Size=UDim2.fromOffset(if compact then 90 else 160,22)
			gold.Position=UDim2.fromOffset(if compact then 254 else 766,if compact then 188 else 115)
			for index,id in Config.Order do
				local main=index<=5; local slot=if main then index-1 else index-6; local button=buttons[id]
				button.Size=UDim2.fromOffset(if main then (if compact then 58 else 78) else (if compact then 102 else 64),if main then 66 else (if compact then 42 else 31))
				button.Position=if compact then UDim2.fromOffset(if main then 102+slot*60 else 8+slot*108,if main then 8 else 160)
					else UDim2.fromOffset(if main then 130+slot*82 else 546,if main then 32 else 32+slot*35)
			end
			for index,slot in inventory do
				slot.Size=UDim2.fromOffset(if compact then 48 else 92,if compact then 28 else 43)
				slot.Position=if compact then UDim2.fromOffset(254+((index-1)%3)*52,122+math.floor((index-1)/3)*32)
					else UDim2.fromOffset(642+((index-1)%3)*98,13+math.floor((index-1)/3)*49)
			end
			local hpTrack=hpFill.Parent :: Frame; local mpTrack=mpFill.Parent :: Frame
			hpTrack.Size=UDim2.fromOffset(if compact then 304 else 480,17); mpTrack.Size=hpTrack.Size
			hpTrack.Position=UDim2.fromOffset(if compact then 102 else 130,if compact then 78 else 103)
			mpTrack.Position=UDim2.fromOffset(if compact then 102 else 130,if compact then 97 else 122)
			xpTrack.Size=UDim2.fromOffset(if compact then 80 else 112,3); xpTrack.Position=UDim2.fromOffset(8,if compact then 122 else 144)
			message.Position=UDim2.new(.5,0,1,-((height+8)*scale.Scale+8)); message.Size=UDim2.fromOffset(math.min(600,camera.ViewportSize.X-20),26)
		end
		local model=player.Character; View.updatePortrait(portrait,model)
		local state=player:FindFirstChild("HeroState")
		local function number(name: string): number local value=if state then state:GetAttribute(name) else nil; return if typeof(value)=="number" then value else 0 end
		local humanoid=if model then model:FindFirstChildOfClass("Humanoid") else nil
		local hp=if humanoid then humanoid.Health else 0; local maximum=if humanoid then humanoid.MaxHealth else 1
		local mana=if model then model:GetAttribute("Mana") else nil; local maxMana=if model then model:GetAttribute("MaxMana") else nil
		local mp=if typeof(mana)=="number" then mana else 0; local maxMP=if typeof(maxMana)=="number" then maxMana else 1
		hpFill.Size=UDim2.fromScale(math.clamp(hp/math.max(1,maximum),0,1),1); hpText.Text=string.format("%d / %d",math.ceil(hp),maximum)
		mpFill.Size=UDim2.fromScale(math.clamp(mp/math.max(1,maxMP),0,1),1); mpText.Text=string.format("%d / %d",math.floor(mp),maxMP)
		level.Text=tostring(number("Level")); gold.Text=string.format("%d GOLD",number("Gold"))
		kda.Text=string.format("%d / %d / %d",number("TotalKills"),number("TotalDeaths"),number("Assists"))
		xpFill.Size=UDim2.fromScale(if number("XPToNextLevel")==0 then 1 else math.clamp(number("CurrentXP")/number("XPToNextLevel"),0,1),1)
		local owned={}; for _,id in Items.Order do if state and state:GetAttribute("Own_"..id)==true then table.insert(owned,Items.Items[id].Name) end end
		for index,slot in inventory do slot.Text=owned[index] or "—" end
		message.Text=if Learning.GetMessage()~="" then Learning.GetMessage() else Controller.GetMessage()
  statsToggle.Text=string.format("C · Параметры · Очки %d",number("SkillPoints")); points.Text=string.format("Очки: %d · Ctrl+1–5 для обучения",number("SkillPoints"))
  points.Visible=camera~=nil and camera.ViewportSize.X>=650
  statsText.Text=string.format("НАРУТО · Уровень %d / 30\nXP %d / %d\nОчки обучения: %d\n\nSTR %.1f  (+1.4 / ур.)\nAGI %.1f  (+1.1 / ур.)\nINT %.1f  (+1 / ур.)\n\nБроня %.1f · M1 x%.2f\nМана %.0f · Реген %.2f/с\nСкорость %.1f",number("Level"),number("CurrentXP"),number("XPToNextLevel"),number("SkillPoints"),number("RawStrength"),number("RawAgility"),number("Intelligence"),number("Defense"),number("AttackDamageMultiplier"),number("MaxMana"),number("ManaRegen"),number("WalkSpeed"))
  for id,plus in learnButtons do plus.Visible=state~=nil and state:GetAttribute("LearnReason_"..id)=="Ready" end
		for id,button in buttons do
			local remaining=Controller.Remaining(id); local reason=Controller.AbilityUnavailable(id)
   local rank=number("Rank_"..id)
			button.Active=reason==nil and remaining<=0; button.AutoButtonColor=button.Active
			button.BackgroundColor3=if button.Active then Color3.fromRGB(67,78,71) else View.Card
			local status=button:FindFirstChild("Status") :: TextLabel
			status.Text=if rank==0 and (id=="Rasengan" or id=="ShadowClones") then "Не изуч." elseif remaining>0 then string.format("%.1f",remaining) elseif not (Config.PrototypeEnabled :: {[string]: boolean})[id] then "Скоро" elseif reason then (if id=="Rasengan" and number("Level")<4 then "Ур. 4" else "—") else "Готово"
			if id~="CloneCommand" then status.Text=tostring(rank).." · "..status.Text end
		end
	end)
end
return HUD
