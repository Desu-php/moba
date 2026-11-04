--!strict
-- Opt-in Play audit: run before Runner.server.luau after the first portrait is visible.
assert(game:GetService("RunService"):IsStudio())
local p=game.Players.LocalPlayer
local c=p.Character;assert(c)
local started=os.clock()
local frames,missing,partial,unmasked,blankPortrait=0,0,0,0,0
local run=game:GetService("RunService")
local connection:RBXScriptConnection?=nil
connection=run.RenderStepped:Connect(function()
 local coverage=0;local fading=false
 for _,folder in c:GetChildren() do
  if folder.Name=="DisplayedHeroAppearance" then
   for _,part in folder:GetChildren() do if part:IsA("BasePart") and string.find(part.Name,"Face") then
    coverage=math.max(coverage,(1-part.Transparency)*(1-part.LocalTransparencyModifier))
    if part.Transparency>.01 and part.Transparency<.99 then fading=true end
   end end
  elseif folder.Name=="HeroAppearance" or folder.Name=="PreviousHeroAppearance" then
   for _,part in folder:GetChildren() do if part:IsA("BasePart") and part.Transparency<.99 then unmasked+=1 end end
  end
 end
 local portraitCount=0
 for _,item in p.PlayerGui:GetDescendants() do
  if item:IsA("Model") and item.Name=="HeroPortrait" then portraitCount+=1 end
 end
 frames+=1;if coverage<.98 then missing+=1 end;if fading then partial+=1 end
 if portraitCount==0 then blankPortrait+=1 end
 if workspace:GetAttribute("AppearanceTransitionQADone")==true or os.clock()-started>25 then
  if connection then connection:Disconnect() end
  local displays=0
  for _,f in c:GetChildren() do if f.Name=="DisplayedHeroAppearance" then displays+=1 end end
  local ok=missing==0 and blankPortrait==0 and unmasked==0 and partial>0 and displays==1
  p:SetAttribute("AppearanceTransitionQA",game:GetService("HttpService"):JSONEncode({ok=ok,frames=frames,missingHeadFrames=missing,
   blankPortraitFrames=blankPortrait,unmaskedSourceParts=unmasked,fadeFrames=partial,finalDisplays=displays}))
 end
end)
