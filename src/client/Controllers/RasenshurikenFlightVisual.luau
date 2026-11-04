--!strict
local Art=require(script.Parent.RasenganVisual)
type Flight={orb:Art.Orb,model:Model,hand:Part,source:Model?,origin:Vector3,direction:Vector3,at:number,speed:number,range:number}
local flights:{[number]:Flight}={}
local V={}
local function remove(id:number)
 local f=flights[id];if f then Art.Destroy(f.orb);f.model:Destroy();flights[id]=nil end
end
function V.Event(message:any,parent:Folder)
 if message.kind=="RasenshurikenFlightEnd" or message.kind=="RasenshurikenDetonate" then remove(message.id);return end
 if message.kind~="RasenshurikenFlight" then return end
 local count=0;for _ in flights do count+=1 end;if count>=32 then return end
 local m=Instance.new("Model");m.Name="ThrownRasenshuriken";m:SetAttribute("RasenganVariant","Rasenshuriken");m:SetAttribute("RasenganPhase","Holding");m:SetAttribute("RasenganStartedAt",message.releaseAt)
 local hand=Instance.new("Part");hand.Name="HumanoidRootPart";hand.Parent=m
 flights[message.id]={orb=Art.Create(parent,m,true),model=m,hand=hand,source=message.source,origin=message.position,direction=message.direction,at=message.releaseAt,speed=message.speed,range=message.range}
end
function V.Update(now:number,dt:number)
 for id,f in flights do
  if now>f.at+f.range/f.speed+.5 or not f.source or not f.source.Parent then remove(id);continue end
  local pos=f.origin+f.direction*math.clamp((now-f.at)*f.speed,0,f.range)
  f.hand.CFrame=CFrame.lookAt(pos,pos+f.direction)*CFrame.new(0,1,.25)
  local hand=f.source:FindFirstChild("RightHand")
  Art.Update(f.orb,f.model,if now<f.at and hand and hand:IsA("BasePart") then hand else f.hand,now,dt)
 end
end
function V.Clear() for id in flights do remove(id) end end
return V
