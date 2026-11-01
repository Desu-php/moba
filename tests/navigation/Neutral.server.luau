--!strict
-- Focused compatibility check; does not repeat the already-tested 45s natural respawn.
assert(game:GetService("RunService"):IsStudio())
local P=game:GetService("Players")
local S=game.ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local Match=require(S.MatchService)
local Jungle=require(S.JungleService)
local N=require(S.NarutoAbilityService)
local U=require(S.NarutoSummonService)
local G=require(S.GamakichiService)
local F=require(S.FighterStateService)
local A=require(S.AbilityService)
local count=0
local evidence:{[string]:any}={}
local function check(name:string,ok:boolean)assert(ok,name);count+=1;print("[NavigationNeutral] PASS",name)end
local function waitFor(fn:()->boolean,seconds:number)
 local finish=os.clock()+seconds;repeat if fn()then return end;task.wait(.02)until os.clock()>finish;error("Fixture timeout")
end
local ok,err=xpcall(function()
 waitFor(function()return #P:GetPlayers()==2 and Match.GetState()~=nil end,60)
 local match=Match.GetState();assert(match);match.phase="Preparing";match.preparationEnds=0
 waitFor(function()return match.phase=="InProgress" and Jungle.GetAll()[1].model~=nil end,15)
 match.nextWaveAt=workspace:GetServerTimeNow()+10000;match.startedAt=match.nextWaveAt
 require(game.ReplicatedStorage.Shared.Config.TowerConfig).Range=0;require(S.TowerService).CancelAll()
 require(S.MinionAIService).SetRunning(false)
 local a=P:GetPlayers()[1];waitFor(function()return a.Character~=nil and N.Get(a)~=nil end,15)
 local c=a.Character;assert(c);local root=c:FindFirstChild("HumanoidRootPart");assert(root and root:IsA("BasePart"));root:SetNetworkOwner(nil)
 local hp=c:FindFirstChildOfClass("Humanoid");assert(hp);hp.AutoRotate=false
 for _,f in c:GetChildren()do if f:IsA("ForceField")then f:Destroy()end end
 require(S.HeroProgressionService).AddXP(a,450)
 for i,id in {"Rasengan","ShadowClones","Gamakichi"}do assert(require(S.AbilityLearningService).HandleRequest(a,i,c,c:GetAttribute("LifeId"),id,match.roundId))end
 local first=Jungle.GetAll()[1].model;assert(first);local tr=first.PrimaryPart;assert(tr);local th=first:FindFirstChildOfClass("Humanoid");assert(th)
 root.CFrame=CFrame.lookAt(tr.Position+Vector3.new(4.5,0,0),tr.Position)
 check("ordinary Q admitted against registered neutral",A.HandleRequest(a,1,c,"Rasengan",match.roundId))
 waitFor(function()return c:GetAttribute("RasenganPhase")=="Holding"end,3)
 root.AssemblyLinearVelocity=Vector3.zero;root.CFrame=CFrame.lookAt(tr.Position+Vector3.new(4.5,0,0),tr.Position)
 check("neutral attack start admitted",require(S.CombatService).TryAttack(a,1,c)=="Started")
 waitFor(function()return th.Health==0 end,2)
 local n=N.Get(a);assert(n)
 evidence.heldAtLethal=c:GetAttribute("RasenganHeld");evidence.authoritativeConsumed=n.q.active==nil
 check("lethal impact consumes authoritative Q once",n.q.active==nil)
 waitFor(function()return c:GetAttribute("RasenganHeld")~=true end,.35)
 check("throttled held snapshot clears within publication interval",c:GetAttribute("RasenganHeld")~=true)
 local camp=Jungle.GetAll()[2];local target=camp.model;assert(target);local targetRoot=target.PrimaryPart;assert(targetRoot)
 local targetHP=target:FindFirstChildOfClass("Humanoid");assert(targetHP);targetHP.MaxHealth=10000;targetHP.Health=10000
 root.CFrame=CFrame.lookAt(camp.home+Vector3.new(8,0,0),targetRoot.Position);hp.Health=hp.MaxHealth;task.wait(.6)
 check("clones admitted on real camp terrain",A.HandleRequest(a,2,c,"ShadowClones",match.roundId))
 waitFor(function()return U.GetCount()==3 end,2);task.wait(.5)
 check("Gamakichi coexists with navigated clones",A.HandleRequest(a,3,c,"Gamakichi",match.roundId))
 waitFor(function()return G.Get(a)~=nil end,1);task.wait(.5)
 check("neutral target command admitted normally",A.HandleRequest(a,4,c,"CloneCommand",target,match.roundId))
 local before=targetHP.Health
 waitFor(function()return targetHP.Health<before end,5)
 check("group damages neutral through unchanged authority",targetHP.Health<before and U.GetCount()>0 and G.Get(a)~=nil)
 local toad=G.Get(a);assert(toad);check("oil remains usable beside clone navigation",A.HandleRequest(a,5,c,"GamakichiOil",target,match.roundId))
 waitFor(function()return target:GetAttribute("OilUntil")~=nil end,3)
 check("oil status actually reaches real neutral",target:GetAttribute("OilUntil")~=nil)
 check("owner M1 unchanged by summon orders",F.Get(c)~=nil and (F.Get(c)::any).logic.attackSerial==1)
 local bases=require(S.BaseService).GetAll();local team=a:GetAttribute("TeamId");assert(typeof(team)=="string")
 local base=bases[if team=="Blue"then"Red"else"Blue"];assert(base);base.humanoid.Health=0
 waitFor(function()return match.phase=="Finished" and U.GetCount()==0 and G.Get(a)==nil end,2)
 check("core death clears both summon kinds and statuses",U.GetCount()==0 and G.Get(a)==nil and target:GetAttribute("OilUntil")==nil)
 return "passed"
end,function(message)return debug.traceback(tostring(message),2)end)
game:GetService("StudioTestService"):EndTest({suite="NavigationNeutral",ok=ok,count=count,evidence=evidence,error=if ok then nil else err})
