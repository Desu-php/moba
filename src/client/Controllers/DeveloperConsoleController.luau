--!strict
local Controller={}
function Controller.Start()
 if not game:GetService("RunService"):IsStudio() then return end
 local player=game:GetService("Players").LocalPlayer
 local input=game:GetService("UserInputService")
 local remote=game:GetService("ReplicatedStorage"):WaitForChild("DeveloperCommand",15)
 if not remote or not remote:IsA("RemoteEvent") then return end
 local gui=Instance.new("ScreenGui");gui.Name="DeveloperConsole";gui.ResetOnSpawn=false;gui.DisplayOrder=100;gui.Parent=player:WaitForChild("PlayerGui")
 local hint=Instance.new("TextButton");hint.Name="Toggle";hint.Text="DEV · F8";hint.Size=UDim2.fromOffset(96,30);hint.Position=UDim2.new(1,-108,0,60)
 hint.BackgroundColor3=Color3.fromRGB(28,35,45);hint.TextColor3=Color3.fromRGB(255,211,110);hint.Font=Enum.Font.GothamBold;hint.TextSize=14;hint.Parent=gui
 local panel=Instance.new("Frame");panel.Name="Panel";panel.Size=UDim2.new(.9,0,0,290);panel.Position=UDim2.new(.5,0,.18,0);panel.AnchorPoint=Vector2.new(.5,0)
 panel.BackgroundColor3=Color3.fromRGB(20,25,33);panel.Visible=false;panel.Parent=gui
 local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(620,290);limit.Parent=panel
 local title=Instance.new("TextLabel");title.Size=UDim2.new(1,-28,0,36);title.Position=UDim2.fromOffset(14,8);title.BackgroundTransparency=1
 title.Text="РЕЖИМ РАЗРАБОТКИ · F8 закрыть";title.Font=Enum.Font.GothamBold;title.TextSize=16;title.TextColor3=Color3.fromRGB(255,211,110);title.Parent=panel
 local output=Instance.new("TextLabel");output.Name="Output";output.Position=UDim2.fromOffset(16,50);output.Size=UDim2.new(1,-32,0,160)
 output.BackgroundTransparency=1;output.TextWrapped=true;output.TextXAlignment=Enum.TextXAlignment.Left;output.TextYAlignment=Enum.TextYAlignment.Top
 output.Font=Enum.Font.Gotham;output.TextSize=17;output.TextColor3=Color3.fromRGB(232,237,244);output.Parent=panel
 local box=Instance.new("TextBox");box.Name="Command";box.Position=UDim2.new(0,16,1,-58);box.Size=UDim2.new(1,-32,0,42)
 box.Text="";box.PlaceholderText="Например: level 30    ·    Enter — выполнить";box.ClearTextOnFocus=false;box.Font=Enum.Font.Code;box.TextSize=18
 box.BackgroundColor3=Color3.fromRGB(35,44,57);box.TextColor3=Color3.new(1,1,1);box.Parent=panel
 local function toggle()
  panel.Visible=not panel.Visible;player:SetAttribute("DeveloperConsoleOpen",panel.Visible)
  if panel.Visible then remote:FireServer("help");box:CaptureFocus() else box:ReleaseFocus() end
 end
 hint.Activated:Connect(toggle)
 input.InputBegan:Connect(function(key,processed)
  if key.KeyCode==Enum.KeyCode.F8 and (not processed or panel.Visible) then toggle() end
 end)
 box.FocusLost:Connect(function(enter)
  if not enter or not panel.Visible or box.Text=="" then return end
  remote:FireServer(box.Text);box.Text=""
  task.defer(function() if panel.Visible then box:CaptureFocus() end end)
 end)
 remote.OnClientEvent:Connect(function(ok: boolean,message: string)
  output.Text=message;output.TextColor3=if ok then Color3.fromRGB(225,238,244) else Color3.fromRGB(255,148,123)
  if ok then require(script.Parent.AbilityController).ClearCooldownCorrections() end
 end)
end
return Controller
