--!strict
-- Insert during a fresh Studio solo Play; restart Play after this fixture.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server.Services
local Dev=require(S.DeveloperCommandService)
local Kcm=require(S.NarutoKcmService)
local Progression=require(S.HeroProgressionService)
local Stats=require(S.CharacterStatsService)
local Match=require(S.MatchService)
local checks={}
local function check(ok:boolean,name:string) assert(ok,name);table.insert(checks,name) end
local function run()
 local limit=os.clock()+25
 while os.clock()<limit do local m=Match.GetState();if m and m.phase=="InProgress" and game.Players:GetPlayers()[1] then break end;task.wait(.1) end
 local p=game.Players:GetPlayers()[1];assert(p and p.Character)
 local c=p.Character;local profile=Progression.Get(p);assert(profile)
 check(profile.Level==1 and c:GetAttribute("HagoromoUnlocked")~=true,"fresh unprepared hero")
 check(select(1,Dev.Execute(p,"rikudo")),"command accepts fresh hero")
 check(profile.Level==27 and profile.Learned.KCM==3,"command supplies level and rank")
 check(Kcm.IsRikudo(p) and c:GetAttribute("RikudoActive")==true,"real rank III domain active")
 check(c:GetAttribute("HagoromoUnlocked")==true,"Hagoromo granted without timer")
 check(Kcm.RikudoGrant(p,workspace:GetServerTimeNow())~=nil,"gameplay grant available")
 check((c:GetAttribute("KuramaChakra") :: number)>=3300,"separate chakra refilled")
 task.wait(.15)
 check(c:GetAttribute("HeroVisualForm")=="Rikudo","transition selects Rikudo costume")
 local maxHealth=Stats.Get(p).MaxHealth
 check(select(1,Dev.Execute(p,"rikudo")),"repeat while active accepted")
 check(Stats.Get(p).MaxHealth==maxHealth,"repeat does not stack stat layers")
 check(select(1,Kcm.TryCast(p,"KcmCancel",1,workspace:GetServerTimeNow(),nil)),"normal cancel works after command")
 task.wait(1.2)
 check(not Kcm.IsRikudo(p),"normal cancel leaves domain")
 check(select(1,Dev.Execute(p,"rikudo")) and Kcm.IsRikudo(p),"reenter bypasses cooldown and wait")
 Kcm.TryCast(p,"KcmCancel",2,workspace:GetServerTimeNow(),nil);task.wait(1.2)
 -- Existing lower-rank KCM must be cleaned up, not stacked beneath Rikudo.
 profile.Learned.KCM=2;Progression.Publish(p);Kcm.StudioResetCooldowns(p)
 check(select(1,Kcm.TryCast(p,"KCM",3,workspace:GetServerTimeNow(),nil)),"lower-rank fixture enters")
 check(select(1,Dev.Execute(p,"rikudo")) and Kcm.IsRikudo(p),"active lower rank upgrades immediately")
 check(Stats.Get(p).MaxHealth==maxHealth,"upgrade replaces lower rank stats")
 Dev.Execute(p,"level 30");Dev.Execute(p,"rikudo")
 check(profile.Level==30,"command never reduces existing level")
 c:FindFirstChildOfClass("Humanoid").Health=0;task.wait(.1)
 check(not select(1,Dev.Execute(p,"rikudo")),"dead hero rejected")
end
local ok,message=pcall(run)
workspace:SetAttribute("RikudoCommandQA",game:GetService("HttpService"):JSONEncode({ok=ok,checks=checks,error=if ok then nil else tostring(message)}))
assert(ok,tostring(message));print("PASS Rikudo developer command: "..#checks.." checks")
