--!nocheck
-- Real-time pathfinding regression: broad toads must route around solid bodies.
assert(game:GetService("RunService"):IsStudio())
local Nav=require(game.ServerScriptService.Server.Services.CloneNavigation)
local Collision=require(game.ServerScriptService.Server.Services.SummonCollision)
local results={}
local function check(name,ok)
 assert(ok,name);table.insert(results,name)
 workspace:SetAttribute("ObstacleAvoidanceResults",game.HttpService:JSONEncode(results))
end
local function rig(name,pos,width)
 local m=Instance.new("Model");m.Name=name
 local r=Instance.new("Part");r.Name="HumanoidRootPart";r.Size=Vector3.new(width,if width==7 then 4.2 else 3,width);r.Anchored=true;r.CanCollide=false;r.Position=pos;r.Parent=m
 local h=Instance.new("Humanoid");h.HipHeight=0;h.RequiresNeck=false;h.EvaluateStateMachine=false;h.Parent=m
 m.PrimaryPart=r;m.Parent=workspace;Collision.Apply(m);return m,r,h
end
local ok,err=xpcall(function()
 task.wait(5)
 local scene=Instance.new("Folder");scene.Name="ObstacleAvoidanceQA";scene.Parent=workspace
 local function part(name,size,pos)
  local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.Size=size;p.Position=pos;p.Parent=scene;return p
 end
 part("Floor",Vector3.new(180,2,180),Vector3.new(900,32,900))
 local owner,destination=rig("ObstacleQA_Owner",Vector3.new(920,35.1,900),2)
 local tower=part("SolidTower",Vector3.new(5,6,5),Vector3.new(900,36,900))
 task.wait(1)
 local function route(name,width,from,to,timeout)
  local m,r,h=rig("ObstacleQA_Toad",from,width);Nav.Register(m,r,h);owner:PivotTo(CFrame.new(to))
  local endAt=os.clock()+timeout;local reached=false;local clearance=true;local continuous=true
  local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Include;overlap.FilterDescendantsInstances={scene,workspace.Map.Towers};overlap.RespectCanCollide=true
  repeat
   local dt=game:GetService("RunService").Heartbeat:Wait()
   local before=r.Position
   Nav.Settle(m,owner,dt);Nav.Step(m,owner,owner,destination,6,workspace:GetServerTimeNow(),dt,16)
   if #workspace:GetPartBoundsInBox(CFrame.new(r.Position),Vector3.new(math.max(2.2,width),math.max(4,r.Size.Y),math.max(2.2,width)),overlap)>0 then clearance=false end
   if ((r.Position-before)*Vector3.new(1,0,1)).Magnitude>16*math.clamp(dt,0,.1)+.01 then continuous=false end
   reached=((r.Position-to)*Vector3.new(1,0,1)).Magnitude<7
  until reached or os.clock()>endAt
  workspace:SetAttribute("ObstacleAvoidanceLast",name.." "..tostring(r.Position))
  Nav.Remove(m);m:Destroy()
  check(name.." reaches destination",reached)
  check(name.." never crosses solid geometry",clearance)
  check(name.." never teleports",continuous)
 end
 for _,width in {2,5,7} do
  route(width.." tower head-on",width,Vector3.new(880,35.15,900),Vector3.new(920,35.15,900),12)
  route(width.." tower corner",width,Vector3.new(880,35.15,893),Vector3.new(920,35.15,906),12)
 end
 tower.Size=Vector3.new(4,10,24);tower.Position=Vector3.new(900,38,900)
 route("adult wide wall",7,Vector3.new(880,35.15,900),Vector3.new(920,35.15,900),15)
 for _,width in {2,5,7} do
  route(width.." real mid tower",width,Vector3.new(-90,35.15,15),Vector3.new(-50,35.15,15),15)
  route(width.." real tower from road",width,Vector3.new(-90,35.15,0),Vector3.new(-50,35.15,22),15)
 end
 owner:Destroy();scene:Destroy()
 workspace:SetAttribute("ObstacleAvoidanceStatus","PASS")
end,debug.traceback)
if not ok then workspace:SetAttribute("ObstacleAvoidanceStatus","FAIL");workspace:SetAttribute("ObstacleAvoidanceError",err);warn(err) end
