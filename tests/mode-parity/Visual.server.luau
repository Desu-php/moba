--!strict
-- Companion to Visual.client.luau. Run after Runner or on a fresh solo match. Restart afterward.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Dev=require(S.DeveloperCommandService)
local N=require(S.NarutoAbilityService)
local K=require(S.NarutoKcmService)
local P=require(S.HeroProgressionService)
local Stats=require(S.CharacterStatsService)
local p=game.Players:GetPlayers()[1];local c=p.Character;assert(c)
local n=N.Get(p);assert(n)
local function waitFor(fn:()->boolean)
 local deadline=os.clock()+20
 repeat if fn() then return end;task.wait(.05) until os.clock()>deadline
 error("visual fixture prerequisite")
end
local ok,err=pcall(function()
 waitFor(function() return n.q.active==nil and n.selfControlUntil<=workspace:GetServerTimeNow() end)
 if n.sage.active then n.sage.active.expiresAt=workspace:GetServerTimeNow()+.05;task.wait(.3) end
 assert(Dev.Execute(p,"rikudo"))
 assert(K.TryCast(p,"KcmCancel",3000,workspace:GetServerTimeNow(),nil))
 waitFor(function() return c:GetAttribute("KcmActive")==false end)
 local profile=P.Get(p);assert(profile);profile.Learned.KCM=2;P.Publish(p)
 Dev.Execute(p,"refresh")
 assert(K.TryCast(p,"KCM",3001,workspace:GetServerTimeNow(),nil))
 assert(N.TryCast(p,"SageMode",3002,workspace:GetServerTimeNow(),nil))
 waitFor(function() return c:GetAttribute("SagePhase")=="Active" end)
 workspace:SetAttribute("ModeVisualStage","Combined");task.wait(2)
 local sage=n.sage.active;assert(sage);local before=Stats.Get(p).AttackDamageBonus
 sage.auraUntil=workspace:GetServerTimeNow()+.05;task.wait(.3)
 assert(Stats.Get(p).AttackDamageBonus==before and c:GetAttribute("KcmActive")==true and n.sage.active==sage)
 workspace:SetAttribute("ModeVisualStage","AuraExpired");task.wait(2)
 K.TryCast(p,"KcmCancel",3003,workspace:GetServerTimeNow(),nil)
 waitFor(function() return c:GetAttribute("KcmActive")==false end)
 for rank=2,3 do
  profile.Learned.Rasengan=rank;P.Publish(p);Dev.Execute(p,"refresh")
  assert(N.TryCast(p,"Rasengan",3002+rank,workspace:GetServerTimeNow(),nil))
  workspace:SetAttribute("ModeVisualStage","Choices"..rank);task.wait(.7)
  local q=n.q.active;assert(q);q.expiresAt=workspace:GetServerTimeNow()+.05
  waitFor(function() return n.q.active==nil end)
 end
end)
workspace:SetAttribute("ModeVisualServerQA",if ok then "PASS" else tostring(err))
assert(ok,tostring(err))
