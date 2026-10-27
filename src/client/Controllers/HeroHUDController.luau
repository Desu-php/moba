--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInput = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.ItemConfig)
local HUD = {}
local started = false
local colors = { Background = Color3.fromRGB(17, 24, 35), Card = Color3.fromRGB(29, 40, 55),
 Text = Color3.fromRGB(235, 242, 255), Muted = Color3.fromRGB(164, 182, 202), Gold = Color3.fromRGB(255, 207, 94),
 Green = Color3.fromRGB(83, 211, 151), Blue = Color3.fromRGB(90, 160, 255) }
local messages: { [string]: string } = {
 Purchased = "Предмет куплен", NotEnoughGold = "Недостаточно золота", FullHealth = "Здоровье уже полное",
 TooFar = "Вернитесь к магазину своей базы", Dead = "Магазин доступен живому герою",
 Unavailable = "Магазин сейчас недоступен", RateLimited = "Слишком много запросов. Попробуйте ещё раз",
 Replay = "Запрос уже обработан", Busy = "Покупка уже выполняется", UnknownItem = "Неизвестный предмет", Malformed = "Некорректный запрос",
}
function HUD.Start()
 if started then return end; started = true
 task.spawn(function()
  local player = Players.LocalPlayer
  local state = player:WaitForChild("HeroState", 30)
  local match = ReplicatedStorage:WaitForChild("SurvivalState", 30)
  local remote = ReplicatedStorage:WaitForChild("ItemShop", 30)
  local notice = ReplicatedStorage:WaitForChild("HeroNotice", 30)
  if not state or not match or not remote or not remote:IsA("RemoteEvent") or not notice or not notice:IsA("RemoteEvent") then return end
  local gui = Instance.new("ScreenGui"); gui.Name = "HeroHUD"; gui.ResetOnSpawn = false; gui.DisplayOrder = 10
  gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = player:WaitForChild("PlayerGui")
  local function round(parent: GuiObject, radius: number)
   local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius); c.Parent = parent
  end
  local function frame(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
   local f = Instance.new("Frame"); f.Name = name; f.Size = size; f.Position = position; f.BorderSizePixel = 0
   f.BackgroundColor3 = colors.Background; f.Parent = parent; return f
  end
  local function label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, fontSize: number): TextLabel
   local l = Instance.new("TextLabel"); l.Name = name; l.Text = text; l.Size = size; l.Position = position
   l.BackgroundTransparency = 1; l.TextColor3 = colors.Text; l.Font = Enum.Font.GothamMedium; l.TextSize = fontSize
   l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parent; return l
  end
  local function button(parent: Instance, name: string, text: string, size: UDim2, position: UDim2): TextButton
   local b = Instance.new("TextButton"); b.Name = name; b.Text = text; b.Size = size; b.Position = position
   b.BackgroundColor3 = colors.Gold; b.TextColor3 = colors.Background; b.TextSize = 14; b.Font = Enum.Font.GothamBold
   b.BorderSizePixel = 0; b.Parent = parent; round(b, 6); return b
  end
  local hero = frame(gui, "ProgressionPanel", UDim2.fromOffset(380, 98), UDim2.new(0.5, 0, 1, -12))
  hero.AnchorPoint = Vector2.new(0.5, 1); hero.BackgroundTransparency = 0.08; round(hero, 10)
  local scale = Instance.new("UIScale"); scale.Parent = hero
  local level = label(hero, "Level", "LV 1", UDim2.fromOffset(100, 24), UDim2.fromOffset(12, 5), 17)
  local gold = label(hero, "Gold", "", UDim2.new(1, -125, 0, 24), UDim2.fromOffset(113, 5), 17); gold.TextColor3 = colors.Gold; gold.TextXAlignment = Enum.TextXAlignment.Right
  local hp = label(hero, "Health", "", UDim2.fromOffset(150, 18), UDim2.fromOffset(12, 32), 12)
  local kda = label(hero, "KDA", "", UDim2.new(1, -175, 0, 18), UDim2.fromOffset(163, 32), 12); kda.TextXAlignment = Enum.TextXAlignment.Right
  local hpTrack = frame(hero, "HealthTrack", UDim2.new(1, -24, 0, 6), UDim2.fromOffset(12, 53)); hpTrack.BackgroundColor3 = colors.Card
  local hpFill = frame(hpTrack, "Fill", UDim2.fromScale(1, 1), UDim2.new()); hpFill.BackgroundColor3 = colors.Green
  local xp = label(hero, "XP", "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 64), 12); xp.TextColor3 = colors.Muted
  local xpTrack = frame(hero, "XPTrack", UDim2.new(1, -24, 0, 4), UDim2.fromOffset(12, 87)); xpTrack.BackgroundColor3 = colors.Card
  local xpFill = frame(xpTrack, "Fill", UDim2.fromScale(0, 1), UDim2.new()); xpFill.BackgroundColor3 = colors.Blue
  local toast = label(gui, "RewardNotice", "", UDim2.fromOffset(360, 50), UDim2.new(0.5, 0, 1, -235), 18)
  toast.AnchorPoint = Vector2.new(0.5, 1); toast.TextXAlignment = Enum.TextXAlignment.Center
  toast.TextColor3 = colors.Gold; toast.TextStrokeTransparency = 0.4; toast.TextWrapped = true
  local shade = frame(gui, "Shop", UDim2.fromScale(1, 1), UDim2.new()); shade.Visible = false
  shade.BackgroundColor3 = Color3.new(); shade.BackgroundTransparency = 0.4; shade.Active = true
  local panel = frame(shade, "Window", UDim2.fromScale(0.92, 0.88), UDim2.fromScale(0.5, 0.5))
  panel.AnchorPoint = Vector2.new(0.5, 0.5); round(panel, 12)
  local constraint = Instance.new("UISizeConstraint"); constraint.MaxSize = Vector2.new(580, 450); constraint.MinSize = Vector2.new(270, 180); constraint.Parent = panel
  label(panel, "Title", "МАГАЗИН БАЗЫ", UDim2.new(1, -75, 0, 30), UDim2.fromOffset(16, 8), 20)
  local shopGold = label(panel, "Balance", "", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 38), 14); shopGold.TextColor3 = colors.Gold
  local close = button(panel, "Close", "×", UDim2.fromOffset(40, 40), UDim2.new(1, -50, 0, 10))
  local list = Instance.new("ScrollingFrame"); list.Name = "Items"; list.Position = UDim2.fromOffset(12, 68)
  list.Size = UDim2.new(1, -24, 1, -110); list.BackgroundTransparency = 1; list.BorderSizePixel = 0
  list.CanvasSize = UDim2.new(); list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.ScrollBarThickness = 4; list.Parent = panel
  local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = list
  local status = label(panel, "Status", "Подойдите к магазину своей команды", UDim2.new(1, -32, 0, 34), UDim2.new(0, 16, 1, -38), 12)
  status.TextWrapped = true
  local buys: { [string]: TextButton } = {}
  local pending: number? = nil
  local serial = 0
  local function setOpen(open: boolean)
   shade.Visible = open; player:SetAttribute("ShopOpen", open)
  end
  close.Activated:Connect(function() setOpen(false) end)
  UserInput.InputBegan:Connect(function(input, processed)
   if not processed and input.KeyCode == Enum.KeyCode.Escape then setOpen(false) end
  end)
  local function number(name: string): number return (state:GetAttribute(name) or 0) :: number end
  local function refresh()
   local maximum = math.max(1, number("MaxHealth")); local health = number("CurrentHealth")
   local required = number("XPToNextLevel"); local current = number("CurrentXP"); local balance = number("Gold")
   level.Text = "LV " .. number("Level"); gold.Text = math.floor(balance) .. " GOLD"
   hp.Text = string.format("HP %d / %d", math.ceil(health), maximum)
   kda.Text = string.format("K / D / A   %d / %d / %d", number("TotalKills"), number("TotalDeaths"), number("Assists"))
   xp.Text = if required == 0 then "МАКСИМАЛЬНЫЙ УРОВЕНЬ" else string.format("XP %d / %d", current, required)
   hpFill.Size = UDim2.fromScale(math.clamp(health / maximum, 0, 1), 1)
   xpFill.Size = UDim2.fromScale(if required == 0 then 1 else math.clamp(current / required, 0, 1), 1)
   shopGold.Text = math.floor(balance) .. " GOLD  •  экипировка сохраняется после смерти"
   for id, buy in buys do
    local item = Items.Items[id]; local owned = state:GetAttribute("Own_" .. id) == true
    local insufficient = balance < item.Cost; local full = item.Heal ~= nil and health >= maximum
    buy.Text = if owned then "Куплено" elseif pending then "…" elseif insufficient then "Нет Gold" elseif full then "HP полное" else "Купить"
    buy.Active = not owned and not insufficient and not full and pending == nil
    buy.AutoButtonColor = buy.Active; buy.BackgroundColor3 = if buy.Active then colors.Gold else colors.Card
    buy.TextColor3 = if buy.Active then colors.Background else colors.Muted
   end
   if health <= 0 or match:GetAttribute("Phase") ~= "InProgress" or player:GetAttribute("Eliminated") == true then setOpen(false) end
  end
  for index, id in Items.Order do
   local item = Items.Items[id]
   local card = frame(list, id, UDim2.new(1, -8, 0, 76), UDim2.new()); card.LayoutOrder = index; card.BackgroundColor3 = colors.Card; round(card, 8)
   local name = label(card, "Name", item.Name, UDim2.new(1, -105, 0, 22), UDim2.fromOffset(12, 6), 15); name.TextTruncate = Enum.TextTruncate.AtEnd
   local desc = label(card, "Description", item.Description, UDim2.new(1, -110, 0, 39), UDim2.fromOffset(12, 28), 12); desc.TextWrapped = true; desc.TextColor3 = colors.Muted
   local cost = label(card, "Cost", item.Cost .. " GOLD", UDim2.fromOffset(82, 20), UDim2.new(1, -94, 0, 4), 13); cost.TextColor3 = colors.Gold; cost.TextXAlignment = Enum.TextXAlignment.Center
   local buy = button(card, "Buy", "Купить", UDim2.fromOffset(82, 40), UDim2.new(1, -94, 0, 27)); buys[id] = buy
   buy.Activated:Connect(function()
    if pending or not buy.Active then return end
    serial += 1; local request = serial; pending = request; status.Text = "Покупка…"; refresh()
    remote:FireServer(request, id)
    task.delay(4, function()
     if pending == request then pending = nil; status.Text = "Ответ не получен. Проверьте баланс и попробуйте ещё раз"; refresh() end
    end)
   end)
  end
  remote.OnClientEvent:Connect(function(kind: string, request: number?, success: boolean?, reason: string?)
   if kind == "Open" then refresh(); setOpen(true); status.Text = "Предметы приобретаются за золото матча"
   elseif kind == "Result" and request == pending then
    pending = nil; refresh()
    status.Text = messages[reason or "Unavailable"] or "Покупка недоступна"
    status.TextColor3 = if success then colors.Green else colors.Gold
   end
  end)
  local xpGain, goldGain, levelGain, noticeVersion = 0, 0, 0, 0
  notice.OnClientEvent:Connect(function(xpAmount: number, goldAmount: number, levels: number)
   xpGain += xpAmount; goldGain += goldAmount; levelGain += levels; noticeVersion += 1
   local version = noticeVersion
   toast.Text = (if levelGain > 0 then "LEVEL UP!  +" .. levelGain .. "\n" else "")
    .. (if xpGain > 0 then "+" .. xpGain .. " XP  " else "") .. (if goldGain > 0 then "+" .. goldGain .. " GOLD" else "")
   task.delay(3, function()
    if version == noticeVersion then toast.Text = ""; xpGain = 0; goldGain = 0; levelGain = 0 end
   end)
  end)
  state.AttributeChanged:Connect(refresh); match:GetAttributeChangedSignal("Phase"):Connect(refresh)
  player:GetAttributeChangedSignal("Eliminated"):Connect(refresh)
  local cameraConnection: RBXScriptConnection? = nil
  local function resize()
   local camera = workspace.CurrentCamera; if not camera then return end
   scale.Scale = math.clamp(math.min((camera.ViewportSize.X - 32) / 380, camera.ViewportSize.Y / 500), 0.7, 1)
   local viewport = camera.ViewportSize
   toast.Size = UDim2.fromOffset(math.min(360, viewport.X - 24), 50)
   toast.TextSize = if viewport.Y < 500 then 14 else 18
   toast.Position = if viewport.Y > viewport.X then UDim2.new(0.5, 0, 0, 325)
    elseif viewport.Y < 500 then UDim2.new(0.5, 0, 0, if viewport.Y < 350 then 120 else 145)
    else UDim2.new(0.5, 0, 1, -235)
  end
  local function cameraChanged()
   if cameraConnection then cameraConnection:Disconnect() end
   local camera = workspace.CurrentCamera
   if camera then cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
   resize()
  end
  workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
  cameraChanged(); refresh()
 end)
end
return HUD
