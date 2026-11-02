--!strict
assert(game:GetService("RunService"):IsStudio())
local player=game:GetService("Players").LocalPlayer
local remote=game:GetService("ReplicatedStorage"):WaitForChild("RangedQABus") :: RemoteEvent
local client=player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local vfx=require(client:WaitForChild("Controllers"):WaitForChild("NarutoRangedVFXController"))
remote.OnClientEvent:Connect(function(serial:number)
 local active,parts,counters=vfx.Diagnostics()
 local gui=player:WaitForChild("PlayerGui"):FindFirstChild("AbilityHUD")
 local panel=if gui then gui:FindFirstChild("RikudoTechniques",true) else nil
 remote:FireServer(serial,active,parts,counters,panel~=nil and panel:IsA("Frame") and panel.Visible)
end)
remote:FireServer("Ready")
