--!strict
local Players=game:GetService("Players")
local Input=game:GetService("UserInputService")
local Actions=game:GetService("ContextActionService")
local Gui=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local Deck=require(Shared.Abilities.AbilityDeck)
local Config=require(Shared.Config.AbilityConfig)
local Controller=require(script.Parent.AbilityController)
local View=require(script.Parent.MobaHUDView)
local Icons=require(script.Parent.HUDIcons)
local Descriptions=require(script.Parent.AbilityDescriptions)
local Module={}
local started=false
function Module.Start(panel:Frame)
 if started then return end;started=true
 local player=Players.LocalPlayer
 local group=Deck.DefaultGroup;local page=1;local selected="Odama";local opened=false
 local hovered:string?=nil
 local function name(id:string):string
  if id=="KCM" then
   local state=player:FindFirstChild("HeroState");local rank=if state then state:GetAttribute("Rank_KCM") else 0
   return if rank==3 then "Рикудо" elseif rank==2 then "KCM II" else "KCM I"
  end
  return if id=="Rasengan" then "Расенган" elseif id=="ShadowClones" then "Теневые клоны" else Config.Abilities[id].Name
 end
 local function active(id:string):boolean
  local c=player.Character;if not c then return false end
  return (id=="KuramaForm" and c:GetAttribute("KuramaActive")==true) or (id=="KCM" and c:GetAttribute("KcmActive")==true)
   or (id=="SageMode" and c:GetAttribute("SagePhase")=="Active") or (id=="MeditationToggle" and c:GetAttribute("MeditationMode")==true)
 end
 local function status(id:string):string
  if active(id) then return "АКТИВЕН" end
  local remaining=Controller.Remaining(id)
  if remaining>0 then return string.format("КД %.1f с",remaining) end
  return Controller.AbilityUnavailable(id) or "Готово"
 end
 local function cost(id:string):string
  if id=="KuramaForm" then return "2500 чакры Курамы" end
  if id=="KCM" then return "200 чакры Курамы • 40/с" end
  if id=="KuramaConvert" then return "200 чакры Курамы → 200 маны" end
  return tostring(Controller.Cost(id)).." маны"
 end
 local function description(id:string):string
  return name(id).."  ["..Config.Abilities[id].KeyLabel.."]\n"..cost(id).."\n"..status(id).."\n\n"..((Descriptions :: {[string]:string})[id] or "")
 end
 local function button(parent:Instance,id:string,text:string,x:number,y:number,w:number,h:number):TextButton
  local b=Instance.new("TextButton");b.Name=id;b.Text=text;b.Position=UDim2.fromOffset(x,y);b.Size=UDim2.fromOffset(w,h)
  b.BackgroundColor3=View.Card;b.BorderSizePixel=0;b.TextColor3=View.Text;b.TextSize=13;b.Font=Enum.Font.GothamMedium;b.Parent=parent;View.border(b,View.Gold);return b
 end
 local quick=View.frame(panel,"TechniqueDeck",UDim2.fromOffset(450,80),UDim2.fromOffset(240,-88));quick.ZIndex=5
 local tabs:{[string]:TextButton}={}
 local book=View.frame(panel,"TechniqueBook",UDim2.fromOffset(760,390),UDim2.fromOffset(70,-398));book.ZIndex=12;book.Visible=false;View.border(book,View.Gold)
 local title=View.label(book,"Title",UDim2.fromOffset(650,30),UDim2.fromOffset(14,8),20);title.Text="ВСЕ ТЕХНИКИ • НАРУТО";title.TextXAlignment=Enum.TextXAlignment.Left
 local close=button(book,"Close","X",712,9,32,28)
 local bookTabs:{[string]:TextButton}={}
 local help=View.label(book,"Help",UDim2.fromOffset(730,24),UDim2.fromOffset(14,352),12);help.Text="Shift + 1–6 — выбранный набор • PgUp / PgDn — страницы • Tab / Esc — закрыть"
 local quickSlots:{TextButton}={};local cards:{TextButton}={}
 local detail=Instance.new("ScrollingFrame");detail.Name="Description";detail.Position=UDim2.fromOffset(454,82);detail.Size=UDim2.fromOffset(290,215)
 detail.BackgroundColor3=View.Card;detail.BorderSizePixel=0;detail.ScrollBarThickness=4;detail.CanvasSize=UDim2.new();detail.AutomaticCanvasSize=Enum.AutomaticSize.Y;detail.Parent=book
 local detailText=View.label(detail,"Text",UDim2.new(1,-24,0,0),UDim2.fromOffset(10,8),15);detailText.AutomaticSize=Enum.AutomaticSize.Y;detailText.TextWrapped=true;detailText.TextTruncate=Enum.TextTruncate.None;detailText.TextXAlignment=Enum.TextXAlignment.Left;detailText.TextYAlignment=Enum.TextYAlignment.Top
 local use=button(book,"Use","ПРИМЕНИТЬ",454,308,290,32)
 local tip=View.frame(panel,"DeckTooltip",UDim2.fromOffset(420,280),UDim2.fromOffset(240,-378));tip.ZIndex=15;tip.Visible=false;View.border(tip,View.Gold)
 local tipScroll=Instance.new("ScrollingFrame");tipScroll.Name="Scroll";tipScroll.Size=UDim2.new(1,-16,1,-16);tipScroll.Position=UDim2.fromOffset(8,8);tipScroll.BackgroundTransparency=1;tipScroll.BorderSizePixel=0;tipScroll.ScrollBarThickness=4;tipScroll.CanvasSize=UDim2.new();tipScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;tipScroll.Parent=tip
 local tipText=View.label(tipScroll,"Text",UDim2.new(1,-8,0,0),UDim2.new(),15);tipText.AutomaticSize=Enum.AutomaticSize.Y;tipText.TextWrapped=true;tipText.TextTruncate=Enum.TextTruncate.None;tipText.TextXAlignment=Enum.TextXAlignment.Left;tipText.TextYAlignment=Enum.TextYAlignment.Top
 local bookToggle=button(panel,"OpenTechniqueBook","Tab\nТехники",638,38,52,60);bookToggle.TextSize=11
 local pageLabel=View.label(quick,"Page",UDim2.fromOffset(54,20),UDim2.fromOffset(348,1),12)
 local prev=button(quick,"Previous","‹",326,1,22,20);local nextButton=button(quick,"Next","›",402,1,22,20)
 local bookPage=View.label(book,"Page",UDim2.fromOffset(120,26),UDim2.fromOffset(530,46),12)
 local bookPrev=button(book,"Previous","‹",492,46,30,26);local bookNext=button(book,"Next","›",662,46,30,26)
 local function setOpen(value:boolean)
  opened=value;book.Visible=value;hovered=nil;tip.Visible=false;player:SetAttribute("AbilityBookOpen",value)
  if value then Controller.CancelCloneCommand() end
 end
 local function cast(id:string)
  -- UI never grants a technique; all existing client and authoritative server gates still apply.
  setOpen(false)
  if id=="RasenshurikenThrow" then Controller.TryThrowRasenshuriken()
  elseif id=="CloneCommand" then Controller.BeginCloneCommand()
  else Controller.TryCast(id) end
 end
 local function redraw()
  local ids=Deck.page(group,page)
  player:SetAttribute("TechniqueDeckGroup",group);player:SetAttribute("TechniqueDeckPage",page)
  for i=1,6 do
   local id=ids[i]
   for _,b in {quickSlots[i],cards[i]} do
    b.Visible=id~=nil;b:SetAttribute("AbilityId",id)
    local old=b:FindFirstChild("Symbol");if old then old:Destroy() end
    if id then
     local symbol=View.frame(b,"Symbol",UDim2.fromOffset(30,30),UDim2.fromOffset(5,if b==quickSlots[i] then 2 else 8));Icons.draw(symbol,id)
    end
   end
  end
  selected=ids[1] or "Rasengan";detail.CanvasPosition=Vector2.zero
  pageLabel.Text=tostring(page).."/"..Deck.pages(group);bookPage.Text="Страница "..page.." / "..Deck.pages(group)
  for id,b in tabs do b.BackgroundColor3=if id==group then Color3.fromRGB(100,76,34) else View.Card end
  for id,b in bookTabs do b.BackgroundColor3=if id==group then Color3.fromRGB(100,76,34) else View.Card end
  for _,b in {prev,nextButton,bookPrev,bookNext} do b.Visible=Deck.pages(group)>1 end
 end
 for i=1,6 do
  local q=button(quick,"Slot"..i,"",(i-1)*75,27,70,50);quickSlots[i]=q
  local label=View.label(q,"Name",UDim2.new(1,-4,0,16),UDim2.fromOffset(2,33),10)
  local key=View.label(q,"Key",UDim2.fromOffset(36,16),UDim2.fromOffset(34,1),9);key.Text="Shift+"..i;key.TextColor3=View.Gold
  local state=View.label(q,"State",UDim2.fromOffset(36,14),UDim2.fromOffset(34,17),9)
  q.MouseEnter:Connect(function() hovered=q:GetAttribute("AbilityId") :: string?;tipScroll.CanvasPosition=Vector2.zero end)
  q.MouseLeave:Connect(function() hovered=nil end)
  q.Activated:Connect(function() local id=q:GetAttribute("AbilityId");if typeof(id)=="string" then cast(id) end end)
  local b=button(book,"Slot"..i,"",14+((i-1)%3)*144,82+math.floor((i-1)/3)*130,136,118);cards[i]=b
  local heading=View.label(b,"Name",UDim2.fromOffset(126,38),UDim2.fromOffset(5,42),13);heading.TextWrapped=true
  local shortcut=View.label(b,"Key",UDim2.fromOffset(89,32),UDim2.fromOffset(43,7),11);shortcut.TextColor3=View.Gold
  local reason=View.label(b,"State",UDim2.fromOffset(126,33),UDim2.fromOffset(5,80),11);reason.TextWrapped=true
  local function select() local id=b:GetAttribute("AbilityId");if typeof(id)=="string" and selected~=id then selected=id;detail.CanvasPosition=Vector2.zero end end
  b.MouseEnter:Connect(select);b.Activated:Connect(select)
 end
 for i,g in Deck.Groups do
  local b=button(quick,g.id,g.name,(i-1)*106,1,102,20);tabs[g.id]=b
  local bb=button(book,g.id,g.name,14+(i-1)*144,46,136,26);bookTabs[g.id]=bb
  local function choose() group=g.id;page=1;hovered=nil;redraw() end
  b.Activated:Connect(choose);bb.Activated:Connect(choose)
 end
 local function turn(delta:number) page=((page-1+delta)%Deck.pages(group))+1;hovered=nil;redraw() end
 prev.Activated:Connect(function() turn(-1) end);nextButton.Activated:Connect(function() turn(1) end)
 bookPrev.Activated:Connect(function() turn(-1) end);bookNext.Activated:Connect(function() turn(1) end)
 use.Activated:Connect(function() if not Controller.AbilityUnavailable(selected) and Controller.Remaining(selected)<=0 then cast(selected) end end)
 close.Activated:Connect(function() setOpen(false) end);bookToggle.Activated:Connect(function() setOpen(not opened) end)
 Actions:BindActionAtPriority("TechniqueDeckKeys",function(_,state,input)
  if Input:GetFocusedTextBox() or Gui.MenuIsOpen or player:GetAttribute("ShopOpen")==true or player:GetAttribute("DeveloperConsoleOpen")==true or player:GetAttribute("StatsOpen")==true then return Enum.ContextActionResult.Pass end
  local key=input.KeyCode.Name;local modifier=Input:IsKeyDown(Enum.KeyCode.LeftShift) or Input:IsKeyDown(Enum.KeyCode.RightShift)
  local control=Input:IsKeyDown(Enum.KeyCode.LeftControl) or Input:IsKeyDown(Enum.KeyCode.RightControl)
  local slot=Deck.slot(key,modifier,control,false,false)
  local owns=key=="Tab" or (opened and key=="Escape") or ((opened or modifier) and (key=="PageUp" or key=="PageDown")) or slot~=nil
  if not owns then return Enum.ContextActionResult.Pass end
  if state==Enum.UserInputState.Begin then
   if key=="Tab" then setOpen(not opened)
   elseif key=="Escape" then setOpen(false)
   elseif key=="PageUp" or key=="PageDown" then turn(if key=="PageUp" then -1 else 1)
   elseif slot then local id=Deck.page(group,page)[slot];if id then cast(id) end end
  end
  return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value+50,Enum.KeyCode.Tab,Enum.KeyCode.Escape,Enum.KeyCode.PageUp,Enum.KeyCode.PageDown,Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six)
 player.CharacterRemoving:Connect(function() setOpen(false) end)
 Input.WindowFocusReleased:Connect(function() setOpen(false) end)
 require(script.Parent.RoundController).Watch(function() setOpen(false) end)
 redraw()
 local last=0
 RunService.Heartbeat:Connect(function()
  if os.clock()-last<.1 then return end;last=os.clock()
  if player:GetAttribute("ShopOpen")==true or player:GetAttribute("StatsOpen")==true or player:GetAttribute("DeveloperConsoleOpen")==true or Gui.MenuIsOpen then setOpen(false) end
  local c=player.Character;local h=if c then c:FindFirstChildOfClass("Humanoid") else nil
  if opened and (not h or h.Health<=0) then setOpen(false) end
  for i=1,6 do
   for _,b in {quickSlots[i],cards[i]} do
    local id=b:GetAttribute("AbilityId");if typeof(id)~="string" then continue end
    (b:FindFirstChild("Name") :: TextLabel).Text=name(id)
    local unavailable=Controller.AbilityUnavailable(id);local remaining=Controller.Remaining(id)
    local state=b:FindFirstChild("State") :: TextLabel
    state.Text=if b==cards[i] then status(id) elseif active(id) then "ВКЛ" elseif remaining>0 then tostring(math.ceil(remaining)) elseif unavailable then "×" else ""
    state.TextColor3=if active(id) then Color3.fromRGB(127,224,165) elseif unavailable or remaining>0 then Color3.fromRGB(193,164,134) else View.Text
    if b==cards[i] then (b:FindFirstChild("Key") :: TextLabel).Text="Shift+"..i.."\n["..Config.Abilities[id].KeyLabel.."]" end
    b.BackgroundColor3=if active(id) then Color3.fromRGB(38,85,64) elseif b==cards[i] and selected==id then Color3.fromRGB(83,68,38) else View.Card
   end
  end
  if opened then
   detailText.Text=description(selected)
   local ready=not Controller.AbilityUnavailable(selected) and Controller.Remaining(selected)<=0
   use.Text=if ready then "ПРИМЕНИТЬ  •  "..Config.Abilities[selected].KeyLabel else "НЕДОСТУПНО • условие выше"
   use.BackgroundColor3=if ready then Color3.fromRGB(40,105,76) else View.Card;use.AutoButtonColor=ready
  end
  tip.Visible=hovered~=nil and not opened
  if hovered then tipText.Text=description(hovered) end
 end)
end
return Module
