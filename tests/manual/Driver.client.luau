assert(game:GetService("RunService"):IsStudio(), "Manual fixture is Studio-only")
local p=game:GetService("Players").LocalPlayer
repeat task.wait(.1) until p.Character and p.Character:GetAttribute("HeroAppearanceVersion")
task.wait(8)
local camera=workspace.CurrentCamera; camera.CameraType=Enum.CameraType.Scriptable
camera.CFrame=CFrame.lookAt(Vector3.new(6,47,24),Vector3.new(6,36,-4))
p:GetAttributeChangedSignal("SelectingCloneTarget"):Connect(function() print("[ManualUI] Selecting",p:GetAttribute("SelectingCloneTarget")) end)
