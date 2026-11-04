--!strict
local Players=game:GetService("Players")
local Aura={}
type State={folder:Folder,parts:{Part},form:string,at:number}
local states:{[Model]:State}={}
function Aura.Update(parent:Folder,now:number)
 local live:{[Model]:boolean}={}
 for _,player in Players:GetPlayers() do
  local model=player.Character
  if not model then continue end
  local root=model:FindFirstChild("HumanoidRootPart");local hp=model:FindFirstChildOfClass("Humanoid")
  local form:string=if model:GetAttribute("KcmActive")==true or model:GetAttribute("KuramaActive")==true then "Kurama" elseif model:GetAttribute("SagePhase")=="Active" or model:GetAttribute("SagePhase")=="Preparing" then "Sage" else ""
  local camera=workspace.CurrentCamera
  if form=="" or not root or not root:IsA("BasePart") or not hp or hp.Health<=0 or (camera and (root.Position-camera.CFrame.Position).Magnitude>120) then continue end
  live[model]=true
  local state=states[model]
  if not state then
   local f=Instance.new("Folder");f.Name="ChakraAura";f.Parent=parent
   local parts:{Part}={}
   for i=1,18 do
    local p=Instance.new("Part");p.Name="ChakraStream";p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Material=Enum.Material.Neon;p.Parent=f;table.insert(parts,p)
   end
   local createdState:State={folder=f,parts=parts,form=form,at=now};state=createdState;states[model]=createdState
  end
  if state.form~=form then state.form=form;state.at=now end
  local t=now-state.at
  for i,p in state.parts do
   local phase=(t*(if form=="Kurama" then 1.2 else .55)+i/18)%1
   local angle=i*2.399+t*.7
   local radius=(if form=="Kurama" then 1.5 else 2.2)+math.sin(phase*math.pi)*.5
   local pos=root.Position+Vector3.new(math.cos(angle)*radius,-2.7+phase*6,math.sin(angle)*radius)
   p.Color=if form=="Kurama" then Color3.fromRGB(255,151,25) else Color3.fromRGB(231,174,80)
   p.Size=Vector3.new(.035,if form=="Kurama" then .7+phase else .18,.035)
   p.CFrame=CFrame.new(pos)*CFrame.Angles(0,angle,math.sin(angle)*.3)
   p.Transparency=.25+math.abs(phase-.5)*1.4
  end
 end
 for model,state in states do if not live[model] then state.folder:Destroy();states[model]=nil end end
end
return Aura
