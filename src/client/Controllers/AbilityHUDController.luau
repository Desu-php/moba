--!strict
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInput=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared.Config.AbilityConfig)
local Items=require(Shared.Config.ItemConfig)
local Combat=require(Shared.Config.CombatConfig)
local BasicRules=require(Shared.Combat.BasicAttackRules)
local CloneRanks=require(Shared.Abilities.NarutoRankPolicy)
local Gamakichi=require(Shared.Abilities.GamakichiState)
local Controller=require(script.Parent.AbilityController)
local Learning=require(script.Parent.LearningController)
local View=require(script.Parent.MobaHUDView)
local Layout=require(script.Parent.HUDLayout)
local Icons=require(script.Parent.HUDIcons)
local HUD={}
local started=false
function HUD.Start()
 if started then return end; started=true; Controller.Start(); Learning.Start()
 local player=Players.LocalPlayer
 local starter=game:GetService("StarterGui")
 starter:SetCoreGuiEnabled(Enum.CoreGuiType.Health,false); starter:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
 local gui=Instance.new("ScreenGui"); gui.Name="AbilityHUD"; gui.ResetOnSpawn=false; gui.DisplayOrder=8
 gui.ScreenInsets=Enum.ScreenInsets.None; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=player:WaitForChild("PlayerGui")
 local panel=View.frame(gui,"Abilities",UDim2.fromOffset(Layout.ConsoleWidth,Layout.ConsoleHeight),UDim2.fromScale(.5,1)); panel.AnchorPoint=Vector2.new(.5,1)
 View.border(panel,View.Gold); local scale=Instance.new("UIScale"); scale.Parent=panel
 local portrait=View.portrait(panel,UDim2.fromOffset(108,132),UDim2.fromOffset(4,25))
 local hero=View.label(panel,"HeroName",UDim2.fromOffset(108,22),UDim2.fromOffset(4,2),13); hero.Text="NARUTO"
 local level=View.label(panel,"Level",UDim2.fromOffset(30,26),UDim2.fromOffset(82,130),17); level.BackgroundTransparency=0; level.BackgroundColor3=View.Background; level.TextColor3=View.Gold
 local xpTrack=View.frame(panel,"XP",UDim2.fromOffset(108,4),UDim2.fromOffset(4,159)); xpTrack.BackgroundColor3=View.Card
 local xpFill=View.frame(xpTrack,"Fill",UDim2.fromScale(0,1),UDim2.new()); xpFill.BackgroundColor3=View.Gold
 local stats=View.label(panel,"CombatStats",UDim2.fromOffset(116,124),UDim2.fromOffset(119,29),13); stats.TextXAlignment=Enum.TextXAlignment.Left; stats.TextYAlignment=Enum.TextYAlignment.Top
 local kda=View.label(panel,"KDA",UDim2.fromOffset(116,22),UDim2.fromOffset(119,2),12)
 local points=View.label(panel,"SkillPoints",UDim2.fromOffset(336,16),UDim2.fromOffset(240,0),12); points.TextColor3=View.Gold
 local gold=View.label(panel,"Gold",UDim2.fromOffset(186,27),UDim2.fromOffset(704,128),17); gold.TextColor3=View.Gold
 local statsToggle=Instance.new("TextButton"); statsToggle.Name="StatsToggle"; statsToggle.Text="C  Характеристики"; statsToggle.Size=UDim2.fromOffset(116,23); statsToggle.Position=UDim2.fromOffset(119,137); statsToggle.TextSize=10; statsToggle.BackgroundColor3=View.Card; statsToggle.TextColor3=View.Gold; statsToggle.Parent=panel
 local statsPanel=View.frame(panel,"CharacterStats",UDim2.fromOffset(300,300),UDim2.fromOffset(0,-310)); statsPanel.Visible=false; View.border(statsPanel,View.Gold)
 local statsText=View.label(statsPanel,"Values",UDim2.new(1,-24,1,-24),UDim2.fromOffset(12,12),14); statsText.TextXAlignment=Enum.TextXAlignment.Left; statsText.TextYAlignment=Enum.TextYAlignment.Top
 local function toggle() statsPanel.Visible=not statsPanel.Visible end
 statsToggle.Activated:Connect(toggle)
 UserInput.InputBegan:Connect(function(input,processed) if not processed and not UserInput:GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.C then toggle() end end)
 local tooltip=View.frame(panel,"Tooltip",UDim2.fromOffset(330,136),UDim2.fromOffset(240,-146)); tooltip.Visible=false; View.border(tooltip,View.Gold)
 local tooltipText=View.label(tooltip,"Text",UDim2.new(1,-20,1,-16),UDim2.fromOffset(10,8),14); tooltipText.TextWrapped=true; tooltipText.TextXAlignment=Enum.TextXAlignment.Left; tooltipText.TextYAlignment=Enum.TextYAlignment.Top
 local hovered: string?=nil
 local buttons: {[string]: TextButton}={}
 local learnButtons: {[string]: TextButton}={}
 for index,id in Config.Order do
  local main=index<=5; local x,y,size=Layout.skill(index)
  local button=Instance.new("TextButton"); button.Name=id; button.Size=UDim2.fromOffset(size,size)
  button.Position=UDim2.fromOffset(x,y)
  button.BackgroundColor3=View.Card; button.BorderSizePixel=0; button.Text=""; button.Parent=panel; View.border(button,View.Gold)
  Icons.draw(button,id)
  local shade=View.frame(button,"Cooldown",UDim2.fromScale(1,1),UDim2.new()); shade.BackgroundColor3=Color3.new(); shade.BackgroundTransparency=.35; shade.ZIndex=2
  local key=View.label(button,"Key",UDim2.fromOffset(if main then 45 else 30,16),UDim2.fromOffset(0,-16),if main then 12 else 11); key.Text=Config.Abilities[id].KeyLabel; key.TextXAlignment=Enum.TextXAlignment.Left; key.TextColor3=View.Gold
  local status=View.label(button,"Status",UDim2.fromScale(1,1),UDim2.new(),if main then 17 else 12); status.ZIndex=3; status.TextStrokeTransparency=.2
  local rank=View.label(button,"Rank",UDim2.fromOffset(size,14),UDim2.fromOffset(0,size+2),11); rank.TextColor3=View.Gold; rank.Visible=main
  button.MouseEnter:Connect(function() hovered=id; tooltip.Visible=true end)
  button.MouseLeave:Connect(function() if hovered==id then hovered=nil; tooltip.Visible=false end end)
  button.Activated:Connect(function() if id=="CloneCommand" then Controller.BeginCloneCommand() else Controller.TryCast(id) end end)
  buttons[id]=button
  if main then
   local plus=Instance.new("TextButton"); plus.Name="Learn"; plus.Text="+"; plus.Size=UDim2.fromOffset(22,20); plus.Position=UDim2.new(1,-22,0,-21); plus.ZIndex=4; plus.TextSize=20
   plus.BackgroundColor3=Color3.fromRGB(152,112,33); plus.TextColor3=Color3.new(1,1,1); plus.Parent=button
   plus.Activated:Connect(function() Learning.TryLearn(id) end); learnButtons[id]=plus
  end
 end
 local rikudoPanel=View.frame(panel,"RikudoTechniques",UDim2.fromOffset(370,45),UDim2.fromOffset(520,-58));rikudoPanel.Visible=false
 local rikudoTitle=View.label(rikudoPanel,"Title",UDim2.fromOffset(370,17),UDim2.fromOffset(0,-18),12);rikudoTitle.Text="РИКУДО • временные техники";rikudoTitle.TextColor3=View.Gold
 local rangedButtons:{[string]:TextButton}={}
 for i,id in {"RikudoHY","RikudoHZ"} do
  local b=Instance.new("TextButton");b.Name=id;b.Size=UDim2.fromOffset(180,45);b.Position=UDim2.fromOffset((i-1)*190,0);b.BackgroundColor3=View.Card;b.TextColor3=View.Text;b.TextSize=12;b.Parent=rikudoPanel;View.border(b,View.Gold)
  b.Activated:Connect(function() Controller.BeginTarget(id) end);rangedButtons[id]=b
  b.MouseEnter:Connect(function() hovered=id;tooltip.Position=UDim2.fromOffset(520,-210);tooltip.Visible=true;tooltipText.Text=Config.Abilities[id].Name.." ["..Config.Abilities[id].KeyLabel.."]\n1800 маны • 60 с\nВыбери точку. Клавиша или кнопка → клик.\nEsc / ПКМ — отмена." end)
  b.MouseLeave:Connect(function() if hovered==id then hovered=nil;tooltip.Visible=false;tooltip.Position=UDim2.fromOffset(240,-146) end end)
 end
 local function bar(name: string,y: number,color: Color3): (Frame,TextLabel)
  local track=View.frame(panel,name,UDim2.fromOffset(450,17),UDim2.fromOffset(240,y)); track.BackgroundColor3=View.Card
  local fill=View.frame(track,"Fill",UDim2.fromScale(1,1),UDim2.new()); fill.BackgroundColor3=color
  local text=View.label(track,"Value",UDim2.fromScale(1,1),UDim2.new(),12); text.TextStrokeTransparency=.35; return fill,text
 end
 local hpFill,hpText=bar("Health",124,Color3.fromRGB(74,144,57))
 local mpFill,mpText=bar("Mana",143,Color3.fromRGB(42,105,171))
 local inventory: {{frame: Frame, name: TextLabel, id: string?}}={}
 for index=1,6 do
  local x,y=Layout.item(index)
  local slot=View.frame(panel,"Item"..index,UDim2.fromOffset(58,48),UDim2.fromOffset(x,y)); slot.BackgroundColor3=View.Card
  local name=View.label(slot,"Name",UDim2.new(1,0,0,20),UDim2.new(0,0,1,-20),9); name.ZIndex=2; name.TextWrapped=true; name.TextTruncate=Enum.TextTruncate.None; name.TextStrokeTransparency=.15
  View.border(slot,Color3.fromRGB(91,97,103)); table.insert(inventory,{frame=slot,name=name,id=nil})
 end
 local itemTitle=View.label(panel,"Inventory",UDim2.fromOffset(186,22),UDim2.fromOffset(704,0),11); itemTitle.Text="ПРЕДМЕТЫ"
 local message=View.label(gui,"AbilityMessage",UDim2.fromOffset(620,28),UDim2.new(.5,0,1,-180),14); message.AnchorPoint=Vector2.new(.5,1); message.TextColor3=View.Gold; message.TextStrokeTransparency=.3
 local nextUpdate=0
 RunService.Heartbeat:Connect(function()
  local now=workspace:GetServerTimeNow(); if now<nextUpdate then return end; nextUpdate=now+.1
  local camera=workspace.CurrentCamera
  if camera then
   scale.Scale=Layout.scale(camera.ViewportSize.X,camera.ViewportSize.Y)
   message.Position=UDim2.new(.5,0,1,-(Layout.ConsoleHeight*scale.Scale+12)); message.Size=UDim2.fromOffset(math.min(620,camera.ViewportSize.X-24),28)
  end
  local model=player.Character; View.updatePortrait(portrait,model)
  rikudoPanel.Visible=model~=nil and model:GetAttribute("RikudoRangedGranted")==true
  for id,b in rangedButtons do
   local left=Controller.Remaining(id);local reason=Controller.AbilityUnavailable(id)
   b.Active=left<=0 and reason==nil;b.AutoButtonColor=b.Active;b.BackgroundColor3=if b.Active then View.Card else Color3.fromRGB(31,29,35)
   b.Text=Config.Abilities[id].KeyLabel.."  "..Config.Abilities[id].Name.."\n"..(if left>0 then string.format("%.1f с",left) elseif reason then "1800 маны • недоступно" else "1800 маны • выбрать точку")
  end
  local state=player:FindFirstChild("HeroState")
  local function number(name: string): number local value=if state then state:GetAttribute(name) else nil; return if typeof(value)=="number" then value else 0 end
  local function shown(name: string,format: string): string local value=if state then state:GetAttribute(name) else nil; return if typeof(value)=="number" then string.format(format,value) else "—" end
  local humanoid=if model then model:FindFirstChildOfClass("Humanoid") else nil
  local hp=if humanoid then humanoid.Health else 0; local maximum=if humanoid then humanoid.MaxHealth else 1
  local mana=if model then model:GetAttribute("Mana") else nil; local maxMana=if model then model:GetAttribute("MaxMana") else nil
  local mp=if typeof(mana)=="number" then mana else 0; local maxMP=if typeof(maxMana)=="number" then maxMana else 1
  hpFill.Size=UDim2.fromScale(math.clamp(hp/math.max(1,maximum),0,1),1); hpText.Text=string.format("%d / %d",math.ceil(hp),maximum)
  mpFill.Size=UDim2.fromScale(math.clamp(mp/math.max(1,maxMP),0,1),1); mpText.Text=string.format("%d / %d",math.floor(mp),maxMP)
  level.Text=shown("Level","%d"); gold.Text=shown("Gold","%d GOLD")
  kda.Text=string.format("K/D/A  %d / %d / %d",number("TotalKills"),number("TotalDeaths"),number("Assists"))
  xpFill.Size=UDim2.fromScale(if number("XPToNextLevel")==0 then 1 else math.clamp(number("CurrentXP")/number("XPToNextLevel"),0,1),1)
  local profile=Combat.Profiles.OrangeNinja
  local rawAttack=profile.Damage*number("AttackDamageMultiplier")+number("AttackDamageBonus")
  local attacksPerSecond=BasicRules.speed(profile,number("Agility"))/profile.AttackCooldown
  stats.Text="STR  "..shown("Strength","%.1f").."\nAGI  "..shown("Agility","%.1f").."\nINT   "..shown("Intelligence","%.1f")..string.format("\nАтака %.1f · %.2f/с",rawAttack,attacksPerSecond).."\nБроня  "..shown("Defense","%.1f").."\nСкор.  "..shown("WalkSpeed","%.1f")
  statsText.Text="NARUTO  •  Уровень "..shown("Level","%d").."\nXP "..shown("CurrentXP","%d").." / "..shown("XPToNextLevel","%d").."\nОчки навыков: "..shown("SkillPoints","%d").."\n\n"..stats.Text.."\n\nМножитель M1  "..shown("AttackDamageMultiplier","x%.2f").."\nБонус M1  "..shown("AttackDamageBonus","+%.0f").."\nРеген. маны  "..shown("ManaRegen","%.2f/с")
  local owned={}; for _,id in Items.Order do if state and state:GetAttribute("Own_"..id)==true then table.insert(owned,id) end end
  for index,slot in inventory do
   local id=owned[index]
   if slot.id~=id then
    local old=slot.frame:FindFirstChild("Icon"); if old then old:Destroy() end
    if id then Icons.draw(slot.frame,id) end
    slot.id=id
   end
   slot.name.Text=if id then Items.Items[id].Name else "—"
  end
  local notice=if Learning.GetMessage()~="" then Learning.GetMessage() else Controller.GetMessage()
  local formStatus=Controller.GetFormStatus()
  message.Text=if notice~="" and formStatus~="" then notice.."\n"..formStatus else notice..formStatus
  points.Text=if number("SkillPoints")>0 then string.format("+ %d  •  Ctrl+1–5 / + для обучения",number("SkillPoints")) else "НАВЫКИ"
  for id,plus in learnButtons do plus.Visible=state~=nil and state:GetAttribute("LearnReason_"..id)=="Ready" end
  for id,button in buttons do
   local remaining=Controller.Remaining(id); local reason=Controller.AbilityUnavailable(id); local rank=number("Rank_"..id)
   local enabled=(Config.PrototypeEnabled :: {[string]: boolean})[id]==true
   button.Active=reason==nil and remaining<=0; button.AutoButtonColor=button.Active
   local shade=button:FindFirstChild("Cooldown") :: Frame
   shade.Visible=remaining>0 or reason~=nil or not enabled
   local cooldown=Config.Abilities[id].Cooldown
   if id=="ShadowClones" then local plan=CloneRanks.cloneRank(rank);if plan then cooldown=plan.cooldown end
   elseif id=="Gamakichi" then local _,cd=Gamakichi.rank(rank);if cd then cooldown=cd end end
   shade.Size=UDim2.fromScale(1,if remaining>0 then math.clamp(remaining/math.max(1,cooldown),0,1) else 1)
   local status=button:FindFirstChild("Status") :: TextLabel
   status.Text=if not enabled then "LOCK" elseif remaining>0 then tostring(math.ceil(remaining)) elseif reason then (if rank==0 and learnButtons[id] then "0" else "×") else ""
   local rankLabel=button:FindFirstChild("Rank") :: TextLabel; rankLabel.Text=if rank>0 then string.rep("●",math.min(rank,5)) else "○"
   if id=="SageMode" and model then
    local phase=model:GetAttribute("SagePhase"); local deadline=model:GetAttribute(if phase=="Preparing" then "SageReadyAt" else "SageExpiresAt")
    if (phase=="Preparing" or phase=="Active") and typeof(deadline)=="number" then
     status.Text=(if phase=="Preparing" then "P " else "S ")..tostring(math.max(0,math.ceil(deadline-now))); shade.Visible=true; shade.Size=UDim2.fromScale(1,1); shade.BackgroundColor3=Color3.fromRGB(89,51,19)
    else shade.BackgroundColor3=Color3.new() end
   end
   if hovered==id then
    local name=Config.Abilities[id].Name
    if id=="ShadowClones" then name="Теневые клоны "..({"I","II","III","IV"})[math.clamp(rank,1,4)] end
    if id=="ShadowClones" then name..=" | T: Sleep" elseif id=="Rasengan" then name="Rasengan "..({"I","II","III"})[math.clamp(rank,1,3)].." | Z / X" end
    tooltipText.Text=name.."  ["..Config.Abilities[id].KeyLabel.."]\nРанг: "..rank.."\n"..(if not enabled then "Ветка закрыта" elseif remaining>0 then string.format("Перезарядка: %.1f с",remaining) elseif reason then tostring(reason) else "Готово").."\n"..tostring(if state then state:GetAttribute("LearnReason_"..id) or "" else "")
   end
  end
 end)
end
return HUD
