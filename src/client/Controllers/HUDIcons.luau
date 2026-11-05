--!strict
-- Original code-drawn Naruto symbols. No uploaded images or Valve assets.
local Icons = {}
local palettes: {[string]: Color3} = {
	Rasengan=Color3.fromRGB(32,133,190), Odama=Color3.fromRGB(23,92,178), Rasenshuriken=Color3.fromRGB(36,115,126), ShadowClones=Color3.fromRGB(183,104,39),
	Gamakichi=Color3.fromRGB(148,66,50), SageMode=Color3.fromRGB(186,96,42),
	KCM=Color3.fromRGB(198,151,34), CloneCommand=Color3.fromRGB(86,129,148),
	GamakichiOil=Color3.fromRGB(87,127,52), GamakichiChop=Color3.fromRGB(126,83,62),
	IronBlade=Color3.fromRGB(82,119,137), GuardianArmor=Color3.fromRGB(107,101,137),
	SwiftBoots=Color3.fromRGB(117,85,51), HealingPotion=Color3.fromRGB(91,144,82),
}
function Icons.draw(parent: GuiObject, id: string): Frame
	local canvas=Instance.new("Frame"); canvas.Name="Icon"; canvas.Size=UDim2.fromScale(1,1)
	canvas.BackgroundColor3=palettes[id] or Color3.fromRGB(65,87,105); canvas.BorderSizePixel=0; canvas.Parent=parent
	local gradient=Instance.new("UIGradient"); gradient.Rotation=65
	gradient.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(55,60,78)); gradient.Parent=canvas
	local function shape(name: string,x: number,y: number,w: number,h: number,round: boolean,rotation: number?): Frame
		local f=Instance.new("Frame"); f.Name=name; f.AnchorPoint=Vector2.new(.5,.5); f.Position=UDim2.fromScale(x,y); f.Size=UDim2.fromScale(w,h)
		f.BackgroundColor3=Color3.fromRGB(224,237,226); f.BorderSizePixel=0; f.Rotation=rotation or 0; f.Parent=canvas
		if round then local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=f end
		return f
	end
	local sasuke=require(game.ReplicatedStorage.Shared.Abilities.SasukeDefinitions).Spells[id]
 if sasuke then
  canvas.BackgroundColor3=if sasuke.line=="SasukeFire" then Color3.fromRGB(177,66,31) elseif sasuke.line=="SasukeLightning" then Color3.fromRGB(51,105,169) else Color3.fromRGB(105,46,148)
  if sasuke.line=="SasukeLightning" then
   shape("Bolt",.48,.35,.16,.5,false,32);shape("Bolt",.58,.65,.14,.43,false,32);shape("Cross",.5,.5,.45,.13,false)
  elseif sasuke.line=="SasukeFire" then
   shape("Flame",.5,.55,.48,.62,true,-15);shape("Tongue",.5,.25,.22,.4,false,28);shape("Core",.5,.65,.22,.3,true).BackgroundColor3=Color3.fromRGB(255,190,45)
  elseif sasuke.line=="SasukeSummon" then
   for i=1,6 do shape("Snake",.5+math.sin(i)*.18,.18+i*.1,.23,.22,true) end
  else
   shape("Eye",.5,.5,.8,.42,true);shape("Iris",.5,.5,.38,.38,true).BackgroundColor3=Color3.fromRGB(173,35,79);shape("Pupil",.5,.5,.13,.13,true).BackgroundColor3=Color3.fromRGB(15,10,24)
   for i=1,3 do local a=i*math.pi*2/3;shape("Tomoe",.5+math.cos(a)*.13,.5+math.sin(a)*.13,.07,.07,true).BackgroundColor3=Color3.fromRGB(15,10,24) end
  end
 elseif id=="Rasengan" then
		for i=1,4 do
			local r=shape("ChakraRing",.5,.5,.18+i*.14,.18+i*.14,true); r.BackgroundTransparency=1
			local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(159,232,255); stroke.Thickness=2; stroke.Parent=r
		end
		shape("Core",.5,.5,.22,.22,true); shape("Flow",.5,.5,.78,.045,false,-35)
	elseif id=="Odama" then
        local outer=shape("LargeAura",.5,.5,.91,.91,true); outer.BackgroundColor3=Color3.fromRGB(83,198,255); outer.BackgroundTransparency=.35
        shape("LargeCore",.5,.5,.72,.72,true).BackgroundColor3=Color3.fromRGB(224,252,255)
        for i=1,3 do
            local r=shape("CompressedFlow",.5,.5,.25+i*.16,.25+i*.16,true);r.BackgroundTransparency=1
            local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(79,166,237);stroke.Thickness=2;stroke.Parent=r
        end
    elseif id=="Rasenshuriken" or id=="RasenshurikenThrow" or id=="RikudoHY" or id=="RikudoHZ" then
        for i=0,3 do
            local a=math.pi*i/2
            local blade=shape("WindBlade",.5+math.cos(a)*.24,.5+math.sin(a)*.24,.15,.48,false,45+i*90)
            blade.BackgroundColor3=Color3.fromRGB(210,255,255)
        end
        shape("WindCore",.5,.5,.45,.45,true).BackgroundColor3=Color3.fromRGB(115,228,255)
        local core=shape("Core",.5,.5,.29,.29,true);core.BackgroundColor3=Color3.fromRGB(245,255,255)
    elseif id=="KcmDash" then
        canvas.BackgroundColor3=Color3.fromRGB(173,122,31)
        shape("Dash",.55,.45,.16,.65,false,30);shape("DashTip",.55,.68,.20,.37,false,-34)
        for i=1,3 do shape("Speed",.22,.22+i*.18,.32,.04,false,-12) end
    elseif id=="ShadowSleep" then
        canvas.BackgroundColor3=Color3.fromRGB(105,72,145)
        for _,x in {.28,.72} do shape("ClosedEye",x,.58,.29,.06,false) end
        shape("Sleep",.55,.22,.28,.05,false);shape("Sleep",.55,.31,.28,.05,false,-38);shape("Sleep",.55,.40,.28,.05,false)
    elseif id=="MeditationToggle" or id=="MeditationRecall" then
        canvas.BackgroundColor3=Color3.fromRGB(65,132,117)
        shape("Head",.5,.25,.22,.25,true);shape("Body",.5,.55,.28,.36,true)
        shape("Leg",.32,.79,.48,.13,true,-18);shape("Leg",.68,.79,.48,.13,true,18)
        if id=="MeditationRecall" then shape("Return",.82,.30,.09,.35,false,35) end
    elseif id=="ShadowClones" or id=="CloneCommand" then
		for i=1,3 do local x=.19+(i-1)*.30; shape("Head",x,.37,.18,.22,true); shape("Body",x,.66,.23,.30,true) end
		if id=="CloneCommand" then shape("Command",.5,.20,.74,.035,false) end
	elseif id=="Gamakichi" or id=="GamakichiOil" then
		shape("Frog",.5,.57,.74,.49,true); shape("Eye",.27,.31,.22,.25,true); shape("Eye",.73,.31,.22,.25,true)
		shape("Mouth",.5,.63,.44,.045,false).BackgroundColor3=palettes[id]
		if id=="GamakichiOil" then shape("Oil",.5,.81,.17,.24,true) end
	elseif id=="SageMode" then
		for _,x in {.28,.72} do
			shape("EyeMark",x,.49,.32,.28,true).BackgroundColor3=Color3.fromRGB(78,36,28)
			shape("Eye",x,.49,.24,.12,true); shape("Pupil",x,.49,.15,.035,false).BackgroundColor3=Color3.fromRGB(33,30,25)
		end
	elseif id=="KuramaForm" then
        canvas.BackgroundColor3=Color3.fromRGB(210,145,34)
        for i=1,9 do local a=(i-5)*.26;shape("Tail",.5+math.sin(a)*.32,.37+math.abs(a)*.08,.065,.50,true,(i-5)*17) end
        shape("Fox",.5,.68,.42,.34,true).BackgroundColor3=Color3.fromRGB(255,220,102)
        shape("Ear",.33,.5,.13,.28,false,-22);shape("Ear",.67,.5,.13,.28,false,22)
        for _,x in {.4,.6} do shape("Eye",x,.65,.10,.04,false).BackgroundColor3=Color3.fromRGB(75,33,18) end
	elseif id=="KCM" or id=="KcmCancel" or id=="KuramaConvert" then
		for i=1,5 do shape("Flame",.18+(i-1)*.16,.43,.13,.52,true,(i-3)*18) end
		shape("Seal",.5,.73,.40,.27,true).BackgroundColor3=Color3.fromRGB(77,49,22)
	elseif id=="GuardianArmor" then
		shape("Plate",.5,.46,.54,.58,true); shape("Shoulder",.20,.29,.25,.22,true); shape("Shoulder",.80,.29,.25,.22,true)
	elseif id=="SwiftBoots" then
		shape("Boot",.45,.37,.29,.50,false,-12); shape("Sole",.57,.65,.56,.22,true)
	elseif id=="HealingPotion" then
		shape("Bottle",.5,.50,.46,.57,true); shape("Cork",.5,.18,.26,.15,false)
	else
		shape("Blade",.54,.44,.14,.76,false,38); shape("Guard",.36,.67,.44,.09,false,38); shape("Grip",.24,.83,.10,.27,false,38)
	end
	return canvas
end
return Icons
