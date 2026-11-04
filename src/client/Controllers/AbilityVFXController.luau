--!strict
-- Original Roblox presentation following the map's timing/attachment sequence.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config=require(Shared.Config.AbilityConfig)
local Definition=require(Shared.Abilities.NarutoDefinitions).Rasengan
local Rounds=require(script.Parent.RoundController)
local Ranged=require(script.Parent.NarutoRangedVFXController)
local RasenganArt=require(script.Parent.RasenganVisual)
local ChakraAura=require(script.Parent.ChakraAuraVisual)
local FlightArt=require(script.Parent.RasenshurikenFlightVisual)
local AreaRules=require(Shared.Abilities.RasenshurikenThrowRules)
local Units=require(Shared.Abilities.WorldUnits)
type Effect={areaId:number?,parts:{BasePart},at:number,untilAt:number,origin:Vector3,model:Model?,kind:string,destination:Vector3?,radius:number?,caster:Model?,orb:RasenganArt.Orb?,burst:RasenganArt.Burst?}
type Helper={model:Model,cast:number}
local effects:{Effect}={}
local orbs:{[Model]:Effect}={}
local helpers:{[Model]:Helper}={}
local oilHighlights:{[Model]:Highlight}={}
local sageHighlights:{[Model]:Highlight}={}
local folder:Folder?=nil
local VFX={}
local started=false
local function part(name:string,color:Color3,size:Vector3): Part
	local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
	p.Color=color; p.Size=size; p.Material=Enum.Material.Neon; p.CastShadow=false; p.Parent=folder; return p
end
local function remove(index:number)
	local effect=effects[index]; if effect.model then orbs[effect.model]=nil end
	if effect.orb then RasenganArt.Destroy(effect.orb) end
	if effect.burst then effect.burst.group:Destroy() end
	for _,p in effect.parts do p:Destroy() end; table.remove(effects,index)
end
local function create(position:Vector3,kind:string,model:Model?,variant:string?): Effect?
	local camera=workspace.CurrentCamera
	if #effects>=Config.Visual.MaxEffects or (camera and (camera.CFrame.Position-position).Magnitude>Config.Visual.ViewDistance) then return nil end
	local now=workspace:GetServerTimeNow()
	local effect:Effect={parts={},at=now,untilAt=now+(if kind=="Area" then 3.5 elseif kind=="Orb" then 20 elseif kind=="Finish" then .7 else .5),origin=position,model=model,kind=kind}
	if kind=="Orb" and model and folder then
  local detailed=model:GetAttribute("NativeNarutoClone")~=true and (not camera or (camera.CFrame.Position-position).Magnitude<90)
  effect.orb=RasenganArt.Create(folder,model,detailed); table.insert(effects,effect); return effect
 end
 if (kind=="Contact" or kind=="Impact" or kind=="Finish") and folder then
  local burst=RasenganArt.Burst(folder,position,variant or "Rasengan",kind,now); effect.burst=burst
  effect.untilAt=now+burst.duration; table.insert(effects,effect); return effect
 end
 local count=if kind=="Oil" then 1 elseif kind=="Area" then 97 elseif kind=="Chop" then 24 elseif kind=="Smoke" then 14 elseif kind=="Channel" or kind=="OilImpact" then 4 else 8
	for i=1,count do
		local p=part(if kind=="Orb" then "RasenganSpiral" else "Rasengan"..kind,Color3.fromRGB(110,211,255),Vector3.one*.2)
		if kind=="Oil" or kind=="OilImpact" then p.Shape=Enum.PartType.Ball; p.Color=Color3.fromRGB(82,49,24); p.Material=Enum.Material.SmoothPlastic; p.Size=Vector3.one*.8
		elseif kind=="Area" then p.Color=Color3.fromRGB(205,248,255); if i==1 then p.Shape=Enum.PartType.Ball;p.Material=Enum.Material.ForceField;p.Color=Color3.fromRGB(30,125,255) end
		elseif kind=="Channel" or kind=="Chop" then if kind=="Channel" then p.Shape=Enum.PartType.Cylinder end; p.Color=Color3.fromRGB(218,241,255)
		elseif kind=="Smoke" then p.Shape=Enum.PartType.Ball; p.Material=Enum.Material.SmoothPlastic; p.Color=Color3.fromRGB(193,207,214)
		elseif kind=="Finish" and i==1 then p.Shape=Enum.PartType.Cylinder
		else p.Shape=Enum.PartType.Ball end
		table.insert(effect.parts,p)
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
 local copiedHumanoid=copy:FindFirstChildOfClass("Humanoid"); if copiedHumanoid then copiedHumanoid.EvaluateStateMachine=false end
	for _,item in copy:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Tool") or item:IsA("ForceField") then item:Destroy()
		elseif item:IsA("BasePart") then item.CanCollide=false; item.CanTouch=false; item.CanQuery=false; item.Massless=true end
	end
	copy.Name="RasenganPreparationHelper"; copy:SetAttribute("RasenganHelper",true); copy:SetAttribute("RasenganPhase","")
	copy:SetAttribute("RasenganVisible",false); copy:SetAttribute("RasenganHeld",false); copy:SetAttribute("EntityKind","Cosmetic")
	local copyRoot=copy:FindFirstChild("HumanoidRootPart") :: BasePart; copyRoot.Anchored=true
	local humanoid=copy:FindFirstChildOfClass("Humanoid"); if humanoid then humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
	-- Cosmetic choreography: the helper works beside the palm, not seven studs away.
	local position=root.Position+root.CFrame.RightVector*2.3+root.CFrame.LookVector*.6
	copy:PivotTo(CFrame.lookAt(position,root.Position)); copy.Parent=folder
	helpers[source]={model=copy,cast=cast}; create(position,"Smoke",nil)
