--!strict
-- Original Roblox presentation following the map's timing/attachment sequence.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared.Config.AbilityConfig)
local Definition=require(Shared.Abilities.NarutoDefinitions).Rasengan
local Units=require(Shared.Abilities.WorldUnits)
local Rounds=require(script.Parent.RoundController)
type Effect={parts:{BasePart},at:number,untilAt:number,origin:Vector3,model:Model?,kind:string}
type Helper={model:Model,cast:number}
local effects:{Effect}={}
local orbs:{[Model]:Effect}={}
local helpers:{[Model]:Helper}={}
local folder:Folder?=nil
local VFX={}
local started=false
local function part(name:string,color:Color3,size:Vector3): Part
	local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
	p.Color=color; p.Size=size; p.Material=Enum.Material.Neon; p.CastShadow=false; p.Parent=folder; return p
end
local function remove(index:number)
	local effect=effects[index]; if effect.model then orbs[effect.model]=nil end
	for _,p in effect.parts do p:Destroy() end; table.remove(effects,index)
end
local function create(position:Vector3,kind:string,model:Model?): Effect?
	local camera=workspace.CurrentCamera
	if #effects>=Config.Visual.MaxEffects or (camera and (camera.CFrame.Position-position).Magnitude>Config.Visual.ViewDistance) then return nil end
	local now=workspace:GetServerTimeNow()
	local effect:Effect={parts={},at=now,untilAt=now+(if kind=="Orb" then 20 elseif kind=="Finish" then .7 else .5),origin=position,model=model,kind=kind}
	local count=if kind=="Orb" then 32 else 8
	for i=1,count do
		local p=part(if kind=="Orb" then "RasenganSpiral" else "Rasengan"..kind,Color3.fromRGB(110,211,255),Vector3.one*.2)
		if kind=="Orb" then
			if i<=2 then p.Shape=Enum.PartType.Ball; p.Size=Vector3.one*(if i==1 then .9 else 1.15); p.Transparency=if i==1 then .08 else .78
			else p.Size=Vector3.new(.035,.035,.29); p.Color=Color3.fromRGB(211,247,255) end
		elseif kind=="Smoke" then p.Shape=Enum.PartType.Ball; p.Material=Enum.Material.SmoothPlastic; p.Color=Color3.fromRGB(193,207,214)
		elseif kind=="Finish" and i==1 then p.Shape=Enum.PartType.Cylinder
		else p.Shape=Enum.PartType.Ball end
		table.insert(effect.parts,p)
	end
	if kind=="Orb" then
		local light=Instance.new("PointLight"); light.Color=Color3.fromRGB(94,194,255); light.Range=4; light.Brightness=.55; light.Parent=effect.parts[1]
	end
	table.insert(effects,effect); return effect
end
local function removeHelper(source:Model,poof:boolean)
	local helper=helpers[source]; if not helper then return end
	if poof and helper.model.Parent then create(helper.model:GetPivot().Position,"Smoke",nil) end
	helper.model:Destroy(); helpers[source]=nil
end
local function helper(source:Model,cast:number)
	if helpers[source] then return end
	local root=source:FindFirstChild("HumanoidRootPart"); if not root or not root:IsA("BasePart") then return end
	local old=source.Archivable; source.Archivable=true; local copy=source:Clone(); source.Archivable=old
	for _,item in copy:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Tool") or item:IsA("ForceField") then item:Destroy()
		elseif item:IsA("BasePart") then item.CanCollide=false; item.CanTouch=false; item.CanQuery=false; item.Massless=true end
	end
	copy.Name="RasenganPreparationHelper"; copy:SetAttribute("RasenganHelper",true); copy:SetAttribute("RasenganPhase","")
	copy:SetAttribute("RasenganVisible",false); copy:SetAttribute("RasenganHeld",false); copy:SetAttribute("EntityKind","Cosmetic")
	local copyRoot=copy:FindFirstChild("HumanoidRootPart") :: BasePart; copyRoot.Anchored=true
	local humanoid=copy:FindFirstChildOfClass("Humanoid"); if humanoid then humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
	local position=root.Position+root.CFrame.RightVector*Units.toStuds(Definition.HelperOffsetWarcraft)
	copy:PivotTo(CFrame.lookAt(position,root.Position)); copy.Parent=folder
	helpers[source]={model=copy,cast=cast}; create(position,"Smoke",nil)
end
local function visible(model:Model,now:number): boolean
	if model:GetAttribute("NativeNarutoClone")==true then return model:GetAttribute("RasenganVisible")==true end
	local at=model:GetAttribute("RasenganStartedAt")
	return model:GetAttribute("RasenganHeld")==true and typeof(at)=="number" and now>=at+Definition.HandEffectDelay
