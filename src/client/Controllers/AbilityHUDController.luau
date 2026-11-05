--!strict
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInput=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items=require(Shared.Config.ItemConfig)
local Combat=require(Shared.Config.CombatConfig)
local BasicRules=require(Shared.Combat.BasicAttackRules)
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
 local statsToggle=Instance.new("TextButton"); statsToggle.Name="StatsToggle"; statsToggle.Text="I  Характеристики"; statsToggle.Size=UDim2.fromOffset(116,23); statsToggle.Position=UDim2.fromOffset(119,137); statsToggle.TextSize=10; statsToggle.BackgroundColor3=View.Card; statsToggle.TextColor3=View.Gold; statsToggle.Parent=panel
 local statsPanel=View.frame(panel,"CharacterStats",UDim2.fromOffset(300,300),UDim2.fromOffset(0,-310)); statsPanel.Visible=false; View.border(statsPanel,View.Gold)
 local statsText=View.label(statsPanel,"Values",UDim2.new(1,-24,1,-24),UDim2.fromOffset(12,12),14); statsText.TextXAlignment=Enum.TextXAlignment.Left; statsText.TextYAlignment=Enum.TextYAlignment.Top
 local function toggle() statsPanel.Visible=not statsPanel.Visible; player:SetAttribute("StatsOpen",statsPanel.Visible) end
 statsToggle.Activated:Connect(toggle)
 UserInput.InputBegan:Connect(function(input,processed) if not processed and not UserInput:GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.I then toggle() end end)
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
 local commands=View.label(gui,"SummonCommands",UDim2.fromOffset(620,24),UDim2.new(.5,0,1,-220),13); commands.AnchorPoint=Vector2.new(.5,1); commands.TextColor3=View.Gold; commands.TextStrokeTransparency=.3
 require(script.Parent.AbilityFamilyController).Start(panel)
 local nextUpdate=0
 RunService.Heartbeat:Connect(function()
  local now=workspace:GetServerTimeNow(); if now<nextUpdate then return end; nextUpdate=now+.1
  local camera=workspace.CurrentCamera
  if camera then
   scale.Scale=Layout.scale(camera.ViewportSize.X,camera.ViewportSize.Y)
   local strip=panel:FindFirstChild("FamilyChoices");local deck=if strip and strip:IsA("Frame") and strip.Visible then strip.Size.Y.Offset+8 else Layout.DeckHeight
   message.Position=UDim2.new(.5,0,1,-((Layout.ConsoleHeight+deck)*scale.Scale+12)); message.Size=UDim2.fromOffset(math.min(900,camera.ViewportSize.X-24),40)
  end
  local model=player.Character; View.updatePortrait(portrait,model)
  commands.Visible=model~=nil and (((model:GetAttribute("NativeCloneCount") or 0) :: number)>0 or ((model:GetAttribute("GamakichiCount") or 0) :: number)>0)
  commands.Position=message.Position-UDim2.fromOffset(0,40)
  local order=tostring(if model then model:GetAttribute("SummonOrder") or "Follow" else "Follow")
  commands.Text="E → X — атаковать · E → V — ко мне · E → B — стоять  ["..(if order=="Hold" then "Стоять" elseif order=="Command" then "Атака" else "Автобой").."]"
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
  local profile=Combat.Profiles[if model then tostring(model:GetAttribute("CombatProfileId")) else "OrangeNinja"] or Combat.Profiles.OrangeNinja
  local rawAttack=profile.Damage*number("AttackDamageMultiplier")+number("AttackDamageBonus")
  local attacksPerSecond=BasicRules.speed(profile,number("Agility"))/profile.AttackCooldown
  stats.Text="STR  "..shown("Strength","%.1f").."\nAGI  "..shown("Agility","%.1f").."\nINT   "..shown("Intelligence","%.1f")..string.format("\nАтака %.1f · %.2f/с",rawAttack,attacksPerSecond).."\nБроня  "..shown("Defense","%.1f").."\nСкор.  "..shown("WalkSpeed","%.1f")
  hero.Text=if player:GetAttribute("HeroId")=="Sasuke" then "SASUKE" else "NARUTO"
  statsText.Text=hero.Text.."  •  Уровень "..shown("Level","%d").."\nXP "..shown("CurrentXP","%d").." / "..shown("XPToNextLevel","%d").."\nОчки навыков: "..shown("SkillPoints","%d").."\n\n"..stats.Text.."\n\nМножитель M1  "..shown("AttackDamageMultiplier","x%.2f").."\nБонус M1  "..shown("AttackDamageBonus","+%.0f").."\nРеген. маны  "..shown("ManaRegen","%.2f/с")
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
  local familyTip=panel:FindFirstChild("FamilyTooltip")
  message.Visible=not (familyTip and familyTip:IsA("GuiObject") and familyTip.Visible)
  if not message.Visible then commands.Visible=false end
  message.Text=if notice~="" and formStatus~="" then notice.."\n"..formStatus else notice..formStatus
  points.Text=if number("SkillPoints")>0 then string.format((if player:GetAttribute("HeroId")=="Sasuke" then "+ %d  •  Ctrl+1–4 / + для обучения" else "+ %d  •  Ctrl+1–5 / + для обучения"),number("SkillPoints")) else "НАВЫКИ"

 end)
end
return HUD