end
local function visible(model:Model,now:number): boolean
	if model:GetAttribute("NativeNarutoClone")==true then return model:GetAttribute("RasenganVisible")==true end
	local at=model:GetAttribute("RasenganStartedAt")
	return model:GetAttribute("RasenganHeld")==true and typeof(at)=="number" and now>=at+.08
end
function VFX.Event(message:any)
 if folder then FlightArt.Event(message,folder) end
 if message.kind=="RasenshurikenAreaEnd" then
  for i=#effects,1,-1 do if effects[i].areaId==message.id then remove(i) end end;return
 end
 if message.kind=="RasenshurikenDetonate" then
  local e=create(message.position,"Area",nil);if e then e.radius=message.radius;e.areaId=message.id;e.at=message.startAt;e.untilAt=e.at+AreaRules.Duration end;return
 end
 local variant=if typeof(message.variant)=="string" then message.variant else "Rasengan"
 if variant~="Odama" and variant~="Rasenshuriken" then variant="Rasengan" end
 if typeof(message.kind)=="string" and string.sub(message.kind,1,6)=="Rikudo" then Ranged.Event(message);return end
	if typeof(message.position)~="Vector3" then return end
	if message.kind=="GamakichiOil" or message.kind=="GamakichiOilImpact" or message.kind=="GamakichiChannel" or message.kind=="GamakichiChopImpact" then
		local kind=if message.kind=="GamakichiOil" then "Oil" elseif message.kind=="GamakichiOilImpact" then "OilImpact" elseif message.kind=="GamakichiChannel" then "Channel" else "Chop"
		local effect=create(message.position,kind,nil)
		if effect then
			effect.destination=if typeof(message.destination)=="Vector3" then message.destination else nil
			effect.radius=if typeof(message.radius)=="number" then message.radius else 1
			local source=message.source
			if typeof(source)=="Instance" then local instance=source :: Instance; if instance:IsA("Model") then effect.caster=instance end end
			if kind=="Oil" and typeof(message.duration)=="number" then effect.untilAt=effect.at+math.max(.03,message.duration) end
		end
	elseif message.kind=="Smoke" then create(message.position,"Smoke",nil)
	elseif message.kind=="RasenshurikenArea" then
  local e=create(message.position,"Area",nil);if e then e.radius=message.radius;e.caster=message.source;e.areaId=message.id;e.at=message.startAt or e.at;e.untilAt=e.at+AreaRules.Duration end
 elseif message.kind=="RasenganContact" then create(message.position,"Contact",nil,variant)
	elseif message.kind=="RasenganImpact" then create(message.position,"Impact",nil,variant)
	elseif message.kind=="RasenganFinish" then create(message.position,"Finish",nil,variant)
	elseif message.kind=="RasenganTrail" then create(message.position,"Trail",nil) end