end
function VFX.Event(message:any)
	if typeof(message.position)~="Vector3" then return end
	if message.kind=="Smoke" then create(message.position,"Smoke",nil)
	elseif message.kind=="RasenganFinish" then create(message.position,"Finish",nil)
	elseif message.kind=="RasenganTrail" then create(message.position,"Trail",nil) end
end
function VFX.GetDiagnostics(model:Model): (boolean,boolean)
	return helpers[model]~=nil,orbs[model]~=nil
end
function VFX.Start()
	if started then return end; started=true
	local created=Instance.new("Folder"); created.Name="LocalHeroVFX"; created.Parent=workspace; folder=created
	Rounds.Watch(function()
		for i=#effects,1,-1 do remove(i) end
		for model in helpers do removeHelper(model,false) end
	end)
	RunService.PreRender:Connect(function()
		local now=workspace:GetServerTimeNow(); local match=game:GetService("ReplicatedStorage"):FindFirstChild("SurvivalState")
		local active=match~=nil and match:GetAttribute("Phase")=="InProgress"
		local function source(model:Model)
			local humanoid=model:FindFirstChildOfClass("Humanoid"); if not active or not humanoid or humanoid.Health<=0 then removeHelper(model,false); return end
			local at=model:GetAttribute("RasenganStartedAt"); local ready=model:GetAttribute("RasenganReadyAt"); local cast=model:GetAttribute("NarutoCastId")
			if model:GetAttribute("NativeNarutoClone")~=true and typeof(at)=="number" and typeof(ready)=="number" and typeof(cast)=="number" and model:GetAttribute("RasenganPhase")=="Preparing"
				and now>=at+Definition.VariantWindow and now<ready then
				local old=helpers[model]; if old and old.cast~=cast then removeHelper(model,false) end
				helper(model,cast)
			else removeHelper(model,true) end
			if visible(model,now) and not orbs[model] then
				local effect=create(model:GetPivot().Position,"Orb",model); if effect then orbs[model]=effect end
			end
		end
		for _,player in Players:GetPlayers() do if player.Character then source(player.Character) end end
		local summons=workspace:FindFirstChild("HeroSummons")
		if summons then for _,model in summons:GetChildren() do if model:IsA("Model") then source(model) end end end
		for model in helpers do if not model:IsDescendantOf(workspace) then removeHelper(model,false) end end
		for index=#effects,1,-1 do
			local effect=effects[index]; local model=effect.model
			local humanoid=if model then model:FindFirstChildOfClass("Humanoid") else nil
			if not active or now>=effect.untilAt or (model and (not model.Parent or not humanoid or humanoid.Health<=0 or not visible(model,now))) then remove(index); continue end
			local elapsed=now-effect.at
			if model then
				local hand=model:FindFirstChild("RightHand"); if not hand or not hand:IsA("BasePart") then remove(index); continue end
				local center=hand.CFrame*CFrame.new(0,-.55,-.7)
				for i,p in effect.parts do
					if i<=2 then p.CFrame=center
					else
						local ring=math.floor((i-3)/10); local segment=(i-3)%10
						local rotation=center*CFrame.Angles(ring*math.pi/3+now*2,now*4,ring*.7)
						local angle=segment*math.pi/5+now*9; local nextAngle=angle+math.pi/5
						local a=rotation:PointToWorldSpace(Vector3.new(math.cos(angle)*.45,math.sin(angle)*.45,0))
						local b=rotation:PointToWorldSpace(Vector3.new(math.cos(nextAngle)*.45,math.sin(nextAngle)*.45,0))
						p.CFrame=CFrame.lookAt((a+b)/2,b)
					end
				end
			else
				local progress=math.clamp(elapsed/(effect.untilAt-effect.at),0,1)
				for i,p in effect.parts do
					local angle=i*math.pi/4; local finish=effect.kind=="Finish"
					if finish and i==1 then
						p.Size=Vector3.new(.12,2+progress*8,2+progress*8); p.CFrame=CFrame.new(effect.origin-Vector3.new(0,2.8,0))*CFrame.Angles(0,0,math.pi/2); p.Transparency=.35+progress*.65
					else
						p.Position=effect.origin+Vector3.new(math.cos(angle)*progress*(if finish then 4 else 2),progress*(if finish then -2 else 1.5),math.sin(angle)*progress*(if finish then 4 else 2))
						p.Size=Vector3.one*(.3+progress*(if finish then 1.4 else 1)); p.Transparency=.2+progress*.8
					end
				end
			end
		end
	end)
end
return VFX
