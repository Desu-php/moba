--!strict
-- Insert as LocalScript in PlayerScripts before Visual.server.luau; opt-in only.
assert(game:GetService("RunService"):IsStudio())
local p=game.Players.LocalPlayer
local observations={}
local function waitFor(fn:()->boolean,label:string)
 local endAt=os.clock()+30
 repeat if fn() then return end;task.wait(.05) until os.clock()>endAt
 error("visual timeout "..label)
end
local function layers():{[string]:boolean}
 local found={}
 for _,x in workspace:GetDescendants() do
  if x.Name=="ChakraAura" then for _,a in x:GetChildren() do found[a.Name]=true end end
 end
 return found
end
local function button(name:string):GuiObject?
 local b=p.PlayerGui:FindFirstChild(name,true)
 return if b and b:IsA("GuiObject") then b else nil
end
local ok,err=pcall(function()
 local label=p.PlayerGui:FindFirstChild("AbilityMessage",true);assert(label and label:IsA("TextLabel"))
 waitFor(function()
  return workspace:GetAttribute("ModeVisualStage")=="Combined" and layers().SageAura==true and layers().KuramaAura==true
   and string.find(label.Text,"KCM II + Мудрец",1,true)~=nil
 end,"both auras and refreshed HUD")
 table.insert(observations,{stage="Combined",layers=layers(),text=label.Text})
 waitFor(function() return workspace:GetAttribute("ModeVisualStage")=="AuraExpired" and layers().SageAura~=true end,"Sage aura endpoint")
 assert(layers().KuramaAura==true and p.Character and p.Character:GetAttribute("SagePhase")=="Active")
 table.insert(observations,{stage="AuraExpired",layers=layers(),text=label.Text})
 for rank=2,3 do
  waitFor(function()
   local o,r=button("ChooseOdama"),button("ChooseRasenshuriken")
   return workspace:GetAttribute("ModeVisualStage")=="Choices"..rank and o~=nil and r~=nil and o.Visible and r.Visible==(rank==3)
  end,"Sage choices "..rank)
  local o,r=button("ChooseOdama"),button("ChooseRasenshuriken");assert(o and r)
  if rank==3 then assert(o.AbsolutePosition.X+o.AbsoluteSize.X<=r.AbsolutePosition.X,"choices overlap") end
  table.insert(observations,{stage="Choices"..rank,odama=o.Visible,shuriken=r.Visible})
 end
end)
p.PlayerGui:SetAttribute("ModeVisualQA",game:GetService("HttpService"):JSONEncode({ok=ok,observations=observations,error=if ok then nil else tostring(err)}))
assert(ok,tostring(err))
