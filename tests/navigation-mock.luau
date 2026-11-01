--!nocheck
-- Generated with the production module embedded by run-clone-navigation.ps1.
-- Geometry/path responses here are controlled doubles, NOT Roblox engine evidence.
local now, jobs, requests = 0, {}, {}
local requestAt = nil
local vector = {}
local V = {}
function V.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vector) end
vector.__add = function(a,b) return V.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vector.__sub = function(a,b) return V.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vector.__mul = function(a,b)
	if type(b)=="number" then return V.new(a.X*b,a.Y*b,a.Z*b) end
	return V.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
vector.__index = function(a,k)
	local n=math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)
	if k=="Magnitude" then return n elseif k=="Unit" then return V.new(a.X/n,a.Y/n,a.Z/n) end
end
local Vector3 = V
local CFrame = {new=function(p) return {Position=p} end}
local Enum = {RaycastFilterType={Exclude=1},PathStatus={Success=1},PathWaypointAction={Walk=1}}
local RaycastParams = {new=function() return {} end}
local OverlapParams = {new=function() return {} end}
local wall = true
local function blocked(a,b,padding)
	-- Expanded box X [-1,1], Z [-5,5]. Sampled only in this deterministic double.
	for i=0,100 do
		local t=i/100; local x=a.X+(b.X-a.X)*t; local z=a.Z+(b.Z-a.Z)*t
		if math.abs(x)<1+padding and math.abs(z)<5+padding then return true end
	end
	return false
end
local workspace = {}
function workspace:GetServerTimeNow() return now end
function workspace:Raycast(p,d)
	if d.Y < -1 and math.abs(d.X)+math.abs(d.Z)<0.001 then return {Position=V.new(p.X,0,p.Z),Normal=V.new(0,1,0)} end
	if wall and blocked(p,p+d,0) then return {} end
	return nil
end
function workspace:Blockcast(cf,size,d)
	if wall and blocked(cf.Position,cf.Position+d,math.max(size.X,size.Z)/2) then return {} end
	return nil
end
function workspace:GetPartBoundsInBox(cf,size)
	if wall and blocked(cf.Position,cf.Position,math.max(size.X,size.Z)/2) then return {{}} end
	return {}
end
local noPath = false
local pathfinding = {}
function pathfinding:CreatePath(options)
	assert(not options.AgentCanJump and options.AgentHeight==5)
	local path={Status=1}
	function path:ComputeAsync(origin,goal)
		table.insert(requests,{at=requestAt or now,origin=origin,goal=goal})
		if noPath then self.Status=0; return end
		self.points={origin,V.new(-3,0,8),V.new(3,0,8),V.new(goal.X,0,goal.Z)}
	end
	function path:GetWaypoints()
		local result={}; for _,p in self.points do table.insert(result,{Position=p,Action=1}) end; return result
	end
	function path:Destroy() end
	return path
end
local game = {GetService=function(_,name)
	if name=="PathfindingService" then return pathfinding end
	return {WaitForChild=function() return {Abilities={CloneNavigationPolicy="policy"}} end}
end}
local task = {spawn=function(job) table.insert(jobs,{run=job,at=now}) end}
local originalRequire = require
local function require(name)
	assert(name=="policy"); return originalRequire("../src/shared/Abilities/CloneNavigationPolicy")
end
local function loadNavigation()
-- MODULE_UNDER_TEST
end
local Navigation=loadNavigation()
local function model(x,z)
	local m={root={Position=V.new(x,3,z),Size=V.new(2,2,1)},attributes={}}
	function m:GetPivot() return self.root.Position end
	function m:PivotTo(p) self.root.Position=p end
	function m:SetAttribute(k,v) self.attributes[k]=v end
	return m
end
local function flush()
	local pending=jobs; jobs={}; for _,job in pending do requestAt=job.at; job.run(); requestAt=nil end
end
local owner=model(-15,0); local enemy=model(12,0)
local clone=model(-12,0)
Navigation.Register(clone,clone.root,{HipHeight=2})
local travelled=0
for i=1,600 do
	now=i*0.05; local before=clone.root.Position
	Navigation.Step(clone,owner,enemy,enemy.root,5.125,now,0.05,16.875)
	flush()
	local after=clone.root.Position
	assert((after-before).Magnitude<=16.875*0.05+0.001,"no teleport")
	assert(not blocked(after,after,1.1),"never enters wall")
	travelled+=(after-before).Magnitude
