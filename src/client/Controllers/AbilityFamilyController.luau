--!strict
local Players=game:GetService("Players")
local Input=game:GetService("UserInputService")
local Gui=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local NarutoFamilies=require(Shared.Abilities.AbilityFamilies)
local SasukeFamilies=require(Shared.Abilities.SasukeFamilies)
local Sasuke=require(Shared.Abilities.SasukeDefinitions)
local Families:any=NarutoFamilies
local Config=require(Shared.Config.AbilityConfig)
local Controller=require(script.Parent.AbilityController)
local Learning=require(script.Parent.LearningController)
local View=require(script.Parent.MobaHUDView)
local Icons=require(script.Parent.HUDIcons)
local Descriptions=require(script.Parent.AbilityDescriptions)
local Module={}
local started=false
function Module.Start(panel:Frame)
 if started then return end;started=true
 local player=Players.LocalPlayer
 Families=if player:GetAttribute("HeroId")=="Sasuke" then SasukeFamilies else NarutoFamilies
 local function isSasuke():boolean return player:GetAttribute("HeroId")=="Sasuke" end
 local opened:string?=nil;local hovered:string?=nil;local hoveredFamily:string?=nil;local hoveredEntry:NarutoFamilies.Entry?=nil
 local roots:{[string]:TextButton}={};local choices:{TextButton}={};local learnButtons:{{button:TextButton,id:string}}={}
 local strip=View.frame(panel,"FamilyChoices",UDim2.fromOffset(450,194),UDim2.fromOffset(240,-202));strip.Visible=false;strip.ZIndex=6;View.border(strip,View.Gold)
 local title=View.label(strip,"Title",UDim2.fromOffset(372,21),UDim2.fromOffset(7,1),13);title.TextXAlignment=Enum.TextXAlignment.Left;title.TextColor3=View.Gold
 local footer=View.label(strip,"Hint",UDim2.fromOffset(436,18),UDim2.fromOffset(7,175),11);footer.Text="Клавиша — выбор · ЛКМ — цель · ПКМ — отмена · Alt — курсор"
 local tip=View.frame(panel,"FamilyTooltip",UDim2.fromOffset(440,260),UDim2.fromOffset(240,-470));tip.Visible=false;tip.ZIndex=10;View.border(tip,View.Gold)
 local hoverEpoch=0;local tipHovered=false
 local function retainHover() hoverEpoch+=1 end
 local function leaveHover()
  hoverEpoch+=1;local epoch=hoverEpoch
  task.delay(.18,function() if hoverEpoch==epoch and not tipHovered then hovered=nil;hoveredFamily=nil;hoveredEntry=nil end end)
 end
 tip.MouseEnter:Connect(function() tipHovered=true;retainHover() end)
 tip.MouseLeave:Connect(function() tipHovered=false;leaveHover() end)
 local scroll=Instance.new("ScrollingFrame");scroll.Name="Scroll";scroll.Size=UDim2.new(1,-16,1,-16);scroll.Position=UDim2.fromOffset(8,8);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=4;scroll.CanvasSize=UDim2.new();scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;scroll.Parent=tip
 local tipText=View.label(scroll,"Text",UDim2.new(1,-8,0,0),UDim2.new(),15);tipText.AutomaticSize=Enum.AutomaticSize.Y;tipText.TextWrapped=true;tipText.TextTruncate=Enum.TextTruncate.None;tipText.TextXAlignment=Enum.TextXAlignment.Left;tipText.TextYAlignment=Enum.TextYAlignment.Top
 local function makeButton(parent:Instance,name:string,x:number,y:number,w:number,h:number):TextButton
  local b=Instance.new("TextButton");b.Name=name;b.Text="";b.Size=UDim2.fromOffset(w,h);b.Position=UDim2.fromOffset(x,y);b.BackgroundColor3=View.Card;b.BorderSizePixel=0;b.Parent=parent;View.border(b,View.Gold);return b
 end
 local function icon(button:TextButton,id:string)
  if button:GetAttribute("IconId")==id then return end
  button:SetAttribute("IconId",id);local symbol=button:FindFirstChild("Symbol") :: Frame
  symbol:ClearAllChildren();Icons.draw(symbol,id)
 end
 local function labelName(entry:NarutoFamilies.Entry):string
  if entry.id=="KCM" then
   local hero=player:FindFirstChild("HeroState");local rank=if hero then hero:GetAttribute("Rank_KCM") else 0
   return if rank==3 then "Рикудо" elseif rank==2 then "KCM II" else "KCM I"
  end
  return entry.name
 end
 local function close()
  opened=nil;strip.Visible=false;hovered=nil;hoveredEntry=nil;player:SetAttribute("AbilityFamily",nil)
 end
 local function blocked():boolean
  local c=player.Character;local h=if c then c:FindFirstChildOfClass("Humanoid") else nil
  return not h or h.Health<=0 or Input:GetFocusedTextBox()~=nil or Gui.MenuIsOpen or player:GetAttribute("HeroSelectionOpen")==true or player:GetAttribute("ShopOpen")==true or player:GetAttribute("StatsOpen")==true or player:GetAttribute("DeveloperConsoleOpen")==true
 end
 local function open(key:string)
  if blocked() then return end
  Controller.CancelCloneCommand();opened=key;hovered=nil;hoveredEntry=nil;hoveredFamily=nil;player:SetAttribute("AbilityFamily",key)
  local family=Families.Definitions[key];local height=if #family.entries>6 then 194 else 118;strip.Size=UDim2.fromOffset(450,height);strip.Position=UDim2.fromOffset(240,-height-8);footer.Position=UDim2.fromOffset(7,height-19);tip.Position=UDim2.fromOffset(240,-height-276);strip.Visible=true;title.Text=family.name..(if key=="E" then " • команды всем боевым призывам" else " • выберите продолжение")
  for i,b in choices do
   local entry=family.entries[i];b.Visible=entry~=nil;b:SetAttribute("AbilityId",if entry then entry.id else nil)
   if entry then
    (b:FindFirstChild("Key") :: TextLabel).Text=entry.key
    icon(b,if entry.id=="MeditationCast" then "MeditationToggle" else entry.id)
   end
  end
 end
 local function rootPress(key:string)
  if blocked() then return end
  open(key)
  if key=="Q" then
   local c=player.Character
   if isSasuke() then
    if not c or c:GetAttribute("ChidoriHeld")~=true then Controller.TryCast("Chidori") end
   elseif not c or c:GetAttribute("RasenganHeld")~=true then Controller.TryCast("Rasengan") end
  end
 end
 local function activate(entry:NarutoFamilies.Entry)
  if blocked() then return end
  local old=opened;close()
  local ok=if entry.command then Controller.Command(entry.command)
   elseif entry.id=="CloneCommand" then Controller.BeginCloneCommand() else Controller.TryCast(entry.id)
  if not ok and old then
   -- Keep the explanation/choices visible without erasing the rejection message.
   opened=old;strip.Visible=true;player:SetAttribute("AbilityFamily",old)
  end
 end
 local function addLearn(parent:TextButton,id:string)
  local plus=makeButton(parent,"Learn",parent.Size.X.Offset-18,-19,18,18);plus.Text="+";plus.TextSize=17;plus.TextColor3=View.Gold;plus.ZIndex=5
  local entry={button=plus,id=id};plus.Activated:Connect(function() Learning.TryLearn(entry.id) end);table.insert(learnButtons,entry)
 end
 for i,key in Families.Order do
  local family=Families.Definitions[key]
  local b=makeButton(panel,"Family"..key,240+(i-1)*75,32,70,78);roots[key]=b
  View.frame(b,"Symbol",UDim2.fromOffset(48,48),UDim2.fromOffset(11,3));icon(b,family.icon)
  local keyText=View.label(b,"Key",UDim2.fromOffset(24,18),UDim2.fromOffset(2,-18),15);keyText.Text=key;keyText.TextColor3=View.Gold
  local name=View.label(b,"Name",UDim2.fromOffset(68,25),UDim2.fromOffset(1,50),11);name.Text=family.name;name.TextWrapped=true
  local status=View.label(b,"Status",UDim2.fromOffset(48,20),UDim2.fromOffset(11,18),15);status.TextStrokeTransparency=.1;status.ZIndex=3
  b.Activated:Connect(function() local _,entry=Families.resolve(opened,key);if entry then activate(entry) else rootPress(key) end end)
  b.MouseEnter:Connect(function() retainHover();hoveredFamily=key;hovered=nil;hoveredEntry=nil;scroll.CanvasPosition=Vector2.zero end)
  b.MouseLeave:Connect(leaveHover)
  if key=="Q" then addLearn(b,if isSasuke() then "SasukeLightning" else "Rasengan") elseif key=="E" then addLearn(b,if isSasuke() then "SasukeFire" else "ShadowClones") elseif key=="R" then addLearn(b,if isSasuke() then "SasukeSummon" else "Gamakichi") elseif key=="C" then addLearn(b,"SasukeEyes") end
 end
 for i=1,12 do
  local b=makeButton(strip,"Choice"..i,((i-1)%6)*75+2,25+math.floor((i-1)/6)*75,70,71);choices[i]=b
  View.frame(b,"Symbol",UDim2.fromOffset(25,25),UDim2.fromOffset(4,3))
  local key=View.label(b,"Key",UDim2.fromOffset(34,23),UDim2.fromOffset(32,3),16);key.TextColor3=View.Gold
  local name=View.label(b,"Name",UDim2.fromOffset(66,26),UDim2.fromOffset(2,29),11);name.TextWrapped=true
  View.label(b,"State",UDim2.fromOffset(66,14),UDim2.fromOffset(2,55),10)
  b.Activated:Connect(function() if opened then local entry=Families.Definitions[opened].entries[i];if entry then activate(entry) end end end)
  b.MouseEnter:Connect(function() retainHover();hovered=b:GetAttribute("AbilityId") :: string?;hoveredEntry=if opened then Families.Definitions[opened].entries[i] else nil;hoveredFamily=nil;scroll.CanvasPosition=Vector2.zero end)
  b.MouseLeave:Connect(leaveHover)
 end
 -- Mode learning remains visible on its own choice, independent of the six families.
 local sageLearn=makeButton(strip,"LearnSage",386,2,27,20);sageLearn.Text="4+";sageLearn.TextColor3=View.Gold;sageLearn.TextSize=17;sageLearn.ZIndex=5
 local kcmLearn=makeButton(strip,"LearnKCM",418,2,27,20);kcmLearn.Text="5+";kcmLearn.TextColor3=View.Gold;kcmLearn.TextSize=17;kcmLearn.ZIndex=5
 sageLearn.Activated:Connect(function() Learning.TryLearn("SageMode") end);kcmLearn.Activated:Connect(function() Learning.TryLearn("KCM") end)
 local function overHUD(input:InputObject):boolean
  local gui=player:FindFirstChildOfClass("PlayerGui");if not gui then return false end
  for _,object in gui:GetGuiObjectsAtPosition(input.Position.X,input.Position.Y) do if object:IsDescendantOf(panel.Parent :: Instance) then return true end end
  return false
 end
 Input.InputBegan:Connect(function(input,processed)
  if blocked() then close();return end
  if input.UserInputType==Enum.UserInputType.MouseButton2 or input.KeyCode==Enum.KeyCode.Escape then close();return end
  if processed then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 then if not overHUD(input) then close() end;return end
  local key=input.KeyCode.Name
  if Input:IsKeyDown(Enum.KeyCode.LeftControl) or Input:IsKeyDown(Enum.KeyCode.RightControl) then local id=Families.learning(key);if id then Learning.TryLearn(id) end;return end
  local kind,entry=Families.resolve(opened,key)
  if entry then activate(entry)
  elseif kind=="Open" then rootPress(key)
  elseif not opened and (key=="Z" or key=="X") and player.Character and player.Character:GetAttribute("RasenganHeld")==true then
   Controller.TryCast(if key=="Z" then "Odama" else "Rasenshuriken")
  end
 end)
 Input.WindowFocusReleased:Connect(close);player.CharacterRemoving:Connect(close);require(script.Parent.RoundController).Watch(close)
 local nextUpdate=0;local lastForm=""
 RunService.Heartbeat:Connect(function()
  local now=workspace:GetServerTimeNow();if now<nextUpdate then return end;nextUpdate=now+.1
  local c=player.Character;local hero=player:FindFirstChild("HeroState")
  local desired=if isSasuke() then SasukeFamilies else NarutoFamilies
  if Families~=desired then
   Families=desired;close()
   for key,b in roots do local family=Families.Definitions[key];icon(b,family.icon);(b:FindFirstChild("Name") :: TextLabel).Text=family.name end
   for i,entry in learnButtons do entry.id=if isSasuke() then Sasuke.LearningOrder[i] else ({"Rasengan","ShadowClones","Gamakichi","SasukeEyes"})[i] end
  end
  local form=if c then tostring(c:GetAttribute("HeroVisualForm"))..":"..tostring(c:GetAttribute("LifeId"))..":"..tostring(c:GetAttribute("SageTechniquesReady")) else ""
  if form~=lastForm then close();Controller.CancelCloneCommand();lastForm=form end
  if blocked() then close() end
  for _,learn in learnButtons do learn.button.Visible=(learn.id~="SasukeEyes" or isSasuke()) and hero~=nil and hero:GetAttribute("LearnReason_"..learn.id)=="Ready" end
  sageLearn.Visible=not isSasuke() and opened=="C" and hero~=nil and hero:GetAttribute("LearnReason_SageMode")=="Ready"
  kcmLearn.Visible=not isSasuke() and opened=="C" and hero~=nil and hero:GetAttribute("LearnReason_KCM")=="Ready"
  for key,b in roots do
   b.BackgroundColor3=if key==opened then Color3.fromRGB(100,77,35) else View.Card
   local status=b:FindFirstChild("Status") :: TextLabel;status.Text=""
   if isSasuke() then
    if key=="Q" then local held=c and c:GetAttribute("ChidoriHeld")==true;local remaining=Controller.Remaining("Chidori");status.Text=if held then "ЧИДОРИ" elseif remaining>0 then tostring(math.ceil(remaining)) else "";status.TextSize=10
    elseif key=="C" and c then local mode=c:GetAttribute("SasukeMode");status.Text=if mode==3 then "РИННЕГАН" elseif mode==2 then "МАНГЕКЁ" elseif mode==1 then "ШАРИНГАН" else "";status.TextSize=9 end
   elseif key=="Q" then
    local held=c~=nil and c:GetAttribute("RasenganHeld")==true
    local variant=if held and c then tostring(c:GetAttribute("RasenganVariant")) else "Rasengan"
    icon(b,if Config.Abilities[variant] then variant else "Rasengan")
    local remaining=Controller.Remaining("Rasengan")
    status.Text=if held and c then (if now<((c:GetAttribute("RasenganReadyAt") or 0) :: number) then "…" else "ГОТОВ") elseif remaining>0 then tostring(math.ceil(remaining)) else ""
    status.TextColor3=if held then Color3.fromRGB(150,240,255) else View.Text
   elseif key=="R" and c and ((c:GetAttribute("GamakichiCount") or 0) :: number)>0 then status.Text=if c:GetAttribute("SummonOrder")=="Hold" then "СТОИТ" else "АВТО";status.TextSize=11
   elseif key=="C" and c then status.Text=if c:GetAttribute("KuramaActive")==true then "КУРАМА" elseif c:GetAttribute("KcmActive")==true then (if c:GetAttribute("KcmRank")==3 then "РИКУДО" else "KCM") elseif c:GetAttribute("SagePhase")=="Active" then "МУДРЕЦ" else "";status.TextSize=10 end
  end
  if opened then
   for i,b in choices do
    local entry=Families.Definitions[opened].entries[i];if not entry then continue end
    (b:FindFirstChild("Name") :: TextLabel).Text=labelName(entry)
    local reason=Controller.AbilityUnavailable(entry.id);local remaining=Controller.Remaining(entry.id)
    local active=c~=nil and ((entry.id=="KCM" and c:GetAttribute("KcmActive")==true) or (entry.id=="KuramaForm" and c:GetAttribute("KuramaActive")==true) or (entry.id=="SageMode" and c:GetAttribute("SagePhase")=="Active"))
    local state=b:FindFirstChild("State") :: TextLabel
    state.Text=if active then "АКТИВЕН" elseif remaining>0 then math.ceil(remaining).." с" elseif reason then "Недоступно" else "Готово"
    state.TextColor3=if not reason and remaining<=0 then Color3.fromRGB(120,224,158) else Color3.fromRGB(210,167,130)
   end
  end
  tip.Visible=(hovered~=nil or hoveredFamily~=nil) and not blocked()
  if hoveredFamily then
   local family=Families.Definitions[hoveredFamily];local text=family.name.." ["..family.key.."]\n\n"..family.hint.."\n\n"
   for _,entry in family.entries do text..=family.key.." → "..entry.key.."  "..labelName(entry).."\n" end
   if hoveredFamily=="Q" and isSasuke() then text..="\n90 чакры • КД 60 с • молния I, уровень 4\n"..Sasuke.Spells.Chidori.description.."\n" end
   if hoveredFamily=="Q" and not isSasuke() then text..="\n100 маны • "..(Controller.AbilityUnavailable("Rasengan") or "Готово").."\n"..Descriptions.Rasengan.."\n" end
   tipText.Text=text.."\nПервое нажатие открывает выбор"..(if hoveredFamily=="Q" then (if isSasuke() then " и формирует Чидори." else " и формирует Расенган.") else ", чакра не расходуется.")
  elseif hovered then
   local id=hovered;local def=Config.Abilities[id]
   local resource=if id=="KuramaForm" then "2500 чакры Курамы" elseif id=="KCM" then "200 чакры Курамы • 40/с" elseif id=="KuramaConvert" then "200 чакры Курамы → 200 маны" else Controller.Cost(id).." маны"
   local entry=hoveredEntry
   local name=if Sasuke.Spells[id] then Sasuke.Spells[id].name elseif entry then labelName(entry) else def.Name
   local binding=if entry and opened then opened.." → "..entry.key else def.KeyLabel
   local description=if entry and entry.command=="Follow" then "Возвращает всех боевых клонов и Гамакичи к Наруто. После возвращения клоны снова ищут врагов рядом с владельцем, а Гамакичи самостоятельно сражается и атакует вышки." elseif entry and entry.command=="Hold" then "Оставляет всех боевых клонов и Гамакичи на текущих позициях без автоматических атак. E → V отзывает их к Наруто и возобновляет автобой; E → X задаёт цель." else (if Sasuke.Spells[id] then Sasuke.Spells[id].description.."\nРанг "..Sasuke.Spells[id].rank.." • "..Sasuke.Learning[Sasuke.Spells[id].line].name else (Descriptions :: {[string]:string})[id] or "")
   if Sasuke.Spells[id] then local d=Sasuke.Spells[id];local rank=if hero then (hero:GetAttribute("Rank_"..d.line) or 0) :: number else 0;resource..=" • КД "..Sasuke.cooldown(id,rank).." с" end
   tipText.Text=name.." ["..binding.."]\n"..resource.."\n"..(Controller.AbilityUnavailable(id) or (if Controller.Remaining(id)>0 then "КД "..math.ceil(Controller.Remaining(id)).." с" else "Готово")).."\n\n"..description
  end
 end)
end
return Module
