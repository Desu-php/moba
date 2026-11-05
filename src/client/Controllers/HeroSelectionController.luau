--!strict
local C={}
function C.Start()
 local player=game:GetService("Players").LocalPlayer
 local event=game.ReplicatedStorage:WaitForChild("HeroSelection") :: RemoteEvent
 local gui=Instance.new("ScreenGui");gui.Name="HeroSelection";gui.ResetOnSpawn=false;gui.DisplayOrder=30;gui.Parent=player:WaitForChild("PlayerGui")
 local panel=Instance.new("Frame");panel.Size=UDim2.fromOffset(550,300);panel.Position=UDim2.fromScale(.5,.4);panel.AnchorPoint=Vector2.new(.5,.5);panel.BackgroundColor3=Color3.fromRGB(20,23,35);panel.Parent=gui
 local scale=Instance.new("UIScale");scale.Parent=panel
 local function label(text:string,y:number,size:number):TextLabel
  local l=Instance.new("TextLabel");l.Size=UDim2.new(1,-30,0,50);l.Position=UDim2.fromOffset(15,y);l.BackgroundTransparency=1;l.Text=text;l.TextColor3=Color3.fromRGB(235,230,245);l.Font=Enum.Font.Gotham;l.TextSize=size;l.TextWrapped=true;l.Parent=panel;return l
 end
 label("ВЫБЕРИТЕ ШИНОБИ",10,23)
 local notice=label("Герой выбирается на своей базе. В Studio его можно сменить для проверки.",235,13)
 local function visible(value:boolean) panel.Visible=value;player:SetAttribute("HeroSelectionOpen",value) end
 for i,id in {"OrangeNinja","Sasuke"} do
  local b=Instance.new("TextButton");b.Name=id;b.Size=UDim2.fromOffset(245,155);b.Position=UDim2.fromOffset(20+(i-1)*265,75)
  b.BackgroundColor3=if i==1 then Color3.fromRGB(151,91,36) else Color3.fromRGB(78,53,130);b.TextColor3=Color3.new(1,1,1);b.TextSize=18;b.Font=Enum.Font.GothamBold;b.TextWrapped=true
  b.Text=if i==1 then "НАРУТО\n\nКлоны • Расенган\nРежим мудреца • Курама" else "САСКЕ\n\nЧидори • Огонь\nШаринган • Сусаноо";b.Parent=panel
  b.Activated:Connect(function() event:FireServer(id);notice.Text="Выбор героя…" end)
 end
 local button=Instance.new("TextButton");button.Name="Open";button.Size=UDim2.fromOffset(135,30);button.Position=UDim2.fromOffset(12,85);button.Text="Выбрать героя";button.TextSize=13;button.TextColor3=Color3.new(1,1,1);button.BackgroundColor3=Color3.fromRGB(46,39,68);button.Parent=gui
 button.Activated:Connect(function() visible(not panel.Visible) end)
 event.OnClientEvent:Connect(function(ok:boolean,message:string) if ok then visible(false) else notice.Text=message end end)
 game:GetService("RunService").RenderStepped:Connect(function() local camera=workspace.CurrentCamera;if camera then scale.Scale=math.min(1,(camera.ViewportSize.X-30)/550) end end)
 visible(true)
end
return C