end
assert((clone.root.Position-enemy.root.Position).Magnitude<5.125,"route reaches attack ring around wall")
assert(travelled>24 and #requests>0,"route used pathfinder")
print("PASS mock adapter: wall route, bounded steps and arrival")
Navigation.Remove(clone)
wall=false
local clones={}
for i=1,8 do
	local c=model(-10,i*2.5-10); Navigation.Register(c,c.root,{HipHeight=2}); table.insert(clones,c)
end
for i=1,500 do
	now+=0.05
	for _,c in clones do Navigation.Step(c,owner,enemy,enemy.root,5.125,now,0.05,16.875) end
	flush()
end
for i,c in clones do
	assert((c.root.Position-enemy.root.Position).Magnitude<5.125,"group reaches attack ring")
	for j=1,i-1 do assert((c.root.Position-clones[j].root.Position).Magnitude>=2.34,"clones occupy separate slots") end
end
print("PASS mock adapter: eight clones reach distinct melee slots")
-- Target movement, new target, Stop and Remove invalidate pending route callbacks.
enemy.root.Position=V.new(20,3,8)
for i=1,400 do
	now+=0.05; for _,c in clones do Navigation.Step(c,owner,enemy,enemy.root,5.125,now,0.05,16.875) end; flush()
end
for _,c in clones do assert((c.root.Position-enemy.root.Position).Magnitude<5.125,"moving target reacquired"); Navigation.Remove(c) end
print("PASS mock adapter: group follows moving target")
local mass={}
enemy.root.Position=V.new(12,3,0)
for i=1,30 do
	local c=model(-12-math.floor((i-1)/6)*2.5,((i-1)%6)*2.5-6.25)
	Navigation.Register(c,c.root,{HipHeight=2}); table.insert(mass,c)
end
for i=1,350 do
	now+=0.05; for _,c in mass do Navigation.Step(c,owner,enemy,enemy.root,5.125,now,0.05,16.875) end; flush()
end
local melee=0
for i,c in mass do
	if (c.root.Position-enemy.root.Position).Magnitude<5.125 then melee+=1 end
	for j=1,i-1 do assert((c.root.Position-mass[j].root.Position).Magnitude>=2.34,"mass group does not overlap") end
end
assert(melee>=7,"mass cast fills melee positions while overflow waits")
for i,c in mass do
	if (c.root.Position-enemy.root.Position).Magnitude<5.125 then Navigation.Remove(c); table.remove(mass,i); break end
end
for i=1,120 do
	now+=0.05; for _,c in mass do Navigation.Step(c,owner,enemy,enemy.root,5.125,now,0.05,16.875) end; flush()
end
local refill=0
for _,c in mass do if (c.root.Position-enemy.root.Position).Magnitude<5.125 then refill+=1 end end
assert(refill>=melee,"waiting clones reclaim a freed melee slot")
for _,c in mass do Navigation.Remove(c) end
print("PASS mock adapter: thirty clones separate, fill and reclaim melee positions")
wall=true; noPath=true
local waiting=model(-12,0); Navigation.Register(waiting,waiting.root,{HipHeight=2})
enemy.root.Position=V.new(12,3,0)
local startRequests=#requests
for i=1,200 do now+=0.05; Navigation.Step(waiting,owner,enemy,enemy.root,5.125,now,0.05,16.875); flush() end
assert(#requests-startRequests<=6,"unreachable backoff")
assert(waiting.root.Position.X<0,"unreachable does not cross wall")
Navigation.Stop(waiting); local held=waiting.root.Position; flush(); assert(waiting.root.Position==held)
Navigation.Remove(waiting)
local queued={}; local queueStart=#requests
for i=1,12 do
	local c=model(-12-i,0); Navigation.Register(c,c.root,{HipHeight=2}); table.insert(queued,c)
end
for i=1,100 do
	now+=0.05
	for _,c in queued do Navigation.Step(c,owner,enemy,enemy.root,5.125,now,0.05,16.875) end
	flush()
end
local origins={}
for i=queueStart+1,#requests do origins[requests[i].origin.X]=true end
local served=0; for _ in origins do served+=1 end
assert(served==12,"FIFO serves all clones instead of starving later records")
for _,c in queued do Navigation.Remove(c) end
print("PASS mock adapter: twelve queued clones receive fair path service")
local inflight={}
now+=3
for i=1,5 do
	local c=model(-20-i,0); Navigation.Register(c,c.root,{HipHeight=2}); table.insert(inflight,c)
	Navigation.Step(c,owner,enemy,enemy.root,5.125,now,0.05,16.875); now+=0.3
end
assert(#jobs==2,"at most two async computations admitted")
for _,c in inflight do Navigation.Stop(c); Navigation.Remove(c) end
flush()
print("PASS mock adapter: concurrent cap and remove during in-flight computation")
for i=2,#requests do assert(requests[i].at-requests[i-1].at>=0.249,"global start budget") end
print("PASS mock adapter: unreachable backoff, stop/remove and global path budget")
print("PASS CloneNavigation adapter (controlled geometry, not engine runtime)")