end
function VFX.GetDiagnostics(model:Model): (boolean,boolean)
	return helpers[model]~=nil,orbs[model]~=nil
end
function VFX.Start()
 Ranged.Start()
	if started then return end; started=true
	local created=Instance.new("Folder"); created.Name="LocalHeroVFX"; created.Parent=workspace; folder=created
	Rounds.Watch(function()
        FlightArt.Clear()
		for i=#effects,1,-1 do remove(i) end
		for model in helpers do removeHelper(model,false) end
	end)
	RunService.PreRender:Connect(function(dt)
		local now=workspace:GetServerTimeNow(); local match=game:GetService("ReplicatedStorage"):FindFirstChild("SurvivalState")
		local active=match~=nil and match:GetAttribute("Phase")=="InProgress"
        ChakraAura.Update(created,now)
        FlightArt.Update(now,dt)
		local sageTagged:{[Model]:boolean}={}
        if active then for _,model in game:GetService("CollectionService"):GetTagged("NarutoSage") do
            if model:IsA("Model") and model.Parent then
                local hp=model:FindFirstChildOfClass("Humanoid")
                local untilAt=model:GetAttribute("SageAuraUntil")
                if hp and hp.Health>0 and typeof(untilAt)=="number" and now<untilAt then
                    sageTagged[model]=true
                    if not sageHighlights[model] then
                        local h=Instance.new("Highlight"); h.Name="SageAura"; h.Adornee=model; h.DepthMode=Enum.HighlightDepthMode.Occluded
                        h.FillColor=Color3.fromRGB(231,140,42); h.OutlineColor=Color3.fromRGB(250,195,75); h.FillTransparency=.88; h.OutlineTransparency=.45; h.Parent=folder; sageHighlights[model]=h
                    end
                end
            end
        end end
        for model,h in sageHighlights do if not sageTagged[model] then h:Destroy(); sageHighlights[model]=nil end end
        local tagged:{[Model]:boolean}={}
		if active then for _,model in game:GetService("CollectionService"):GetTagged("GamakichiOilStatus") do
			if model:IsA("Model") and model.Parent and ((model:GetAttribute("OilUntil") or 0) :: number)>now then
				tagged[model]=true
				if not oilHighlights[model] then
					local h=Instance.new("Highlight"); h.Name="OilStatus"; h.FillColor=Color3.fromRGB(92,55,21); h.FillTransparency=.45; h.OutlineTransparency=.6; h.DepthMode=Enum.HighlightDepthMode.Occluded; h.Adornee=model; h.Parent=folder; oilHighlights[model]=h
				end
			end
		end end
		for model,h in oilHighlights do if not tagged[model] then h:Destroy(); oilHighlights[model]=nil end end
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
			if not active or now>=effect.untilAt or (effect.caster and not effect.caster.Parent) or (model and (not model.Parent or not humanoid or humanoid.Health<=0 or not visible(model,now))) then remove(index); continue end
			local elapsed=now-effect.at
			if model then
				local hand=model:FindFirstChild("RightHand"); if not hand or not hand:IsA("BasePart") then remove(index); continue end
                if effect.orb then RasenganArt.Update(effect.orb,model,hand,now,dt) end
            elseif effect.burst then
                RasenganArt.UpdateBurst(effect.burst,effect.origin,now)
			else
				local progress=math.clamp(elapsed/(effect.untilAt-effect.at),0,1)
				for i,p in effect.parts do
					local angle=i*math.pi/4; local finish=effect.kind=="Finish"
					if effect.kind=="Oil" and effect.destination then
						p.Position=effect.origin:Lerp(effect.destination,progress)+Vector3.new(0,(effect.destination-effect.origin).Magnitude*.05*4*progress*(1-progress),0)
					elseif effect.kind=="Area" then
                        local radius=Units.toStuds(AreaRules.radius(elapsed))
                        if radius<=0 then p.Transparency=1;continue end
                        if effect.caster then effect.origin=effect.caster:GetPivot().Position end
                        local envelope=math.min(1,(1-progress)*5)
                        if i==1 then
                            p.Size=Vector3.one*radius*2; p.Position=effect.origin; p.Transparency=1-envelope*.72
                        elseif i<=73 then
                            local band=math.floor((i-2)/24);local segment=(i-2)%24
                            local rotation=CFrame.new(effect.origin)*CFrame.Angles(band*1.05,elapsed*.7,band*.85)
                            local spin=segment*math.pi/12+elapsed*(if band%2==0 then 11 else -9)
                            local bandRadius=math.max(0,radius-.15)
                            local a=rotation:PointToWorldSpace(Vector3.new(math.cos(spin)*bandRadius,math.sin(spin)*bandRadius,0))
                            local b=rotation:PointToWorldSpace(Vector3.new(math.cos(spin+.28)*bandRadius,math.sin(spin+.28)*bandRadius,0))
                            p.Size=Vector3.new(.06,.12,(b-a).Magnitude);p.CFrame=CFrame.lookAt((a+b)/2,b);p.Transparency=1-envelope*(.55+.3*math.sin(segment*.4)^2)
                        else
                            local spin=i*2.399+elapsed*17;local r=radius*(.2+((i*17)%19)/25)
                            local a=effect.origin+Vector3.new(math.cos(spin)*r,math.sin(i+elapsed*9)*radius*.7,math.sin(spin)*r)
                            local b=a+Vector3.new(math.cos(spin+1)*radius*.35,.35,math.sin(spin+1)*radius*.35)
                            local limit=math.max(.01,radius-.15)
                            local da,db=a-effect.origin,b-effect.origin
                            if da.Magnitude>limit then a=effect.origin+da.Unit*limit end
                            if db.Magnitude>limit then b=effect.origin+db.Unit*limit end
                            p.Size=Vector3.new(.025,.04,(b-a).Magnitude);p.CFrame=CFrame.lookAt((a+b)/2,b);p.Transparency=1-envelope*.8
                        end
                    elseif effect.kind=="Chop" then
                        local radius=(effect.radius or 4)*(.45+progress*.55)
                        local rotation=CFrame.new(effect.origin)*CFrame.Angles(.25,elapsed*2,math.rad(55))
                        local angle=(i-1)/23*math.pi*1.4
                        local a=rotation:PointToWorldSpace(Vector3.new(math.cos(angle)*radius,math.sin(angle)*radius,0))
                        local b=rotation:PointToWorldSpace(Vector3.new(math.cos(angle+.2)*radius,math.sin(angle+.2)*radius,0))
                        p.Size=Vector3.new(.07,.25,(b-a).Magnitude);p.CFrame=CFrame.lookAt((a+b)/2,b);p.Transparency=progress
                    elseif effect.kind=="Smoke" then
                        local spread=progress*3.3;local angle=i*2.399
                        p.Position=effect.origin+Vector3.new(math.cos(angle)*spread,math.sin(i)*.7+progress*2,math.sin(angle)*spread)
                        p.Size=Vector3.one*(.7+math.sin(i)^2+progress*1.7);p.Transparency=.15+progress*.85
                    elseif effect.kind=="Channel" or effect.kind=="OilImpact" then
						local radius=(effect.radius or 1)*(if effect.kind=="Area" then 1+math.min(elapsed/1.6,1)*2/3 elseif effect.kind=="Channel" then 1 else progress)
                        if effect.kind=="Area" and effect.caster then effect.origin=effect.caster:GetPivot().Position end
						if effect.kind=="OilImpact" then p.Position=effect.origin+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius); p.Transparency=progress
						else p.Size=Vector3.new(.1,radius*2,radius*2); p.CFrame=CFrame.new(effect.origin+Vector3.new(0,.12+i*.02,0))*CFrame.Angles(0,0,math.pi/2); p.Transparency=.7+progress*.3 end
					elseif finish and i==1 then
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
