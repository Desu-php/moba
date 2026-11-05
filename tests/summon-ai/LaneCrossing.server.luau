--!nocheck
-- Real generated lane lip regression: center-ray navigation used to stop here.
assert(game:GetService("RunService"):IsStudio())
local Nav=require(game.ServerScriptService.Server.Services.CloneNavigation)
local Collision=require(game.ServerScriptService.Server.Services.SummonCollision)
local out={}
local function check(name,ok) assert(ok,name);table.insert(out,name);workspace:SetAttribute("LaneCrossingResults",game.HttpService:JSONEncode(out)) end
local function rig(name,pos,size)
 local m=Instance.new("Model");m.Name=name
 local r=Instance.new("Part");r.Name="HumanoidRootPart";r.Size=size;r.Anchored=true;r.CanCollide=false;r.Position=pos;r.Parent=m
 local h=Instance.new("Humanoid");h.HipHeight=0;h.RequiresNeck=false;h.EvaluateStateMachine=false;h.Parent=m
 m.PrimaryPart=r;m.Parent=workspace;Collision.Apply(m);return m,r,h
end
local ok,err=xpcall(function()
 local limit=os.clock()+20;repeat task.wait(.1) until workspace:FindFirstChild("Map") or os.clock()>limit
 assert(workspace.Map.Lanes.Mid.Road2)
 local owner,target=rig("LaneQA_Owner",Vector3.new(-30,36,0),Vector3.new(2,2,1))
 local function cross(name,size,from,to)
  local m,r,h=rig("LaneQA_Toad",from,size);Nav.Register(m,r,h);owner:PivotTo(CFrame.new(to))
  local reached=false;local now=workspace:GetServerTimeNow()
  for i=1,350 do
   Nav.Settle(m,owner,1/30);Nav.Step(m,owner,owner,target,4,now+i/30,1/30,16)
   if ((r.Position-to)*Vector3.new(1,0,1)).Magnitude<5.5 then reached=true;break end
   if i%20==0 then task.wait(.02) end
  end
  local over=OverlapParams.new();over.FilterType=Enum.RaycastFilterType.Include;over.FilterDescendantsInstances={workspace.Map.Ground,workspace.Map.Lanes}
  check(name.." reaches destination",reached)
  check(name.." body stays clear",#workspace:GetPartBoundsInBox(r.CFrame,Vector3.new(size.X,math.max(4,size.Y),size.Z),over)==0)
  Nav.Remove(m);m:Destroy()
 end
 for _,width in {5,7} do
  local size=Vector3.new(width,if width==7 then 4.2 else 3,width)
  cross(width.." grass to lane",size,Vector3.new(0,35.15,24),Vector3.new(0,36,0))
  cross(width.." lane to grass",size,Vector3.new(0,35.4,0),Vector3.new(0,36,24))
  cross(width.." diagonal lip",size,Vector3.new(-13,35.15,24),Vector3.new(3,36,0))
 end
 -- Tall obstacles must not be treated as tiny steps.
 local wall=Instance.new("Part");wall.Name="LaneQA_Wall";wall.Size=Vector3.new(60,8,1);wall.Anchored=true;wall.Position=Vector3.new(0,37,18);wall.Parent=workspace
 local m,r,h=rig("LaneQA_WallToad",Vector3.new(0,35.15,24),Vector3.new(7,4.2,7));Nav.Register(m,r,h);owner:PivotTo(CFrame.new(0,36,0))
 local now=workspace:GetServerTimeNow();for i=1,60 do Nav.Settle(m,owner,1/30);Nav.Step(m,owner,owner,target,4,now+i/30,1/30,16) end
 check("solid wall is not stepped through",r.Position.Z>18+3.5)
 Nav.Remove(m);m:Destroy();wall:Destroy();owner:Destroy()
 workspace:SetAttribute("LaneCrossingStatus","PASS")
end,debug.traceback)
if not ok then workspace:SetAttribute("LaneCrossingStatus","FAIL");workspace:SetAttribute("LaneCrossingError",err);warn(err) end
