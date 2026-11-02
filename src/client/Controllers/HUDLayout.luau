--!strict
-- Reference space: 1920x1080. Scale with height; never stretch on ultrawide.
local Layout = { ConsoleWidth = 900, ConsoleHeight = 164, TopWidth = 920, TopHeight = 48,
	RikudoPanelY = -124, RikudoTooltipY = -284 }
function Layout.skill(index: number): (number, number, number)
	if index<=5 then return 240+(index-1)*66,38,60 end
	return 582+(index-6)*38,54,32
end
function Layout.item(index: number): (number,number)
	return 704+((index-1)%3)*62,24+math.floor((index-1)/3)*52
end
function Layout.scale(width: number, height: number): number
	return math.min(height / 1080, (width - 32) / Layout.ConsoleWidth, (width - 240) / Layout.TopWidth)
end
return table.freeze(Layout)
