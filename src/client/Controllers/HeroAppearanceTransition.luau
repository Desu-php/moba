--!strict
-- Presentation only: keep a loaded costume while its successor is replicated/preloaded.
local Content=game:GetService("ContentProvider")
local Run=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Controller={}
type State={model:Model,source:Folder?,shown:Folder?,generation:number,connection:RBXScriptConnection?}
local states:{[Model]:State}={}
local started=false
local function hide(folder:Instance)
 for _,part in folder:GetDescendants() do if part:IsA("BasePart") then part.Transparency=1 end end
end
local function alpha(folder:Folder,value:number)
 for _,part in folder:GetChildren() do
  if part:IsA("BasePart") then
   local original=part:GetAttribute("TransitionTransparency")
   part.Transparency=(if typeof(original)=="number" then original else 0)+(1-(if typeof(original)=="number" then original else 0))*value
  end
 end
end
local function visualCopy(source:Folder,model:Model):Folder
 local copy=Instance.new("Folder");copy.Name="DisplayedHeroAppearance"
 copy:SetAttribute("AppearanceVersion",source:GetAttribute("AppearanceVersion"))
 copy:SetAttribute("AppearanceForm",source:GetAttribute("AppearanceForm"))
 for _,original in source:GetChildren() do
  if not original:IsA("BasePart") then continue end
  local bodyName=original:GetAttribute("CosmeticBody");local offset=original:GetAttribute("CosmeticOffset")
  local body=if typeof(bodyName)=="string" then model:FindFirstChild(bodyName) else nil
  if not body or not body:IsA("BasePart") or typeof(offset)~="CFrame" then continue end
  local part=original:Clone()
  for _,child in part:GetDescendants() do
   if not child:IsA("DataModelMesh") and not child:IsA("Decal") and not child:IsA("SurfaceAppearance") then child:Destroy() end
  end
  local target=original:GetAttribute("AppearanceTransparency")
  part.Transparency=if typeof(target)=="number" then target else 0
  part:SetAttribute("TransitionTransparency",part.Transparency)
  part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Massless=true;part.Anchored=false
  part.LocalTransparencyModifier=0;part.CFrame=body.CFrame*offset;part.Parent=copy
  local weld=Instance.new("Weld");weld.Name="FormVisualWeld";weld.Part0=body;weld.Part1=part;weld.C0=offset;weld.Parent=part
 end
 return copy
end
local function stage(state:State,folder:Folder)
 if state.source==folder then return end
 state.source=folder;state.generation+=1
 local generation=state.generation
 hide(folder)
 task.spawn(function()
  local function current():boolean return state.model.Parent~=nil and state.generation==generation and folder.Parent==state.model end
  -- Attribute/descendant replication is not atomic, even when the server builds off-tree.
  while current() do
   local expected=folder:GetAttribute("AppearanceParts")
   local descendants=folder:GetAttribute("AppearanceDescendants")
   if typeof(expected)=="number" and #folder:GetChildren()>=expected and typeof(descendants)=="number" and #folder:GetDescendants()>=descendants then break end
   Run.Heartbeat:Wait()
  end
  if not current() then return end
  local copy=visualCopy(folder,state.model)
  if not state.shown then
   -- First spawn has no previous costume; show it while warming its textures.
   copy.Parent=state.model;state.shown=copy
   pcall(function() Content:PreloadAsync({copy}) end)
   return
  end
  local fetched=true
  local ready=true
  if folder:GetAttribute("AppearanceForm")=="Sasuke" then
   -- Sasuke has a procedural face. A slow optional mesh must not hold an entire
   -- mode transition (or mode exit) behind an obsolete costume for many seconds.
   task.spawn(function() pcall(function() Content:PreloadAsync({copy}) end) end)
  else
   ready=pcall(function() Content:PreloadAsync({copy},function(_id,status)
    if status~=Enum.AssetFetchStatus.Success then fetched=false end
   end) end)
  end
  if not current() or not ready or not fetched then copy:Destroy();return end
  local previous=state.shown
  alpha(copy,1);copy.Parent=state.model
  local at=os.clock()
  while current() do
   local t=math.clamp((os.clock()-at)/.55,0,1)
   -- Keep the old face fully opaque until the new face is opaque.
   local incoming=math.clamp(t/.6,0,1);incoming=incoming*incoming*(3-2*incoming)
   local outgoing=math.clamp((t-.6)/.4,0,1);outgoing=outgoing*outgoing*(3-2*outgoing)
   alpha(copy,1-incoming);if previous then alpha(previous,outgoing) end
   if t>=1 then break end
   Run.RenderStepped:Wait()
  end
  if not current() then copy:Destroy();if previous and previous.Parent then alpha(previous,0) end;return end
  if previous then previous:Destroy() end
  state.shown=copy;alpha(copy,0)
 end)
end
local function bind(model:Model)
 if states[model] then return end
 local state:State={model=model,source=nil,shown=nil,generation=0,connection=nil};states[model]=state
 state.connection=model.DescendantAdded:Connect(function(item)
  local parent=item.Parent
  if parent and (parent.Name=="HeroAppearance" or parent.Name=="PreviousHeroAppearance") and item:IsA("BasePart") then item.Transparency=1 end
  if item:IsA("Folder") and item.Parent==model and item.Name=="HeroAppearance" then stage(state,item) end
 end)
 for _,child in model:GetChildren() do
  if child.Name=="PreviousHeroAppearance" then hide(child) end
  if child:IsA("Folder") and child.Name=="HeroAppearance" then stage(state,child) end
 end
 model.Destroying:Once(function()
  state.generation+=1;if state.connection then state.connection:Disconnect() end
  if state.shown then state.shown:Destroy() end;states[model]=nil
 end)
end
function Controller.Start()
 if started then return end;started=true
 task.spawn(function()
  local cache=Instance.new("Folder");local factory=require(Shared.CreatorVisualFactory)
  local data=require(Shared.Config.SasukeVisualData)
  for _,specs in {data.appearance,data.susanoo,data.garuda} do for _,spec in specs do factory.Part(spec :: any).Parent=cache end end
  pcall(function() Content:PreloadAsync({cache}) end);cache:Destroy()
 end)
 -- Warm every form's mesh/face IDs before the first transformation when possible.
 task.spawn(function()
  local cache=Instance.new("Folder")
  local factory=require(Shared.CreatorVisualFactory)
  local data=require(Shared.Config.CreatorVisualData)
  local forms=require(Shared.Config.NarutoFormVisualData)
  -- Typed Instances ensure mesh IDs are fetched as meshes, not as generic images.
  local function add(specs:any) for _,s in specs do factory.Part(s).Parent=cache end end
  add(data.appearance);for _,specs in forms do add(specs) end
  for _,id in {"rbxassetid://9477576334","rbxassetid://9449064416"} do
   local part=Instance.new("Part");part.Parent=cache;local decal=Instance.new("Decal");decal.Texture=id;decal.Parent=part
  end
  pcall(function() Content:PreloadAsync({cache}) end);cache:Destroy()
 end)
 workspace.DescendantAdded:Connect(function(item)
  if item:IsA("Folder") and item.Name=="HeroAppearance" and item.Parent and item.Parent:IsA("Model") then bind(item.Parent) end
 end)
 for _,item in workspace:GetDescendants() do
  if item:IsA("Folder") and item.Name=="HeroAppearance" and item.Parent and item.Parent:IsA("Model") then bind(item.Parent) end
 end
end
return Controller
