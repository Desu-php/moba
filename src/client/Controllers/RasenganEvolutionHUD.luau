--!strict
-- A permanent explanation of the existing 1 -> Z -> X technique, not new spells.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Controller = require(script.Parent.AbilityController)
local View = require(script.Parent.MobaHUDView)
local Icons = require(script.Parent.HUDIcons)
local Layout = require(script.Parent.HUDLayout)

local HUD = {}
local started = false
local ids = { "Rasengan", "Odama", "Rasenshuriken" }
local names = { "Расенган", "Одама Расенган", "Расенсюрикен" }
local keys = { "1", "Z", "X" }
local colors = { Color3.fromRGB(81,189,255), Color3.fromRGB(105,220,255), Color3.fromRGB(192,250,255) }
type Card = { button: TextButton, stroke: UIStroke, key: TextLabel, state: TextLabel, progress: Frame, icon: Frame }
local function number(model: Instance?, name: string): number
	local n = if model then model:GetAttribute(name) else nil
	return if typeof(n) == "number" then n else 0
end

function HUD.Start(gui: ScreenGui)
	if started then return end; started = true
	local player = Players.LocalPlayer
	local panel = View.frame(gui,"RasenganEvolution",UDim2.fromOffset(278,294),UDim2.new(0,18,1,-190))
	panel.AnchorPoint = Vector2.new(0,1); panel.BackgroundTransparency = .08
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,8); corner.Parent = panel
	local outline = Instance.new("UIStroke"); outline.Color = Color3.fromRGB(62,100,124); outline.Transparency = .3; outline.Parent = panel
	local scale = Instance.new("UIScale"); scale.Parent = panel
	local header = View.label(panel,"Heading",UDim2.new(1,-24,0,32),UDim2.fromOffset(12,3),12)
	header.TextWrapped = true
	header.TextXAlignment = Enum.TextXAlignment.Left; header.Font = Enum.Font.GothamBold
	local footer = View.label(panel,"Instruction",UDim2.new(1,-24,0,47),UDim2.fromOffset(12,241),12)
	footer.TextWrapped = true
	footer.TextColor3 = Color3.fromRGB(179,198,212); footer.TextXAlignment = Enum.TextXAlignment.Left
	local cards: {Card} = {}
	for i,id in ids do
		local button = Instance.new("TextButton"); button.Name = id; button.Text = ""
		button.Position = UDim2.fromOffset(12,38+(i-1)*68); button.Size = UDim2.fromOffset(254,60)
		button.BackgroundColor3 = Color3.fromRGB(28,37,49); button.BorderSizePixel = 0; button.Parent = panel
		local round = Instance.new("UICorner"); round.CornerRadius = UDim.new(0,5); round.Parent = button
		local stroke = Instance.new("UIStroke"); stroke.Color = colors[i]; stroke.Transparency = .7; stroke.Parent = button
		local iconHolder = View.frame(button,"Symbol",UDim2.fromOffset(44,44),UDim2.fromOffset(7,10))
		local icon = Icons.draw(iconHolder,id)
		local name = View.label(button,"Name",UDim2.fromOffset(190,22),UDim2.fromOffset(57,5),13)
		name.TextXAlignment = Enum.TextXAlignment.Left; name.Font = Enum.Font.GothamBold; name.Text = names[i]
		local state = View.label(button,"State",UDim2.fromOffset(190,20),UDim2.fromOffset(57,30),11)
		state.TextXAlignment = Enum.TextXAlignment.Left
		local key = View.label(iconHolder,"Key",UDim2.fromOffset(18,18),UDim2.fromOffset(-3,-5),12)
		key.BackgroundTransparency = 0; key.BackgroundColor3 = Color3.fromRGB(9,17,25); key.Font = Enum.Font.GothamBold; key.Text = keys[i]; key.ZIndex = 3
		local progress = View.frame(button,"Window",UDim2.new(0,0,0,3),UDim2.new(0,0,1,-3)); progress.BackgroundColor3 = colors[i]
		button.Activated:Connect(function() Controller.TryCast(id) end)
		cards[i] = {button=button,stroke=stroke,key=key,state=state,progress=progress,icon=icon}
		if i<3 then
			local arrow = View.label(panel,"Arrow"..i,UDim2.fromOffset(20,12),UDim2.fromOffset(129,96+(i-1)*68),11)
			arrow.Text = "↓"; arrow.TextColor3 = colors[i+1]
		end
	end
	RunService.RenderStepped:Connect(function()
		local model = player.Character
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		panel.Visible = humanoid ~= nil and humanoid.Health>0 and player:GetAttribute("ShopOpen")~=true
			and player:GetAttribute("StatsOpen")~=true and not GuiService.MenuIsOpen and (not model or model:GetAttribute("RikudoRangedGranted")~=true)
		if not panel.Visible then return end
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y/900,.72,1)
			panel.Position = UDim2.new(0,18,1,-(Layout.ConsoleHeight*Layout.scale(camera.ViewportSize.X,camera.ViewportSize.Y)+18))
		end
		local now = workspace:GetServerTimeNow()
		local profile = player:FindFirstChild("HeroState")
		local rank = number(profile,"Rank_Rasengan")
		local phase = if model then model:GetAttribute("RasenganPhase") else nil
		local variant = if model then model:GetAttribute("RasenganVariant") else nil
		local current = if typeof(variant)=="string" then table.find(ids,variant) or 0 else 0
		local active = current>0 and (phase=="Preparing" or phase=="Holding" or phase=="Consumed")
		local ordinary = model ~= nil and model:GetAttribute("KcmActive")~=true and model:GetAttribute("KuramaActive")~=true
			and (model:GetAttribute("SagePhase")==nil or model:GetAttribute("SagePhase")=="")
		local window = if active and ordinary then math.max(0,number(model,"RasenganVariantUntil")-now) else 0
		local nextIndex = if current<3 and window>0 then current+1 else 0
		local ready = math.max(0,number(model,"RasenganReadyAt")-now,if phase~="Consumed" then number(model,"RasenganSelfPauseUntil")-now else 0)
		header.Text = "РАСЕНГАН  /  ЦЕПОЧКА УСИЛЕНИЙ"
		header.TextColor3 = colors[1]
		footer.Text = "1 → Z → X  ·  На каждое усиление — 1 секунда.  Alt — курсор."
		if not ordinary then
			footer.Text = "Усиления Z и X доступны в обычной форме Наруто."
		elseif rank==0 then
			footer.Text = "Изучите Расенган: Ctrl + 1 с уровня 4. Одама — ранг II, Расенсюрикен — III."
		end
		if active then
			header.Text = string.upper(names[current])..(if phase=="Consumed" then "  /  ПОПАДАНИЕ" elseif ready>0 then "  /  ФОРМИРОВАНИЕ" else "  /  ГОТОВ К УДАРУ")
			header.TextColor3 = colors[current]
			footer.Text = if phase=="Consumed" then "Контакт подтверждён — техника завершается."
				elseif ready>0 then string.format("Формирование %.1f с · затем подойдите к врагу и нажмите ЛКМ.",ready)
				else string.format("Подойдите к врагу: ЛКМ — удар. Заряд сохранится ещё %.1f с.",math.max(0,number(model,"RasenganExpiresAt")-now))
			if nextIndex>0 and rank>=nextIndex then
				local reason = Controller.AbilityUnavailable(ids[nextIndex])
				if not reason and Controller.Remaining(ids[nextIndex])<=0 then
					header.Text = "НАЖМИТЕ "..keys[nextIndex].."  →  "..string.upper(names[nextIndex])
					footer.Text = string.format("Усилить за +200 чакры · окно %.1f с. Без усиления сохранится %s.",window,names[current])
				end
			end
		end
		for i,id in ids do
			local card = cards[i]
			local reason = Controller.AbilityUnavailable(id)
			local cooldown = Controller.Remaining(id)
			local isCurrent = active and current==i
			local available = (i==1 or ordinary) and rank>=i and reason==nil and cooldown<=0 and ((i==1 and not active) or nextIndex==i)
			local complete = active and current>i
			card.button.AutoButtonColor = available; card.button.Active = true
			card.button.BackgroundColor3 = if isCurrent then Color3.fromRGB(26,67,88) elseif available then Color3.fromRGB(28,59,72) else Color3.fromRGB(26,32,42)
			card.stroke.Transparency = if available then .1+.12*math.sin(now*10) elseif isCurrent then .1 else .78
			card.stroke.Thickness = if available or isCurrent then 2 else 1
			card.key.TextColor3 = if available then Color3.fromRGB(255,233,143) else colors[i]
			card.state.TextColor3 = if available then Color3.fromRGB(255,233,143) elseif isCurrent then colors[i] else Color3.fromRGB(159,177,191)
			card.progress.Size = UDim2.new(if nextIndex==i and rank>=i then math.clamp(window,0,1) else 0,0,0,3)
			card.state.Text = if rank<i then (if i==1 then "Изучить: Ctrl + 1" else "Нужен ранг "..(if i==2 then "II" else "III"))
				elseif isCurrent then (if phase=="Consumed" then "Удар" elseif ready>0 then string.format("Формирование %.1f с",ready) else "ЛКМ — удар")
				elseif complete then "✓ Усилено"
				elseif Controller.GetQueuedUpgrade(id) then "Нажатие принято…"
				elseif i>1 and not ordinary then "Обычная форма"
				elseif cooldown>0 then string.format("Перезарядка %.0f с",math.ceil(cooldown))
				elseif active and i==current+1 and window<=0 then "Окно усиления закрыто"
				elseif number(model,"Mana")<(if i==1 then 100 else 200) then "Не хватает чакры"
				elseif available then (if i==1 then "Начать · 100 чакры" else string.format("НАЖМИТЕ %s · %.1f с",keys[i],window))
				elseif nextIndex==i and reason then reason
				elseif i==1 and not active and reason then reason
				else (if i==1 then "100 чакры" elseif i==2 then "После 1 · +200 чакры" else "После Z · +200 чакры")
		end
	end)
end
return HUD
