--!nocheck
-- Execute in the QA client before the server fixture reaches its casts; never shipped.
local seen={};local count=0
local connection
local function check(id,condition)
 if seen[id] then return end
 assert(condition,id);seen[id]=true;count+=1
 workspace:SetAttribute("SasukeVisualChecks",count)
 workspace:SetAttribute("SasukeVisualSeen",table.concat((function() local out={} for key in seen do table.insert(out,key) end;return out end)(),","))
end
connection=game:GetService("RunService").Heartbeat:Connect(function()
 local ok,err=pcall(function()
  local f=workspace:FindFirstChild("LocalSasukeVFX");if not f then return end
  for _,e in f:GetChildren() do
   local function countParts(name) local n=0;for _,p in e:GetChildren() do if p.Name==name then n+=1 end end;return n end
   if e.Name=="Amaterasu" and countParts("BlackFlame")==32 then
    check("black flame boundary",countParts("DamageBoundary")==32 and e:GetAttribute("DamageRadius")==12.5)
    local center=e:GetAttribute("ServerCentre")
    for _,p in e:GetChildren() do if p.Name=="BlackFlame" then assert(((p.Position-center)*Vector3.new(1,0,1)).Magnitude+p.Size.X/2<=12.5+.01,"flame outside boundary") end end
    check("flame cores inside radius",true)
   elseif e.Name=="KirinWarning" and e:FindFirstChild("KirinHead") then
    check("Kirin warning and creature",countParts("DamageBoundary")==32 and e:GetAttribute("DamageRadius")==34.375 and countParts("KirinHorn")==2)
   elseif e.Name=="Kirin" and e:FindFirstChild("ImpactCore") then
    check("Kirin impact radius",countParts("DamageBoundary")==32 and e:GetAttribute("DamageRadius")==34.375)
   elseif e.Name=="SusanooAura" and e:FindFirstChild("ChakraBlade") then
    check("Susanoo blade and footprint",countParts("AttackFootprint")==5)
   elseif e.Name=="ChibakuDrop" and countParts("FallingCore")==9 then
    check("nine drop warnings",countParts("DamageBoundary")==9*32)
    check("hovering spheres removed on drop",f:FindFirstChild("Chibaku")==nil)
   elseif e.Name=="Projectile" and e:FindFirstChild("FireballCore") then check("fire projectile silhouette",e:FindFirstChild("ProjectileTail")~=nil)
   end
   for _,p in e:GetDescendants() do if p:IsA("BasePart") then assert(not p.CanCollide and not p.CanQuery,"visual blocks combat") end end
  end
 end)
 if not ok then workspace:SetAttribute("SasukeVisualError",tostring(err));connection:Disconnect() end
end)
task.delay(100,function() connection:Disconnect() end)
return "Visual probe started"
