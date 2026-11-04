--!strict
-- Play-only visual lifecycle stress. Restart Play afterwards to reset cosmetic attributes.
assert(game:GetService("RunService"):IsStudio())
local p=game.Players:GetPlayers()[1];assert(p and p.Character)
local c=p.Character
workspace:SetAttribute("AppearanceTransitionQADone",false)
task.wait(.5)
c:SetAttribute("KcmRank",3);c:SetAttribute("KcmActive",true)
local candidate=c:FindFirstChild("HeroAppearance");assert(candidate)
local count=candidate:GetAttribute("AppearanceDescendants")
-- Hold readiness past server retirement to emulate incomplete replication on a slow client.
candidate:SetAttribute("AppearanceDescendants",10000)
task.wait(4.2);candidate:SetAttribute("AppearanceDescendants",count)
task.wait(1.2);c:SetAttribute("KcmActive",false);task.wait(1)
for i=1,8 do c:SetAttribute("KcmActive",i%2==1);task.wait(.08) end
c:SetAttribute("KcmActive",true);task.wait(1.3)
c:SetAttribute("KcmActive",false);task.wait(1.3)
workspace:SetAttribute("AppearanceTransitionQADone",true)
